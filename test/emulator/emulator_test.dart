import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/emulator.dart';

void main() {
  test('Emulator initializes with ROM', () {
    final rom = Uint8List(32 * 1024);
    rom[0] = 0x76; // HALT
    final emu = Emulator(rom);
    expect(emu.isRunning, false);
  });

  test('runFrame executes one frame of emulation', () {
    final rom = Uint8List(32 * 1024);
    rom[0] = 0x31; rom[1] = 0xF0; rom[2] = 0xDF; // LD SP, 0xDFF0
    rom[3] = 0x76; // HALT
    final emu = Emulator(rom);
    emu.runFrame();
    expect(emu.frameBuffer, isNotNull);
    expect(emu.frameBuffer.length, 256 * 192);
  });

  test('button press and release', () {
    final rom = Uint8List(32 * 1024);
    rom[0] = 0x76;
    final emu = Emulator(rom);
    emu.pressButton(EmulatorButton.up);
    emu.releaseButton(EmulatorButton.up);
  });

  test('state save and load roundtrip', () {
    final rom = Uint8List(32 * 1024);
    rom[0] = 0x3E; rom[1] = 0x42; // LD A, 0x42
    rom[2] = 0x76; // HALT
    final emu = Emulator(rom);
    emu.runFrame();

    final state = emu.saveState();
    expect(state, isNotNull);
    expect(state.length, greaterThan(0));

    emu.runFrame();
    emu.loadState(state);
  });
}
