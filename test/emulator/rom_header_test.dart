import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/rom_header.dart';

void main() {
  test('detect standard Sega mapper for 256KB ROM', () {
    final rom = Uint8List(256 * 1024);
    // Write TMR SEGA magic at 0x7FF0
    final magic = 'TMR SEGA'.codeUnits;
    for (int i = 0; i < magic.length; i++) {
      rom[0x7FF0 + i] = magic[i];
    }
    final header = RomHeader.parse(rom);
    expect(header.mapperType, MapperType.sega);
    expect(header.hasCopierHeader, false);
  });

  test('detect 512-byte copier header', () {
    final rom = Uint8List(256 * 1024 + 512);
    // TMR SEGA at 0x7FF0 + 512
    final magic = 'TMR SEGA'.codeUnits;
    for (int i = 0; i < magic.length; i++) {
      rom[0x7FF0 + 512 + i] = magic[i];
    }
    final header = RomHeader.parse(rom);
    expect(header.hasCopierHeader, true);
  });

  test('small ROM (32KB) uses no mapper', () {
    final rom = Uint8List(32 * 1024);
    final header = RomHeader.parse(rom);
    expect(header.mapperType, MapperType.none);
  });

  test('Codemasters mapper detection', () {
    final rom = Uint8List(256 * 1024);
    // No TMR SEGA header, but >48KB = likely Codemasters
    final header = RomHeader.parse(rom);
    expect(header.mapperType, MapperType.codemasters);
  });
}
