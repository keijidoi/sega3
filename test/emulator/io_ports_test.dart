import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/io_ports.dart';
import 'package:sega3/emulator/vdp.dart';
import 'package:sega3/emulator/psg.dart';

void main() {
  late IoPorts io;
  late Vdp vdp;
  late Psg psg;

  setUp(() {
    vdp = Vdp();
    psg = Psg();
    io = IoPorts(vdp: vdp, psg: psg);
  });

  test('port \$BF read returns VDP status', () {
    vdp.setVBlankFlag();
    int status = io.read(0xBF);
    expect(status & 0x80, 0x80);
  });

  test('port \$BF write goes to VDP control', () {
    io.write(0xBF, 0xFF);
    io.write(0xBF, 0x80);
    expect(vdp.registers[0], 0xFF);
  });

  test('port \$BE read returns VDP data', () {
    io.write(0xBF, 0x00);
    io.write(0xBF, 0x40);
    io.write(0xBE, 0x42);
    io.write(0xBF, 0x00);
    io.write(0xBF, 0x00);
    io.read(0xBE);
    expect(io.read(0xBE), 0x42);
  });

  test('port \$7E write goes to PSG', () {
    io.write(0x7E, 0x9F);
    expect(psg.volumes[0], 0x0F);
  });

  test('port \$7E read returns V counter', () {
    int v = io.read(0x7E);
    expect(v, vdp.vCounter);
  });

  test('port \$DC returns controller 1 state (all released)', () {
    expect(io.read(0xDC), 0xFF);
  });

  test('port \$DC reflects button presses', () {
    io.pressButton(Button.up);
    expect(io.read(0xDC) & 0x01, 0x00);
    io.releaseButton(Button.up);
    expect(io.read(0xDC) & 0x01, 0x01);
  });

  test('port \$3F returns export region', () {
    int val = io.read(0x3F);
    expect(val, isA<int>());
  });
}
