import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sega3/emulator/bus.dart';
import 'package:sega3/emulator/z80_cpu.dart';
import 'package:sega3/emulator/vdp.dart';
import 'package:sega3/emulator/psg.dart';
import 'package:sega3/emulator/memory_bus.dart';
import 'package:sega3/emulator/io_ports.dart';
import 'package:sega3/emulator/rom_header.dart';

enum EmulatorButton { up, down, left, right, button1, button2, start }

/// Bridges MemoryBus and IoPorts into the Bus interface used by Z80CPU.
class _SystemBus implements Bus {
  final MemoryBus _memory;
  final IoPorts _io;

  _SystemBus(this._memory, this._io);

  @override
  int read(int address) => _memory.read(address);

  @override
  void write(int address, int value) => _memory.write(address, value);

  @override
  int ioRead(int port) => _io.read(port);

  @override
  void ioWrite(int port, int value) => _io.write(port, value);
}

class Emulator extends ChangeNotifier {
  late final Z80CPU _cpu;
  late final Vdp _vdp;
  late final Psg _psg;
  late final MemoryBus _memoryBus;
  late final IoPorts _ioPorts;
  late final _SystemBus _systemBus;

  bool isRunning = false;
  int _excessCycles = 0; // Amendment F: carry excess cycles between scanlines

  static const int _cyclesPerScanline = 228;
  static const int _scanlinesPerFrame = 262;
  static const int _samplesPerFrame = 44100 ~/ 60;

  Emulator(Uint8List romData) {
    final header = RomHeader.parse(romData);
    final cleanRom = header.cleanRom(romData);

    _vdp = Vdp();
    _psg = Psg();
    _memoryBus = MemoryBus(rom: cleanRom, mapperType: header.mapperType);
    _ioPorts = IoPorts(vdp: _vdp, psg: _psg);
    _systemBus = _SystemBus(_memoryBus, _ioPorts);
    _cpu = Z80CPU(_systemBus);
  }

  /// The current frame buffer from the VDP: 256 × 192 pixels, 32-bit ARGB.
  Uint32List get frameBuffer => _vdp.frameBuffer;

  /// Exposed for diagnostics/testing only.
  Z80CPU get cpu => _cpu;

  /// Exposed for diagnostics/testing only.
  Vdp get vdp => _vdp;

  /// Run one full frame of emulation (262 scanlines).
  void runFrame() {
    for (int scanline = 0; scanline < _scanlinesPerFrame; scanline++) {
      // Amendment F: start with carried-over excess cycles.
      int cyclesThisScanline = _excessCycles;
      while (cyclesThisScanline < _cyclesPerScanline) {
        cyclesThisScanline += _cpu.step();
      }
      _excessCycles = cyclesThisScanline - _cyclesPerScanline;

      _vdp.renderScanline();

      if (_vdp.interruptPending && _cpu.regs.iff1) {
        _cpu.interrupt();
      }
    }

    _psg.generateSamples(_samplesPerFrame);
    notifyListeners();
  }

  // ── Button handling ──────────────────────────────────────────────────────────

  /// Map EmulatorButton to IoPorts Button, triggering NMI for START.
  void pressButton(EmulatorButton button) {
    if (button == EmulatorButton.start) {
      _cpu.nmi();
      return;
    }
    _ioPorts.pressButton(_toIoButton(button));
  }

  void releaseButton(EmulatorButton button) {
    if (button == EmulatorButton.start) return; // NMI is edge-triggered
    _ioPorts.releaseButton(_toIoButton(button));
  }

  Button _toIoButton(EmulatorButton button) {
    switch (button) {
      case EmulatorButton.up:      return Button.up;
      case EmulatorButton.down:    return Button.down;
      case EmulatorButton.left:    return Button.left;
      case EmulatorButton.right:   return Button.right;
      case EmulatorButton.button1: return Button.button1;
      case EmulatorButton.button2: return Button.button2;
      case EmulatorButton.start:   return Button.start;
    }
  }

  // ── State save / load ────────────────────────────────────────────────────────

  /// Binary state format:
  ///   [0..3]  magic "SMS\0"
  ///   [4]     version = 1
  ///   [5..8]  offset of Z80 block   (uint32 LE)
  ///   [9..12] offset of VDP block   (uint32 LE)
  ///   [13..16] offset of PSG block  (uint32 LE)
  ///   [17..20] offset of MEM block  (uint32 LE)
  ///   followed by each block in order
  Uint8List saveState() {
    final z80Data = _serializeZ80();
    final vdpData = _serializeVdp();
    final psgData = _serializePsg();
    final memData = _serializeMemory();

    const headerSize = 21; // 4 magic + 1 version + 4*4 offsets
    final z80Offset  = headerSize;
    final vdpOffset  = z80Offset + z80Data.length;
    final psgOffset  = vdpOffset + vdpData.length;
    final memOffset  = psgOffset + psgData.length;
    final totalSize  = memOffset + memData.length;

    final buf = ByteData(totalSize);
    int pos = 0;

    // Magic "SMS\0"
    buf.setUint8(pos++, 0x53); // S
    buf.setUint8(pos++, 0x4D); // M
    buf.setUint8(pos++, 0x53); // S
    buf.setUint8(pos++, 0x00); // \0

    // Version
    buf.setUint8(pos++, 1);

    // Offsets (uint32 LE)
    buf.setUint32(pos, z80Offset,  Endian.little); pos += 4;
    buf.setUint32(pos, vdpOffset,  Endian.little); pos += 4;
    buf.setUint32(pos, psgOffset,  Endian.little); pos += 4;
    buf.setUint32(pos, memOffset,  Endian.little); pos += 4;

    final result = buf.buffer.asUint8List();
    result.setRange(z80Offset, z80Offset + z80Data.length, z80Data);
    result.setRange(vdpOffset, vdpOffset + vdpData.length, vdpData);
    result.setRange(psgOffset, psgOffset + psgData.length, psgData);
    result.setRange(memOffset, memOffset + memData.length, memData);

    return result;
  }

  void loadState(Uint8List data) {
    if (data.length < 21) throw ArgumentError('State data too short');
    // Verify magic
    if (data[0] != 0x53 || data[1] != 0x4D || data[2] != 0x53 || data[3] != 0x00) {
      throw ArgumentError('Invalid state magic');
    }
    if (data[4] != 1) throw ArgumentError('Unsupported state version: ${data[4]}');

    final bd = ByteData.sublistView(data);
    final z80Offset = bd.getUint32(5,  Endian.little);
    final vdpOffset = bd.getUint32(9,  Endian.little);
    final psgOffset = bd.getUint32(13, Endian.little);
    final memOffset = bd.getUint32(17, Endian.little);

    _deserializeZ80(data, z80Offset);
    _deserializeVdp(data, vdpOffset);
    _deserializePsg(data, psgOffset);
    _deserializeMemory(data, memOffset);

    _excessCycles = 0;
  }

  // ── Z80 serialization ────────────────────────────────────────────────────────

  // Layout (30 bytes):
  //   AF, BC, DE, HL, AF', BC', DE', HL', IX, IY, PC, SP  (16-bit LE each = 24 bytes)
  //   I, R, IM  (1 byte each = 3 bytes)
  //   flags: IFF1, IFF2, halted  (1 byte each = 3 bytes)
  static const int _z80StateSize = 30;

  Uint8List _serializeZ80() {
    final regs = _cpu.regs;
    final bd = ByteData(_z80StateSize);
    int pos = 0;

    bd.setUint16(pos, regs.af,  Endian.little); pos += 2;
    bd.setUint16(pos, regs.bc,  Endian.little); pos += 2;
    bd.setUint16(pos, regs.de,  Endian.little); pos += 2;
    bd.setUint16(pos, regs.hl,  Endian.little); pos += 2;

    // Shadow registers: swap to access, serialize, swap back
    regs.exAF();
    regs.exx();
    bd.setUint16(pos, regs.af,  Endian.little); pos += 2; // AF'
    bd.setUint16(pos, regs.bc,  Endian.little); pos += 2; // BC'
    bd.setUint16(pos, regs.de,  Endian.little); pos += 2; // DE'
    bd.setUint16(pos, regs.hl,  Endian.little); pos += 2; // HL'
    regs.exAF();
    regs.exx();

    bd.setUint16(pos, regs.ix,  Endian.little); pos += 2;
    bd.setUint16(pos, regs.iy,  Endian.little); pos += 2;
    bd.setUint16(pos, regs.pc,  Endian.little); pos += 2;
    bd.setUint16(pos, regs.sp,  Endian.little); pos += 2;

    bd.setUint8(pos++, regs.i);
    bd.setUint8(pos++, regs.r);
    bd.setUint8(pos++, regs.im);
    bd.setUint8(pos++, regs.iff1 ? 1 : 0);
    bd.setUint8(pos++, regs.iff2 ? 1 : 0);
    bd.setUint8(pos++, regs.halted ? 1 : 0);

    return bd.buffer.asUint8List();
  }

  void _deserializeZ80(Uint8List data, int offset) {
    final regs = _cpu.regs;
    final bd = ByteData.sublistView(data, offset, offset + _z80StateSize);
    int pos = 0;

    regs.af = bd.getUint16(pos, Endian.little); pos += 2;
    regs.bc = bd.getUint16(pos, Endian.little); pos += 2;
    regs.de = bd.getUint16(pos, Endian.little); pos += 2;
    regs.hl = bd.getUint16(pos, Endian.little); pos += 2;

    // Shadow registers: swap, restore, swap back
    regs.exAF();
    regs.exx();
    regs.af = bd.getUint16(pos, Endian.little); pos += 2; // AF'
    regs.bc = bd.getUint16(pos, Endian.little); pos += 2; // BC'
    regs.de = bd.getUint16(pos, Endian.little); pos += 2; // DE'
    regs.hl = bd.getUint16(pos, Endian.little); pos += 2; // HL'
    regs.exAF();
    regs.exx();

    regs.ix = bd.getUint16(pos, Endian.little); pos += 2;
    regs.iy = bd.getUint16(pos, Endian.little); pos += 2;
    regs.pc = bd.getUint16(pos, Endian.little); pos += 2;
    regs.sp = bd.getUint16(pos, Endian.little); pos += 2;

    regs.i      = bd.getUint8(pos++);
    regs.r      = bd.getUint8(pos++);
    regs.im     = bd.getUint8(pos++);
    regs.iff1   = bd.getUint8(pos++) != 0;
    regs.iff2   = bd.getUint8(pos++) != 0;
    regs.halted = bd.getUint8(pos++) != 0;
  }

  // ── VDP serialization ────────────────────────────────────────────────────────

  // Layout: 16 registers (16 bytes) + VRAM (16384 bytes) + CRAM (32 bytes) = 16432 bytes
  static const int _vdpStateSize = 16 + 16384 + 32;

  Uint8List _serializeVdp() {
    final buf = Uint8List(_vdpStateSize);
    int pos = 0;
    for (int i = 0; i < 16; i++) {
      buf[pos++] = _vdp.registers[i];
    }
    buf.setRange(pos, pos + 16384, _vdp.vram);
    pos += 16384;
    buf.setRange(pos, pos + 32, _vdp.cram);
    return buf;
  }

  void _deserializeVdp(Uint8List data, int offset) {
    int pos = offset;
    for (int i = 0; i < 16; i++) {
      _vdp.registers[i] = data[pos++];
    }
    _vdp.vram.setRange(0, 16384, data, pos);
    pos += 16384;
    _vdp.cram.setRange(0, 32, data, pos);
  }

  // ── PSG serialization ────────────────────────────────────────────────────────

  // Layout: 3 tone regs (uint16 LE each = 6 bytes) + 4 volumes (1 byte each = 4 bytes) = 10 bytes
  static const int _psgStateSize = 10;

  Uint8List _serializePsg() {
    final bd = ByteData(_psgStateSize);
    int pos = 0;
    for (int i = 0; i < 3; i++) {
      bd.setUint16(pos, _psg.toneRegisters[i], Endian.little); pos += 2;
    }
    for (int i = 0; i < 4; i++) {
      bd.setUint8(pos++, _psg.volumes[i]);
    }
    return bd.buffer.asUint8List();
  }

  void _deserializePsg(Uint8List data, int offset) {
    final bd = ByteData.sublistView(data, offset, offset + _psgStateSize);
    int pos = 0;
    for (int i = 0; i < 3; i++) {
      _psg.toneRegisters[i] = bd.getUint16(pos, Endian.little); pos += 2;
    }
    for (int i = 0; i < 4; i++) {
      _psg.volumes[i] = bd.getUint8(pos++);
    }
  }

  // ── Memory serialization ─────────────────────────────────────────────────────

  // Layout: 8192 bytes RAM + slot0 + slot1 + slot2 + ramControl (4 bytes) = 8196 bytes
  static const int _memStateSize = 8192 + 4;

  Uint8List _serializeMemory() {
    final buf = Uint8List(_memStateSize);
    buf.setRange(0, 8192, _memoryBus.ram);
    buf[8192] = _memoryBus.slot0Bank;
    buf[8193] = _memoryBus.slot1Bank;
    buf[8194] = _memoryBus.slot2Bank;
    buf[8195] = _memoryBus.ramControl;
    return buf;
  }

  // Amendment E: use restoreRamDirect + restoreBankState instead of write()
  void _deserializeMemory(Uint8List data, int offset) {
    final ramData = Uint8List.sublistView(data, offset, offset + 8192);
    _memoryBus.restoreRamDirect(ramData);
    offset += 8192;
    int s0     = data[offset++];
    int s1     = data[offset++];
    int s2     = data[offset++];
    int ramCtrl = data[offset++];
    _memoryBus.restoreBankState(s0, s1, s2, ramCtrl);
  }
}
