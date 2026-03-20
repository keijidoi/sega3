import 'dart:typed_data';
import 'package:sega3/emulator/rom_header.dart';

class MemoryBus {
  final Uint8List _rom;
  final Uint8List _ram = Uint8List(8192); // 8KB system RAM
  final Uint8List _cartRam = Uint8List(32768); // Up to 32KB cart RAM
  final MapperType _mapperType;

  // Bank registers (Sega mapper)
  int _slot0Bank = 0;
  int _slot1Bank = 1;
  int _slot2Bank = 2;
  int _ramControl = 0; // $FFFC register

  final int _pageCount;

  // Codemasters mapper
  int _cmSlot0 = 0;
  int _cmSlot1 = 1;
  int _cmSlot2 = 0;

  MemoryBus({required Uint8List rom, required MapperType mapperType})
      : _rom = rom,
        _mapperType = mapperType,
        _pageCount = (rom.length / 16384).ceil().clamp(1, 256);

  int read(int address) {
    address &= 0xFFFF;

    if (address < 0xC000) {
      return _readRom(address);
    }

    // $C000-$DFFF: System RAM, $E000-$FFFF: RAM mirror
    return _ram[address & 0x1FFF];
  }

  void write(int address, int value) {
    address &= 0xFFFF;
    value &= 0xFF;

    if (_mapperType == MapperType.codemasters) {
      if (address == 0x0000) {
        _cmSlot0 = value % _pageCount;
        return;
      }
      if (address == 0x4000) {
        _cmSlot1 = value % _pageCount;
        return;
      }
      if (address == 0x8000) {
        _cmSlot2 = value % _pageCount;
        return;
      }
    }

    if (address >= 0xC000) {
      _ram[address & 0x1FFF] = value;

      // Check for bank register writes (mapped to RAM $FFFC-$FFFF)
      if (_mapperType == MapperType.sega) {
        int ramAddr = address & 0x1FFF;
        if (ramAddr == 0x1FFC) {
          _ramControl = value;
        } else if (ramAddr == 0x1FFD) {
          _slot0Bank = value % _pageCount;
        } else if (ramAddr == 0x1FFE) {
          _slot1Bank = value % _pageCount;
        } else if (ramAddr == 0x1FFF) {
          _slot2Bank = value % _pageCount;
        }
      }
      return;
    }

    // Cartridge RAM write (slot 2)
    if (address >= 0x8000 && address < 0xC000 && _isCartRamEnabled) {
      _cartRam[address - 0x8000 + _cartRamOffset] = value;
      return;
    }

    // Writes to ROM space — silently ignored
  }

  int _readRom(int address) {
    if (_mapperType == MapperType.codemasters) {
      return _readCodemasters(address);
    }

    // Sega mapper (or no mapper)
    if (address < 0x0400) {
      // First 1KB always maps to start of ROM
      return _romRead(address);
    } else if (address < 0x4000) {
      return _romRead(_slot0Bank * 16384 + address);
    } else if (address < 0x8000) {
      return _romRead(_slot1Bank * 16384 + (address - 0x4000));
    } else {
      // Slot 2: $8000-$BFFF
      if (_isCartRamEnabled) {
        return _cartRam[address - 0x8000 + _cartRamOffset];
      }
      return _romRead(_slot2Bank * 16384 + (address - 0x8000));
    }
  }

  int _readCodemasters(int address) {
    if (address < 0x4000) {
      return _romRead(_cmSlot0 * 16384 + address);
    } else if (address < 0x8000) {
      return _romRead(_cmSlot1 * 16384 + (address - 0x4000));
    } else {
      return _romRead(_cmSlot2 * 16384 + (address - 0x8000));
    }
  }

  int _romRead(int offset) {
    if (offset >= _rom.length) return 0;
    return _rom[offset];
  }

  bool get _isCartRamEnabled => (_ramControl & 0x08) != 0;
  int get _cartRamOffset => (_ramControl & 0x04) != 0 ? 16384 : 0;

  /// Get cart RAM for battery backup save
  Uint8List get cartRam => _cartRam;
  bool get hasCartRam => _isCartRamEnabled;

  /// Get system RAM for state save
  Uint8List get ram => _ram;
  int get slot0Bank => _slot0Bank;
  int get slot1Bank => _slot1Bank;
  int get slot2Bank => _slot2Bank;
  int get ramControl => _ramControl;

  /// Restore RAM without triggering bank register side effects (for state load)
  void restoreRamDirect(Uint8List data) {
    for (int i = 0; i < data.length && i < _ram.length; i++) {
      _ram[i] = data[i];
    }
  }

  /// Restore bank register state directly (for state load)
  void restoreBankState(int slot0, int slot1, int slot2, int ramCtrl) {
    _slot0Bank = slot0 % _pageCount;
    _slot1Bank = slot1 % _pageCount;
    _slot2Bank = slot2 % _pageCount;
    _ramControl = ramCtrl;
  }
}
