import 'dart:typed_data';

/// Sega Master System VDP (Video Display Processor) — TMS9918A-derived Mode 4.
///
/// Memory map:
///   VRAM : 16 KB (0x0000–0x3FFF)
///   CRAM :  32 bytes (SMS palette, 6-bit BGR)
///
/// Control-port write protocol (latch):
///   First byte  → low 8 bits of address
///   Second byte → bits [5:0] = high 6 bits of address
///                 bits [7:6] = command:  00=VRAM read, 01=VRAM write,
///                                        10=register write, 11=CRAM write
class Vdp {
  // ── Memory ──────────────────────────────────────────────────────────────────
  final Uint8List vram = Uint8List(0x4000); // 16 KB
  final Uint8List cram = Uint8List(32); // 32 palette entries (6-bit each)
  final List<int> registers = List<int>.filled(16, 0);

  // ── Frame buffer ─────────────────────────────────────────────────────────────
  /// 256 × 192 pixels, 32-bit ARGB (Flutter-compatible).
  final Uint32List frameBuffer = Uint32List(256 * 192);

  // ── Internal state ────────────────────────────────────────────────────────────
  int _addressRegister = 0; // 14-bit VRAM/CRAM address
  bool _writePending = false; // latch toggle
  int _firstByte = 0; // buffered first control byte
  int _readBuffer = 0; // prefetch buffer for data reads
  int _statusRegister = 0;
  int _commandWord = 0; // bits 15-14 of the address word


  // ── Counters ──────────────────────────────────────────────────────────────────
  int _vCounter = 0;
  int _lineInterruptCounter = 0xFF; // counts down from register[10]; init high so it doesn't fire before game sets reg[10]
  bool _lineInterruptPending = false;

  // ── Public getters ────────────────────────────────────────────────────────────
  int get vCounter => _vCounter;

  /// hCounter is not cycle-accurate in this implementation; returns 0.
  int get hCounter => 0;

  /// Raw status register value without side-effects.
  int get statusRegister => _statusRegister;

  /// True when an interrupt should be asserted to the CPU.
  bool get interruptPending {
    final vblankEnabled = (registers[1] & 0x20) != 0;
    final vblankActive = (_statusRegister & 0x80) != 0;
    if (vblankEnabled && vblankActive) return true;

    final lineEnabled = (registers[0] & 0x10) != 0;
    if (lineEnabled && _lineInterruptPending) return true;

    return false;
  }

  // ── Control port ──────────────────────────────────────────────────────────────

  /// Write a byte to the VDP control port (port 0xBF on SMS).
  void writeControl(int value) {
    value &= 0xFF;
    if (!_writePending) {
      // First byte: buffer it and set latch.
      _firstByte = value;
      _writePending = true;
    } else {
      // Second byte: form the full command word.
      _writePending = false;
      _commandWord = (value >> 6) & 0x03;
      _addressRegister = (_firstByte | ((value & 0x3F) << 8)) & 0x3FFF;

      if (_commandWord == 0x02) {
        // Register write: bits [3:0] of second byte select register.
        int regIndex = value & 0x0F;
        if (regIndex < registers.length) {
          registers[regIndex] = _firstByte;
        }
      } else if (_commandWord == 0x00) {
        // VRAM read: prefetch first byte into read buffer without advancing address.
        // The address will advance on the first readData() call.
        _readBuffer = vram[_addressRegister];
      }
    }
  }

  // ── Data port ─────────────────────────────────────────────────────────────────

  /// Write a byte to the VDP data port (port 0xBE on SMS).
  void writeData(int value) {
    value &= 0xFF;
    _writePending = false; // any data access resets latch

    if (_commandWord == 0x03) {
      // CRAM write
      int cramAddr = _addressRegister & 0x1F;
      cram[cramAddr] = value;
    } else {
      // VRAM write (commands 0x00, 0x01, or default)
      vram[_addressRegister] = value;
    }
    _addressRegister = (_addressRegister + 1) & 0x3FFF;
  }

  /// Read a byte from the VDP data port (port 0xBE on SMS).
  int readData() {
    _writePending = false; // any data access resets latch
    int result = _readBuffer;
    _readBuffer = vram[_addressRegister];
    _addressRegister = (_addressRegister + 1) & 0x3FFF;
    return result;
  }

  // ── Status port ───────────────────────────────────────────────────────────────

  /// Read the VDP status register (port 0xBF on SMS).
  /// Clears the status register, clears the line-interrupt pending flag,
  /// and resets the address latch.
  int readStatus() {
    int result = _statusRegister;
    _statusRegister = 0;
    _lineInterruptPending = false; // reading status acknowledges line interrupt
    _writePending = false;
    return result;
  }

  // ── Flag helpers ──────────────────────────────────────────────────────────────

  /// Set VBlank flag (bit 7) in the status register.
  void setVBlankFlag() {
    _statusRegister |= 0x80;
  }

  void _setSpriteOverflowFlag() {
    _statusRegister |= 0x40;
  }

  void _setSpriteCollisionFlag() {
    _statusRegister |= 0x20;
  }

  // ── Scanline rendering ────────────────────────────────────────────────────────

  /// Advance the VDP by one scanline.
  void renderScanline() {
    final line = _vCounter;

    if (line < 192) {
      _renderSpriteLine(line);
      _renderBackgroundLine(line);
    }

    if (line == 192) {
      setVBlankFlag();
    }

    // Line interrupt counter (register 10 = line interrupt reload value).
    if (line < 192) {
      if (_lineInterruptCounter == 0) {
        _lineInterruptPending = true;
        _lineInterruptCounter = registers[10];
      } else {
        _lineInterruptCounter--;
      }
    } else {
      _lineInterruptCounter = registers[10];
    }

    _vCounter = (_vCounter + 1) % 262;
  }

  // ── Background rendering ──────────────────────────────────────────────────────

  void _renderBackgroundLine(int line) {
    // Name table base address: register[2] bits [3:1] select 1 KB block within VRAM.
    int nameTableBase = (registers[2] & 0x0E) << 10;
    int hScroll = registers[8];
    int vScroll = registers[9];

    int row = ((line + vScroll) % 224);
    int tileRow = row ~/ 8;
    int fineY = row % 8;

    for (int col = 0; col < 32; col++) {
      int screenX = (col * 8 - hScroll) & 0xFF;

      // Bit 7 of register[0]: disable horizontal scrolling for columns 24–31.
      if (col >= 24 && (registers[0] & 0x80) != 0) {
        screenX = col * 8;
      }

      int actualRow = tileRow;
      int actualFineY = fineY;

      // Bit 6 of register[0]: disable vertical scrolling for first 8 tile columns.
      if (line < 16 && (registers[0] & 0x40) != 0) {
        actualRow = line ~/ 8;
        actualFineY = line % 8;
      }

      int nameAddr = nameTableBase + (actualRow * 32 + col) * 2;
      if (nameAddr + 1 >= vram.length) continue;

      int word = vram[nameAddr] | (vram[nameAddr + 1] << 8);
      int tileIndex = word & 0x1FF;
      bool hFlip = (word & 0x200) != 0;
      bool vFlip = (word & 0x400) != 0;
      // bool priority = (word & 0x1000) != 0;  // used in sprite compositing
      int palette = (word & 0x800) != 0 ? 16 : 0;

      int tileY = vFlip ? (7 - actualFineY) : actualFineY;
      int tileAddr = tileIndex * 32 + tileY * 4;
      if (tileAddr + 3 >= vram.length) continue;

      int b0 = vram[tileAddr];
      int b1 = vram[tileAddr + 1];
      int b2 = vram[tileAddr + 2];
      int b3 = vram[tileAddr + 3];

      for (int px = 0; px < 8; px++) {
        int bit = hFlip ? px : (7 - px);
        int colorIdx = ((b0 >> bit) & 1) |
            (((b1 >> bit) & 1) << 1) |
            (((b2 >> bit) & 1) << 2) |
            (((b3 >> bit) & 1) << 3);

        int x = (screenX + px) & 0xFF;
        if (x < 256 && line < 192) {
          int cramValue = cram[palette + colorIdx];
          frameBuffer[line * 256 + x] = _cramToArgb(cramValue);
        }
      }
    }
  }

  /// Convert a 6-bit SMS CRAM value (--BBGGRR) to 32-bit ARGB.
  int _cramToArgb(int cramValue) {
    int r = (cramValue & 0x03) * 85;
    int g = ((cramValue >> 2) & 0x03) * 85;
    int b = ((cramValue >> 4) & 0x03) * 85;
    return 0xFF000000 | (b << 16) | (g << 8) | r; // Flutter BGRA
  }

  // ── Sprite rendering ──────────────────────────────────────────────────────────

  void _renderSpriteLine(int line) {
    // SAT (Sprite Attribute Table) base: register[5] bits [6:1] select 128-byte
    // aligned block.  Full address = (reg5 & 0x7E) << 7.
    int satBase = (registers[5] & 0x7E) << 7;

    bool tallSprites = (registers[1] & 0x02) != 0; // 8×16 when set
    int spriteHeight = tallSprites ? 16 : 8;

    // Collect sprites visible on this line (max 8 per SMS hardware limit).
    List<int> visibleSprites = [];

    for (int i = 0; i < 64; i++) {
      int yAddr = satBase + i;
      if (yAddr >= vram.length) break;
      int yPos = vram[yAddr];

      // 0xD0 is the sprite list terminator in Mode 4.
      if (yPos == 0xD0) break;

      // Sprite Y is offset by +1 (sprite appears one line below stored value).
      int spriteY = (yPos + 1) & 0xFF;

      // Handle wrap: Y values 0xD1–0xFF are treated as negative (above line 0).
      int effectiveY = spriteY;
      if (effectiveY > 240) effectiveY -= 256;

      if (line >= effectiveY && line < effectiveY + spriteHeight) {
        visibleSprites.add(i);
        if (visibleSprites.length > 8) {
          _setSpriteOverflowFlag();
          break;
        }
      }
    }

    // Priority: lower-index sprites are drawn on top → render in reverse order.
    // Also track which X pixels have been drawn for collision detection.
    final List<bool> occupied = List<bool>.filled(256, false);

    for (int idx = visibleSprites.length - 1; idx >= 0; idx--) {
      int i = visibleSprites[idx];

      int yPos = vram[satBase + i];
      int spriteY = (yPos + 1) & 0xFF;
      if (spriteY > 240) spriteY -= 256;

      // SAT second section (bytes 128–255): pairs of [X, tile].
      int xAddr = satBase + 0x80 + i * 2;
      int tAddr = satBase + 0x80 + i * 2 + 1;
      if (xAddr >= vram.length || tAddr >= vram.length) continue;

      int xPos = vram[xAddr];
      int tileIndex = vram[tAddr];

      // Bit 3 of register[6] selects whether sprites use tile bank 0 or 256.
      if ((registers[6] & 0x04) != 0) tileIndex += 256;

      // Horizontal shift: register[0] bit 3 shifts all sprites left 8 pixels.
      if ((registers[0] & 0x08) != 0) xPos = (xPos - 8) & 0xFF;

      int lineInSprite = line - spriteY;
      if (tallSprites && lineInSprite >= 8) {
        tileIndex |= 0x01; // lower half of 8×16 sprite uses next tile
        lineInSprite -= 8;
      }

      int tileAddr = tileIndex * 32 + lineInSprite * 4;
      if (tileAddr + 3 >= vram.length) continue;

      int b0 = vram[tileAddr];
      int b1 = vram[tileAddr + 1];
      int b2 = vram[tileAddr + 2];
      int b3 = vram[tileAddr + 3];

      for (int px = 0; px < 8; px++) {
        int bit = 7 - px;
        int colorIdx = ((b0 >> bit) & 1) |
            (((b1 >> bit) & 1) << 1) |
            (((b2 >> bit) & 1) << 2) |
            (((b3 >> bit) & 1) << 3);

        if (colorIdx == 0) continue; // transparent

        int x = (xPos + px) & 0xFF;
        if (x >= 256) continue;

        // Sprite collision detection.
        if (occupied[x]) {
          _setSpriteCollisionFlag();
        }
        occupied[x] = true;

        // Sprites always use the second palette (CRAM entries 16–31).
        int cramValue = cram[16 + colorIdx];
        frameBuffer[line * 256 + x] = _cramToArgb(cramValue);
      }
    }
  }
}
