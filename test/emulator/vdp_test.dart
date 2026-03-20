import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/vdp.dart';

void main() {
  late Vdp vdp;

  setUp(() {
    vdp = Vdp();
  });

  test('initial state', () {
    expect(vdp.vCounter, 0);
    expect(vdp.frameBuffer.length, 256 * 192);
    expect(vdp.statusRegister, 0);
  });

  group('control port writes', () {
    test('write to VRAM address', () {
      vdp.writeControl(0x00);
      vdp.writeControl(0x40); // VRAM write command
      vdp.writeData(0xAA);
      vdp.writeControl(0x00);
      vdp.writeControl(0x00); // VRAM read command
      vdp.readData(); // discard buffer
      expect(vdp.readData(), 0xAA);
    });

    test('VDP register write', () {
      vdp.writeControl(0xFF);
      vdp.writeControl(0x80); // Register 0 = 0xFF
      expect(vdp.registers[0], 0xFF);
    });

    test('address latch resets on status read', () {
      vdp.writeControl(0x34);
      vdp.readStatus(); // resets latch
      vdp.writeControl(0x00);
      vdp.writeControl(0x40); // VRAM write command
    });
  });

  group('CRAM writes', () {
    test('write to CRAM', () {
      vdp.writeControl(0x00);
      vdp.writeControl(0xC0); // CRAM write
      vdp.writeData(0x3F);
      expect(vdp.cram[0], 0x3F);
    });
  });

  group('status register', () {
    test('reading status clears flags and latch', () {
      vdp.setVBlankFlag();
      int status = vdp.readStatus();
      expect(status & 0x80, 0x80);
      status = vdp.readStatus();
      expect(status & 0x80, 0x00);
    });
  });

  group('scanline rendering', () {
    test('V counter increments per scanline', () {
      expect(vdp.vCounter, 0);
      vdp.renderScanline();
      expect(vdp.vCounter, 1);
    });

    test('V counter wraps after 262 scanlines', () {
      for (int i = 0; i < 262; i++) {
        vdp.renderScanline();
      }
      expect(vdp.vCounter, 0);
    });

    test('VBlank interrupt flag set at scanline 192', () {
      for (int i = 0; i < 193; i++) {
        vdp.renderScanline();
      }
      expect(vdp.statusRegister & 0x80, 0x80);
    });
  });

  test('H counter returns value', () {
    expect(vdp.hCounter, isA<int>());
  });

  group('read buffer behavior', () {
    test('data read returns buffered value', () {
      vdp.writeControl(0x00);
      vdp.writeControl(0x40);
      vdp.writeData(0xAA);
      vdp.writeData(0xBB);

      vdp.writeControl(0x00);
      vdp.writeControl(0x00);

      vdp.readData(); // discard buffered value
      int second = vdp.readData();
      expect(second, 0xAA);
    });
  });

  test('background tile renders correct pixels', () {
    // Set up Mode 4
    vdp.writeControl(0x06); vdp.writeControl(0x80); // reg0 = 0x06
    vdp.writeControl(0x00); vdp.writeControl(0x81); // reg1 = 0x00
    vdp.writeControl(0xFF); vdp.writeControl(0x82); // reg2 = 0xFF (name table at 0x3800)
    vdp.writeControl(0xFF); vdp.writeControl(0x85); // reg5 = 0xFF (SAT at 0x3F00, away from tile data)

    // Write SAT terminator so no sprites render
    vdp.writeControl(0x00); vdp.writeControl(0x7F); // VRAM write at 0x3F00
    vdp.writeData(0xD0); // sprite list terminator

    // Write a tile pattern to VRAM at tile 0
    vdp.writeControl(0x00); vdp.writeControl(0x40); // VRAM write at 0x0000
    for (int row = 0; row < 8; row++) {
      vdp.writeData(0xFF); // plane 0 = all 1s
      vdp.writeData(0x00);
      vdp.writeData(0x00);
      vdp.writeData(0x00);
    }

    // Write name table entry at 0x3800
    vdp.writeControl(0x00); vdp.writeControl(0x78); // VRAM write at 0x3800
    vdp.writeData(0x00); vdp.writeData(0x00);

    // Write CRAM color 1
    vdp.writeControl(0x01); vdp.writeControl(0xC0); // CRAM write at index 1
    vdp.writeData(0x03); // Red

    vdp.renderScanline();
    int pixel = vdp.frameBuffer[0];
    expect(pixel & 0x00FFFFFF, isNot(0));
  });
}
