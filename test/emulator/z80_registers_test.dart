import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/z80_registers.dart';

void main() {
  late Z80Registers regs;

  setUp(() {
    regs = Z80Registers();
  });

  test('initial values are zero', () {
    expect(regs.a, 0);
    expect(regs.f, 0);
    expect(regs.b, 0);
    expect(regs.c, 0);
    expect(regs.d, 0);
    expect(regs.e, 0);
    expect(regs.h, 0);
    expect(regs.l, 0);
    expect(regs.pc, 0);
    expect(regs.sp, 0);
    expect(regs.ix, 0);
    expect(regs.iy, 0);
    expect(regs.i, 0);
    expect(regs.r, 0);
  });

  test('16-bit register pairs BC, DE, HL, AF', () {
    regs.b = 0x12;
    regs.c = 0x34;
    expect(regs.bc, 0x1234);
    regs.bc = 0xABCD;
    expect(regs.b, 0xAB);
    expect(regs.c, 0xCD);
    regs.d = 0x56;
    regs.e = 0x78;
    expect(regs.de, 0x5678);
    regs.h = 0x9A;
    regs.l = 0xBC;
    expect(regs.hl, 0x9ABC);
    regs.a = 0xFF;
    regs.f = 0x40;
    expect(regs.af, 0xFF40);
  });

  test('8-bit values are masked to 0xFF', () {
    regs.a = 0x1FF;
    expect(regs.a, 0xFF);
  });

  test('16-bit values are masked to 0xFFFF', () {
    regs.bc = 0x1FFFF;
    expect(regs.bc, 0xFFFF);
  });

  test('exchange AF with shadow AF', () {
    regs.a = 0x12;
    regs.f = 0x34;
    regs.exAF();
    expect(regs.a, 0);
    expect(regs.f, 0);
    regs.exAF();
    expect(regs.a, 0x12);
    expect(regs.f, 0x34);
  });

  test('exchange BC/DE/HL with shadow registers via EXX', () {
    regs.bc = 0x1111;
    regs.de = 0x2222;
    regs.hl = 0x3333;
    regs.exx();
    expect(regs.bc, 0);
    expect(regs.de, 0);
    expect(regs.hl, 0);
    regs.exx();
    expect(regs.bc, 0x1111);
    expect(regs.de, 0x2222);
    expect(regs.hl, 0x3333);
  });

  group('flags', () {
    test('carry flag', () {
      regs.flagC = true;
      expect(regs.flagC, true);
      expect(regs.f & 0x01, 0x01);
      regs.flagC = false;
      expect(regs.flagC, false);
    });

    test('zero flag', () {
      regs.flagZ = true;
      expect(regs.flagZ, true);
      expect(regs.f & 0x40, 0x40);
    });

    test('sign flag', () {
      regs.flagS = true;
      expect(regs.flagS, true);
      expect(regs.f & 0x80, 0x80);
    });

    test('half carry flag', () {
      regs.flagH = true;
      expect(regs.flagH, true);
      expect(regs.f & 0x10, 0x10);
    });

    test('parity/overflow flag', () {
      regs.flagPV = true;
      expect(regs.flagPV, true);
      expect(regs.f & 0x04, 0x04);
    });

    test('subtract flag', () {
      regs.flagN = true;
      expect(regs.flagN, true);
      expect(regs.f & 0x02, 0x02);
    });
  });
}
