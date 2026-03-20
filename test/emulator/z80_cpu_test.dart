import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/z80_cpu.dart';
import 'package:sega3/emulator/bus.dart';

class TestBus implements Bus {
  final Uint8List memory = Uint8List(65536);
  final Map<int, int> ioPorts = {};
  @override int read(int address) => memory[address & 0xFFFF];
  @override void write(int address, int value) => memory[address & 0xFFFF] = value & 0xFF;
  @override int ioRead(int port) => ioPorts[port & 0xFF] ?? 0xFF;
  @override void ioWrite(int port, int value) => ioPorts[port & 0xFF] = value & 0xFF;
  void loadAt(int address, List<int> data) {
    for (int i = 0; i < data.length; i++) { memory[(address + i) & 0xFFFF] = data[i] & 0xFF; }
  }
}

void main() {
  late Z80CPU cpu;
  late TestBus bus;

  setUp(() {
    bus = TestBus();
    cpu = Z80CPU(bus);
  });

  test('NOP takes 4 cycles', () {
    bus.loadAt(0, [0x00]);
    expect(cpu.step(), 4);
    expect(cpu.regs.pc, 1);
  });

  test('LD A, n', () {
    bus.loadAt(0, [0x3E, 0x42]);
    expect(cpu.step(), 7);
    expect(cpu.regs.a, 0x42);
  });

  test('LD B, n', () {
    bus.loadAt(0, [0x06, 0xAB]);
    cpu.step();
    expect(cpu.regs.b, 0xAB);
  });

  test('LD r, r', () {
    bus.loadAt(0, [0x3E, 0x55, 0x47]); // LD A,0x55; LD B,A
    cpu.step(); cpu.step();
    expect(cpu.regs.b, 0x55);
  });

  test('LD HL, nn', () {
    bus.loadAt(0, [0x21, 0x34, 0x12]);
    cpu.step();
    expect(cpu.regs.hl, 0x1234);
  });

  test('LD BC, nn', () {
    bus.loadAt(0, [0x01, 0xCD, 0xAB]);
    cpu.step();
    expect(cpu.regs.bc, 0xABCD);
  });

  test('LD SP, nn', () {
    bus.loadAt(0, [0x31, 0xFF, 0xDF]);
    cpu.step();
    expect(cpu.regs.sp, 0xDFFF);
  });

  test('INC A', () {
    bus.loadAt(0, [0x3E, 0x0F, 0x3C]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x10);
    expect(cpu.regs.flagH, true);
    expect(cpu.regs.flagZ, false);
  });

  test('INC A overflow', () {
    bus.loadAt(0, [0x3E, 0xFF, 0x3C]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x00);
    expect(cpu.regs.flagZ, true);
  });

  test('DEC A', () {
    bus.loadAt(0, [0x3E, 0x01, 0x3D]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x00);
    expect(cpu.regs.flagZ, true);
    expect(cpu.regs.flagN, true);
  });

  test('ADD A, B', () {
    bus.loadAt(0, [0x3E, 0x10, 0x06, 0x20, 0x80]);
    cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x30);
    expect(cpu.regs.flagC, false);
  });

  test('ADD A, B with carry', () {
    bus.loadAt(0, [0x3E, 0xFF, 0x06, 0x01, 0x80]);
    cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x00);
    expect(cpu.regs.flagC, true);
    expect(cpu.regs.flagZ, true);
  });

  test('SUB B', () {
    bus.loadAt(0, [0x3E, 0x30, 0x06, 0x10, 0x90]);
    cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x20);
    expect(cpu.regs.flagN, true);
  });

  test('AND B', () {
    bus.loadAt(0, [0x3E, 0xFF, 0x06, 0x0F, 0xA0]);
    cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x0F);
    expect(cpu.regs.flagH, true);
  });

  test('OR B', () {
    bus.loadAt(0, [0x3E, 0xF0, 0x06, 0x0F, 0xB0]);
    cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.a, 0xFF);
  });

  test('XOR A', () {
    bus.loadAt(0, [0x3E, 0xFF, 0xAF]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x00);
    expect(cpu.regs.flagZ, true);
  });

  test('CP B', () {
    bus.loadAt(0, [0x3E, 0x42, 0x06, 0x42, 0xB8]);
    cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x42);
    expect(cpu.regs.flagZ, true);
  });

  test('JP nn', () {
    bus.loadAt(0, [0xC3, 0x00, 0x10]);
    cpu.step();
    expect(cpu.regs.pc, 0x1000);
  });

  test('JP Z taken', () {
    bus.loadAt(0, [0x3E, 0xFF, 0xAF, 0xCA, 0x00, 0x20]);
    cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.pc, 0x2000);
  });

  test('JR e', () {
    bus.loadAt(0, [0x18, 0x05]);
    cpu.step();
    expect(cpu.regs.pc, 7);
  });

  test('JR negative', () {
    bus.loadAt(0x10, [0x18, 0xFE]);
    cpu.regs.pc = 0x10;
    cpu.step();
    expect(cpu.regs.pc, 0x10);
  });

  test('CALL and RET', () {
    bus.loadAt(0, [0x31, 0x00, 0xE0, 0xCD, 0x00, 0x10]);
    bus.loadAt(0x1000, [0xC9]);
    cpu.step(); cpu.step();
    expect(cpu.regs.pc, 0x1000);
    cpu.step();
    expect(cpu.regs.pc, 0x0006);
  });

  test('PUSH and POP', () {
    bus.loadAt(0, [0x31, 0x00, 0xE0, 0x01, 0x34, 0x12, 0xC5, 0xD1]);
    cpu.step(); cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.de, 0x1234);
  });

  test('DI and EI', () {
    bus.loadAt(0, [0xF3, 0xFB]);
    cpu.step();
    expect(cpu.regs.iff1, false);
    cpu.step();
    expect(cpu.regs.iff1, true);
  });

  test('OUT and IN', () {
    bus.loadAt(0, [0x3E, 0xAA, 0xD3, 0x7E, 0xDB, 0x7E]);
    cpu.step(); cpu.step();
    expect(bus.ioPorts[0x7E], 0xAA);
    cpu.regs.a = 0;
    cpu.step();
    expect(cpu.regs.a, 0xAA);
  });

  test('DJNZ loop', () {
    bus.loadAt(0, [0x06, 0x03, 0x3C, 0x10, 0xFD]);
    cpu.step(); // LD B,3
    for (int i = 0; i < 6; i++) { cpu.step(); } // 3x (INC A + DJNZ)
    expect(cpu.regs.a, 3);
    expect(cpu.regs.b, 0);
  });

  test('EX DE, HL', () {
    bus.loadAt(0, [0x21, 0x34, 0x12, 0x11, 0x78, 0x56, 0xEB]);
    cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.hl, 0x5678);
    expect(cpu.regs.de, 0x1234);
  });

  test('RLCA', () {
    bus.loadAt(0, [0x3E, 0x85, 0x07]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x0B);
    expect(cpu.regs.flagC, true);
  });

  test('RRCA', () {
    bus.loadAt(0, [0x3E, 0x85, 0x0F]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0xC2);
    expect(cpu.regs.flagC, true);
  });

  test('INC HL 16-bit', () {
    bus.loadAt(0, [0x21, 0xFF, 0xFF, 0x23]);
    cpu.step(); cpu.step();
    expect(cpu.regs.hl, 0x0000);
  });

  test('DEC BC 16-bit', () {
    bus.loadAt(0, [0x01, 0x00, 0x00, 0x0B]);
    cpu.step(); cpu.step();
    expect(cpu.regs.bc, 0xFFFF);
  });

  test('LD A, (HL)', () {
    bus.loadAt(0, [0x21, 0x00, 0x80, 0x7E]);
    bus.write(0x8000, 0xBB);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0xBB);
  });

  test('LD (HL), A', () {
    bus.loadAt(0, [0x3E, 0xCC, 0x21, 0x00, 0x80, 0x77]);
    cpu.step(); cpu.step(); cpu.step();
    expect(bus.read(0x8000), 0xCC);
  });

  test('RST 38h', () {
    bus.loadAt(0, [0x31, 0x00, 0xE0, 0xFF]);
    cpu.step(); cpu.step();
    expect(cpu.regs.pc, 0x0038);
  });

  test('HALT', () {
    bus.loadAt(0, [0x76]);
    cpu.step();
    expect(cpu.regs.halted, true);
  });

  // CB prefix tests
  test('BIT 7, A zero', () {
    bus.loadAt(0, [0x3E, 0x00, 0xCB, 0x7F]);
    cpu.step(); cpu.step();
    expect(cpu.regs.flagZ, true);
  });

  test('BIT 7, A set', () {
    bus.loadAt(0, [0x3E, 0x80, 0xCB, 0x7F]);
    cpu.step(); cpu.step();
    expect(cpu.regs.flagZ, false);
  });

  test('SET 0, A', () {
    bus.loadAt(0, [0x3E, 0x00, 0xCB, 0xC7]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x01);
  });

  test('RES 7, A', () {
    bus.loadAt(0, [0x3E, 0xFF, 0xCB, 0xBF]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x7F);
  });

  test('SLA A', () {
    bus.loadAt(0, [0x3E, 0x85, 0xCB, 0x27]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x0A);
    expect(cpu.regs.flagC, true);
  });

  test('SRL A', () {
    bus.loadAt(0, [0x3E, 0x85, 0xCB, 0x3F]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x42);
    expect(cpu.regs.flagC, true);
  });

  // ED prefix tests
  test('IM 1', () {
    bus.loadAt(0, [0xED, 0x56]);
    cpu.step();
    expect(cpu.regs.im, 1);
  });

  test('LD I, A', () {
    bus.loadAt(0, [0x3E, 0x42, 0xED, 0x47]);
    cpu.step(); cpu.step();
    expect(cpu.regs.i, 0x42);
  });

  test('LDIR', () {
    bus.loadAt(0x1000, [0xAA, 0xBB, 0xCC]);
    bus.loadAt(0, [0x21, 0x00, 0x10, 0x11, 0x00, 0x20, 0x01, 0x03, 0x00, 0xED, 0xB0]);
    cpu.step(); cpu.step(); cpu.step(); cpu.step();
    expect(bus.read(0x2000), 0xAA);
    expect(bus.read(0x2001), 0xBB);
    expect(bus.read(0x2002), 0xCC);
    expect(cpu.regs.bc, 0);
  });

  test('NEG', () {
    bus.loadAt(0, [0x3E, 0x01, 0xED, 0x44]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0xFF);
    expect(cpu.regs.flagC, true);
  });

  // DD prefix (IX) tests
  test('LD IX, nn', () {
    bus.loadAt(0, [0xDD, 0x21, 0x34, 0x12]);
    cpu.step();
    expect(cpu.regs.ix, 0x1234);
  });

  test('LD A, (IX+d)', () {
    bus.write(0x1005, 0xAA);
    bus.loadAt(0, [0xDD, 0x21, 0x00, 0x10, 0xDD, 0x7E, 0x05]);
    cpu.step(); cpu.step();
    expect(cpu.regs.a, 0xAA);
  });

  // FD prefix (IY) tests
  test('LD IY, nn', () {
    bus.loadAt(0, [0xFD, 0x21, 0x78, 0x56]);
    cpu.step();
    expect(cpu.regs.iy, 0x5678);
  });

  // Interrupt tests
  test('NMI', () {
    bus.loadAt(0, [0x31, 0x00, 0xE0]);
    cpu.step();
    cpu.regs.pc = 0x1234;
    cpu.nmi();
    expect(cpu.regs.pc, 0x0066);
    expect(cpu.regs.iff1, false);
  });

  test('INT IM1', () {
    bus.loadAt(0, [0x31, 0x00, 0xE0, 0xFB, 0xED, 0x56]);
    cpu.step(); cpu.step(); cpu.step();
    cpu.regs.pc = 0x1234;
    cpu.interrupt();
    expect(cpu.regs.pc, 0x0038);
  });

  test('INT disabled', () {
    bus.loadAt(0, [0x31, 0x00, 0xE0, 0xF3]);
    cpu.step(); cpu.step();
    cpu.regs.pc = 0x1234;
    cpu.interrupt();
    expect(cpu.regs.pc, 0x1234);
  });

  test('DAA BCD addition', () {
    bus.loadAt(0, [0x3E, 0x15, 0xC6, 0x27, 0x27]);
    cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.a, 0x42);
  });

  test('OTIR', () {
    bus.loadAt(0x1000, [0xAA, 0xBB, 0xCC]);
    bus.loadAt(0, [0x21, 0x00, 0x10, 0x01, 0x03, 0xBE, 0xED, 0xB3]);
    cpu.step(); cpu.step(); cpu.step();
    expect(cpu.regs.b, 0);
  });
}
