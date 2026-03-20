import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/memory_bus.dart';
import 'package:sega3/emulator/rom_header.dart';

void main() {
  late MemoryBus memBus;

  setUp(() {
    // Create a 256KB ROM filled with page markers
    final rom = Uint8List(256 * 1024);
    for (int page = 0; page < 16; page++) {
      for (int i = 0; i < 16384; i++) {
        rom[page * 16384 + i] = page;
      }
    }
    // Add TMR SEGA header
    final magic = 'TMR SEGA'.codeUnits;
    for (int i = 0; i < magic.length; i++) rom[0x7FF0 + i] = magic[i];

    memBus = MemoryBus(rom: rom, mapperType: MapperType.sega);
  });

  test('initial bank mapping: slot0=0, slot1=1, slot2=2', () {
    expect(memBus.read(0x0000), 0);
    expect(memBus.read(0x4000), 1);
    expect(memBus.read(0x8000), 2);
  });

  test('RAM read/write at \$C000-\$DFFF', () {
    memBus.write(0xC000, 0xAA);
    expect(memBus.read(0xC000), 0xAA);
  });

  test('RAM mirror at \$E000-\$FFFF', () {
    memBus.write(0xC000, 0xBB);
    expect(memBus.read(0xE000), 0xBB);
    memBus.write(0xE100, 0xCC);
    expect(memBus.read(0xC100), 0xCC);
  });

  test('bank switching via \$FFFF changes slot 2', () {
    memBus.write(0xFFFF, 5);
    expect(memBus.read(0x8000), 5);
  });

  test('bank switching via \$FFFE changes slot 1', () {
    memBus.write(0xFFFE, 3);
    expect(memBus.read(0x4000), 3);
  });

  test('bank switching via \$FFFD changes slot 0', () {
    memBus.write(0xFFFD, 4);
    expect(memBus.read(0x0400), 4);
    expect(memBus.read(0x0000), 0);
  });

  test('\$0000-\$03FF always maps to ROM start regardless of slot 0 bank', () {
    memBus.write(0xFFFD, 7);
    expect(memBus.read(0x0000), 0);
    expect(memBus.read(0x03FF), 0);
    expect(memBus.read(0x0400), 7);
  });

  test('writes to ROM space are silently ignored', () {
    int original = memBus.read(0x0000);
    memBus.write(0x0000, 0xFF);
    expect(memBus.read(0x0000), original);
  });

  test('cartridge RAM enable via \$FFFC', () {
    memBus.write(0xFFFC, 0x08);
    memBus.write(0x8000, 0xDD);
    expect(memBus.read(0x8000), 0xDD);
  });
}
