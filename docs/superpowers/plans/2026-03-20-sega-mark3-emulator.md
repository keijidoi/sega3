# Sega Mark III / Master System Emulator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a working Sega Mark III / Master System emulator in Flutter (Dart) that can play Alex Kidd in Miracle World, Hang-On, and Fantasy Zone on Android and iOS.

**Architecture:** Component-separated design with Z80 CPU, VDP, PSG, MemoryBus, and I/O as independent classes communicating via a Bus interface. Flutter UI uses CustomPainter for rendering and a virtual gamepad for input. Emulation loop driven by Ticker on the main isolate.

**Tech Stack:** Flutter/Dart, file_picker, path_provider, flutter_soloud

**Spec:** `docs/superpowers/specs/2026-03-20-sega-mark3-emulator-design.md`

---

## Phase 1: Project Setup & Z80 CPU Core

### Task 1: Project dependencies and Bus interface

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/emulator/bus.dart`

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Add under `dependencies:` in `pubspec.yaml`:

```yaml
  file_picker: ^8.0.0
  path_provider: ^2.1.0
  flutter_soloud: ^3.1.0
```

Remove `cupertino_icons` (not needed).

- [ ] **Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolve successfully.

- [ ] **Step 3: Create Bus abstract class**

Create `lib/emulator/bus.dart`:

```dart
abstract class Bus {
  int read(int address);
  void write(int address, int value);
  int ioRead(int port);
  void ioWrite(int port, int value);
}
```

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/emulator/bus.dart
git commit -m "feat: add dependencies and Bus interface"
```

---

### Task 2: Z80 Registers

**Files:**
- Create: `lib/emulator/z80_registers.dart`
- Create: `test/emulator/z80_registers_test.dart`

- [ ] **Step 1: Write failing test for Z80Registers**

Create `test/emulator/z80_registers_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/emulator/z80_registers_test.dart`
Expected: FAIL — `Z80Registers` not found.

- [ ] **Step 3: Implement Z80Registers**

Create `lib/emulator/z80_registers.dart`:

```dart
class Z80Registers {
  // Main registers
  int _a = 0, _f = 0;
  int _b = 0, _c = 0;
  int _d = 0, _e = 0;
  int _h = 0, _l = 0;

  // Shadow registers
  int _aShadow = 0, _fShadow = 0;
  int _bShadow = 0, _cShadow = 0;
  int _dShadow = 0, _eShadow = 0;
  int _hShadow = 0, _lShadow = 0;

  // Index registers
  int _ix = 0, _iy = 0;

  // Special registers
  int pc = 0;
  int sp = 0;
  int _i = 0;
  int _r = 0;

  // Interrupt state
  bool iff1 = false;
  bool iff2 = false;
  int im = 0; // Interrupt mode (0, 1, 2)
  bool halted = false;

  // 8-bit getters/setters with masking
  int get a => _a;
  set a(int v) => _a = v & 0xFF;
  int get f => _f;
  set f(int v) => _f = v & 0xFF;
  int get b => _b;
  set b(int v) => _b = v & 0xFF;
  int get c => _c;
  set c(int v) => _c = v & 0xFF;
  int get d => _d;
  set d(int v) => _d = v & 0xFF;
  int get e => _e;
  set e(int v) => _e = v & 0xFF;
  int get h => _h;
  set h(int v) => _h = v & 0xFF;
  int get l => _l;
  set l(int v) => _l = v & 0xFF;
  int get i => _i;
  set i(int v) => _i = v & 0xFF;
  int get r => _r;
  set r(int v) => _r = v & 0xFF;

  // 16-bit register pair getters/setters
  int get af => (_a << 8) | _f;
  set af(int v) {
    v &= 0xFFFF;
    _a = (v >> 8) & 0xFF;
    _f = v & 0xFF;
  }

  int get bc => (_b << 8) | _c;
  set bc(int v) {
    v &= 0xFFFF;
    _b = (v >> 8) & 0xFF;
    _c = v & 0xFF;
  }

  int get de => (_d << 8) | _e;
  set de(int v) {
    v &= 0xFFFF;
    _d = (v >> 8) & 0xFF;
    _e = v & 0xFF;
  }

  int get hl => (_h << 8) | _l;
  set hl(int v) {
    v &= 0xFFFF;
    _h = (v >> 8) & 0xFF;
    _l = v & 0xFF;
  }

  int get ix => _ix;
  set ix(int v) => _ix = v & 0xFFFF;
  int get iy => _iy;
  set iy(int v) => _iy = v & 0xFFFF;

  // Flag bit positions: S=7, Z=6, H=4, PV=2, N=1, C=0
  // Undocumented flags: bit5 (Y/F5), bit3 (X/F3) — tracked for accuracy
  bool get flagC => (_f & 0x01) != 0;
  set flagC(bool v) => _f = v ? (_f | 0x01) : (_f & ~0x01) & 0xFF;

  bool get flagN => (_f & 0x02) != 0;
  set flagN(bool v) => _f = v ? (_f | 0x02) : (_f & ~0x02) & 0xFF;

  bool get flagPV => (_f & 0x04) != 0;
  set flagPV(bool v) => _f = v ? (_f | 0x04) : (_f & ~0x04) & 0xFF;

  bool get flagH => (_f & 0x10) != 0;
  set flagH(bool v) => _f = v ? (_f | 0x10) : (_f & ~0x10) & 0xFF;

  bool get flagZ => (_f & 0x40) != 0;
  set flagZ(bool v) => _f = v ? (_f | 0x40) : (_f & ~0x40) & 0xFF;

  bool get flagS => (_f & 0x80) != 0;
  set flagS(bool v) => _f = v ? (_f | 0x80) : (_f & ~0x80) & 0xFF;

  // Exchange AF <-> AF'
  void exAF() {
    int tmpA = _a, tmpF = _f;
    _a = _aShadow;
    _f = _fShadow;
    _aShadow = tmpA;
    _fShadow = tmpF;
  }

  // Exchange BC, DE, HL <-> BC', DE', HL'
  void exx() {
    int tmp;
    tmp = _b; _b = _bShadow; _bShadow = tmp;
    tmp = _c; _c = _cShadow; _cShadow = tmp;
    tmp = _d; _d = _dShadow; _dShadow = tmp;
    tmp = _e; _e = _eShadow; _eShadow = tmp;
    tmp = _h; _h = _hShadow; _hShadow = tmp;
    tmp = _l; _l = _lShadow; _lShadow = tmp;
  }

  void reset() {
    _a = _f = _b = _c = _d = _e = _h = _l = 0;
    _aShadow = _fShadow = _bShadow = _cShadow = 0;
    _dShadow = _eShadow = _hShadow = _lShadow = 0;
    _ix = _iy = 0;
    pc = sp = 0;
    _i = _r = 0;
    iff1 = iff2 = false;
    im = 0;
    halted = false;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/emulator/z80_registers_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emulator/z80_registers.dart test/emulator/z80_registers_test.dart
git commit -m "feat: implement Z80 register file with shadow registers and flags"
```

---

### Task 3: Z80 CPU — Core structure and basic opcode execution

**Files:**
- Create: `lib/emulator/z80_cpu.dart`
- Create: `test/emulator/z80_cpu_test.dart`

- [ ] **Step 1: Write failing tests for Z80 CPU core**

Create `test/emulator/z80_cpu_test.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/z80_cpu.dart';
import 'package:sega3/emulator/bus.dart';

/// Simple Bus implementation for testing
class TestBus implements Bus {
  final Uint8List memory = Uint8List(65536);
  final Map<int, int> ioPorts = {};

  @override
  int read(int address) => memory[address & 0xFFFF];

  @override
  void write(int address, int value) {
    memory[address & 0xFFFF] = value & 0xFF;
  }

  @override
  int ioRead(int port) => ioPorts[port & 0xFF] ?? 0xFF;

  @override
  void ioWrite(int port, int value) {
    ioPorts[port & 0xFF] = value & 0xFF;
  }

  void loadAt(int address, List<int> data) {
    for (int i = 0; i < data.length; i++) {
      memory[(address + i) & 0xFFFF] = data[i] & 0xFF;
    }
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
    bus.loadAt(0, [0x00]); // NOP
    final cycles = cpu.step();
    expect(cycles, 4);
    expect(cpu.regs.pc, 1);
  });

  test('LD A, n (immediate)', () {
    bus.loadAt(0, [0x3E, 0x42]); // LD A, 0x42
    final cycles = cpu.step();
    expect(cycles, 7);
    expect(cpu.regs.a, 0x42);
    expect(cpu.regs.pc, 2);
  });

  test('LD B, n (immediate)', () {
    bus.loadAt(0, [0x06, 0xAB]); // LD B, 0xAB
    cpu.step();
    expect(cpu.regs.b, 0xAB);
  });

  test('LD r, r (register to register)', () {
    bus.loadAt(0, [0x3E, 0x55, 0x47]); // LD A,0x55; LD B,A
    cpu.step();
    cpu.step();
    expect(cpu.regs.b, 0x55);
  });

  test('LD (HL), n', () {
    bus.loadAt(0, [0x21, 0x00, 0x80, 0x36, 0xAA]);
    // LD HL, 0x8000; LD (HL), 0xAA
    cpu.step();
    cpu.step();
    expect(bus.read(0x8000), 0xAA);
  });

  test('LD HL, nn (immediate 16-bit)', () {
    bus.loadAt(0, [0x21, 0x34, 0x12]); // LD HL, 0x1234
    cpu.step();
    expect(cpu.regs.hl, 0x1234);
  });

  test('LD BC, nn', () {
    bus.loadAt(0, [0x01, 0xCD, 0xAB]); // LD BC, 0xABCD
    cpu.step();
    expect(cpu.regs.bc, 0xABCD);
  });

  test('LD SP, nn', () {
    bus.loadAt(0, [0x31, 0xFF, 0xDF]); // LD SP, 0xDFFF
    cpu.step();
    expect(cpu.regs.sp, 0xDFFF);
  });

  test('INC A', () {
    bus.loadAt(0, [0x3E, 0x0F, 0x3C]); // LD A, 0x0F; INC A
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0x10);
    expect(cpu.regs.flagH, true);
    expect(cpu.regs.flagZ, false);
  });

  test('INC A overflow wraps to 0', () {
    bus.loadAt(0, [0x3E, 0xFF, 0x3C]); // LD A, 0xFF; INC A
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0x00);
    expect(cpu.regs.flagZ, true);
  });

  test('DEC A', () {
    bus.loadAt(0, [0x3E, 0x01, 0x3D]); // LD A, 0x01; DEC A
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0x00);
    expect(cpu.regs.flagZ, true);
    expect(cpu.regs.flagN, true);
  });

  test('ADD A, B', () {
    bus.loadAt(0, [0x3E, 0x10, 0x06, 0x20, 0x80]);
    // LD A, 0x10; LD B, 0x20; ADD A, B
    cpu.step();
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0x30);
    expect(cpu.regs.flagC, false);
  });

  test('ADD A, B with carry', () {
    bus.loadAt(0, [0x3E, 0xFF, 0x06, 0x01, 0x80]);
    // LD A, 0xFF; LD B, 0x01; ADD A, B
    cpu.step();
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0x00);
    expect(cpu.regs.flagC, true);
    expect(cpu.regs.flagZ, true);
  });

  test('SUB B', () {
    bus.loadAt(0, [0x3E, 0x30, 0x06, 0x10, 0x90]);
    // LD A, 0x30; LD B, 0x10; SUB B
    cpu.step();
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0x20);
    expect(cpu.regs.flagN, true);
    expect(cpu.regs.flagC, false);
  });

  test('AND B', () {
    bus.loadAt(0, [0x3E, 0xFF, 0x06, 0x0F, 0xA0]);
    // LD A, 0xFF; LD B, 0x0F; AND B
    cpu.step();
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0x0F);
    expect(cpu.regs.flagH, true);
  });

  test('OR B', () {
    bus.loadAt(0, [0x3E, 0xF0, 0x06, 0x0F, 0xB0]);
    // LD A, 0xF0; LD B, 0x0F; OR B
    cpu.step();
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0xFF);
  });

  test('XOR A (clear A)', () {
    bus.loadAt(0, [0x3E, 0xFF, 0xAF]); // LD A, 0xFF; XOR A
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0x00);
    expect(cpu.regs.flagZ, true);
  });

  test('CP B (compare without modifying A)', () {
    bus.loadAt(0, [0x3E, 0x42, 0x06, 0x42, 0xB8]);
    // LD A, 0x42; LD B, 0x42; CP B
    cpu.step();
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0x42); // A unchanged
    expect(cpu.regs.flagZ, true);
  });

  test('JP nn (unconditional jump)', () {
    bus.loadAt(0, [0xC3, 0x00, 0x10]); // JP 0x1000
    cpu.step();
    expect(cpu.regs.pc, 0x1000);
  });

  test('JP Z, nn (conditional jump — taken)', () {
    bus.loadAt(0, [0x3E, 0xFF, 0xAF, 0xCA, 0x00, 0x20]);
    // LD A, 0xFF; XOR A; JP Z, 0x2000
    cpu.step();
    cpu.step();
    cpu.step();
    expect(cpu.regs.pc, 0x2000);
  });

  test('JP Z, nn (conditional jump — not taken)', () {
    bus.loadAt(0, [0x3E, 0x01, 0xCA, 0x00, 0x20]);
    // LD A, 0x01; JP Z, 0x2000
    cpu.step();
    cpu.step();
    expect(cpu.regs.pc, 5); // Not taken, continue
  });

  test('JR e (relative jump)', () {
    bus.loadAt(0, [0x18, 0x05]); // JR +5
    cpu.step();
    expect(cpu.regs.pc, 7); // 0 + 2 + 5
  });

  test('JR e (negative offset)', () {
    bus.loadAt(0x10, [0x18, 0xFE]); // JR -2 (infinite loop)
    cpu.regs.pc = 0x10;
    cpu.step();
    expect(cpu.regs.pc, 0x10);
  });

  test('CALL nn and RET', () {
    bus.loadAt(0, [0x31, 0x00, 0xE0, 0xCD, 0x00, 0x10]);
    // LD SP, 0xE000; CALL 0x1000
    bus.loadAt(0x1000, [0xC9]); // RET
    cpu.step(); // LD SP
    cpu.step(); // CALL
    expect(cpu.regs.pc, 0x1000);
    expect(cpu.regs.sp, 0xDFFE);
    cpu.step(); // RET
    expect(cpu.regs.pc, 0x0006);
    expect(cpu.regs.sp, 0xE000);
  });

  test('PUSH BC and POP DE', () {
    bus.loadAt(0, [0x31, 0x00, 0xE0, 0x01, 0x34, 0x12, 0xC5, 0xD1]);
    // LD SP, 0xE000; LD BC, 0x1234; PUSH BC; POP DE
    cpu.step(); // LD SP
    cpu.step(); // LD BC
    cpu.step(); // PUSH BC
    expect(cpu.regs.sp, 0xDFFE);
    cpu.step(); // POP DE
    expect(cpu.regs.de, 0x1234);
    expect(cpu.regs.sp, 0xE000);
  });

  test('DI and EI', () {
    bus.loadAt(0, [0xF3, 0xFB]); // DI; EI
    cpu.step(); // DI
    expect(cpu.regs.iff1, false);
    expect(cpu.regs.iff2, false);
    cpu.step(); // EI
    expect(cpu.regs.iff1, true);
    expect(cpu.regs.iff2, true);
  });

  test('OUT (n), A and IN A, (n)', () {
    bus.loadAt(0, [0x3E, 0xAA, 0xD3, 0x7E, 0xDB, 0x7E]);
    // LD A, 0xAA; OUT (0x7E), A; IN A, (0x7E)
    cpu.step(); // LD A
    cpu.step(); // OUT
    expect(bus.ioPorts[0x7E], 0xAA);
    cpu.regs.a = 0;
    cpu.step(); // IN
    expect(cpu.regs.a, 0xAA);
  });

  test('DJNZ — loop 3 times', () {
    bus.loadAt(0, [0x06, 0x03, 0x3C, 0x10, 0xFD]);
    // LD B, 3; INC A; DJNZ -3
    cpu.step(); // LD B, 3
    cpu.step(); // INC A (A=1)
    cpu.step(); // DJNZ (B=2, jump back)
    cpu.step(); // INC A (A=2)
    cpu.step(); // DJNZ (B=1, jump back)
    cpu.step(); // INC A (A=3)
    cpu.step(); // DJNZ (B=0, fall through)
    expect(cpu.regs.a, 3);
    expect(cpu.regs.b, 0);
  });

  test('EX DE, HL', () {
    bus.loadAt(0, [0x21, 0x34, 0x12, 0x11, 0x78, 0x56, 0xEB]);
    // LD HL, 0x1234; LD DE, 0x5678; EX DE, HL
    cpu.step();
    cpu.step();
    cpu.step();
    expect(cpu.regs.hl, 0x5678);
    expect(cpu.regs.de, 0x1234);
  });

  test('RLCA (rotate left circular)', () {
    bus.loadAt(0, [0x3E, 0x85, 0x07]); // LD A, 0x85; RLCA
    cpu.step();
    cpu.step();
    // 0x85 = 10000101 -> rotate left -> 00001011 = 0x0B, carry=1
    expect(cpu.regs.a, 0x0B);
    expect(cpu.regs.flagC, true);
  });

  test('RRCA (rotate right circular)', () {
    bus.loadAt(0, [0x3E, 0x85, 0x0F]); // LD A, 0x85; RRCA
    cpu.step();
    cpu.step();
    // 0x85 = 10000101 -> rotate right -> 11000010 = 0xC2, carry=1
    expect(cpu.regs.a, 0xC2);
    expect(cpu.regs.flagC, true);
  });

  test('INC HL (16-bit increment)', () {
    bus.loadAt(0, [0x21, 0xFF, 0xFF, 0x23]); // LD HL, 0xFFFF; INC HL
    cpu.step();
    cpu.step();
    expect(cpu.regs.hl, 0x0000);
  });

  test('DEC BC (16-bit decrement)', () {
    bus.loadAt(0, [0x01, 0x00, 0x00, 0x0B]); // LD BC, 0x0000; DEC BC
    cpu.step();
    cpu.step();
    expect(cpu.regs.bc, 0xFFFF);
  });

  test('LD A, (HL)', () {
    bus.loadAt(0, [0x21, 0x00, 0x80, 0x7E]); // LD HL, 0x8000; LD A, (HL)
    bus.write(0x8000, 0xBB);
    cpu.step();
    cpu.step();
    expect(cpu.regs.a, 0xBB);
  });

  test('LD (HL), A', () {
    bus.loadAt(0, [0x3E, 0xCC, 0x21, 0x00, 0x80, 0x77]);
    // LD A, 0xCC; LD HL, 0x8000; LD (HL), A
    cpu.step();
    cpu.step();
    cpu.step();
    expect(bus.read(0x8000), 0xCC);
  });

  test('RST 38h', () {
    bus.loadAt(0, [0x31, 0x00, 0xE0, 0xFF]); // LD SP, 0xE000; RST 38h
    cpu.step(); // LD SP
    cpu.step(); // RST
    expect(cpu.regs.pc, 0x0038);
  });

  test('HALT sets halted flag', () {
    bus.loadAt(0, [0x76]); // HALT
    cpu.step();
    expect(cpu.regs.halted, true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/emulator/z80_cpu_test.dart`
Expected: FAIL — `Z80CPU` not found.

- [ ] **Step 3: Implement Z80CPU core with basic opcodes**

Create `lib/emulator/z80_cpu.dart`. This is a large file implementing the Z80 instruction set. The implementation must include:

- Constructor taking a `Bus` instance
- `Z80Registers regs` public field
- `int step()` method that fetches, decodes, executes one instruction and returns cycle count
- Main opcode table (0x00-0xFF) in a switch statement
- Helper methods for: flag calculation (`_incFlags`, `_decFlags`, `_addFlags`, `_subFlags`, `_logicFlags`), stack operations (`_push16`, `_pop16`), memory read/write wrappers
- All load instructions (LD r,r / LD r,n / LD r,(HL) / LD (HL),r / LD rr,nn / LD (nn),A / LD A,(nn))
- 8-bit arithmetic: ADD, ADC, SUB, SBC, AND, OR, XOR, CP, INC, DEC
- 16-bit arithmetic: ADD HL,rr, INC rr, DEC rr
- Rotates: RLCA, RRCA, RLA, RRA
- Jumps: JP, JP cc, JR, JR cc, DJNZ
- Calls/Returns: CALL, CALL cc, RET, RET cc, RST
- Stack: PUSH, POP
- Exchange: EX DE,HL, EX AF,AF', EXX, EX (SP),HL
- I/O: IN A,(n), OUT (n),A
- Misc: NOP, HALT, DI, EI, SCF, CCF, CPL, NEG (via ED), DAA
- CB-prefixed bit operations: RLC, RRC, RL, RR, SLA, SRA, SRL, BIT, SET, RES
- ED-prefixed: IM 0/1/2, LD I,A, LD R,A, LD A,I, LD A,R, NEG, RETI, RETN, block ops (LDI, LDIR, LDD, LDDR, CPI, CPIR, CPD, CPDR, INI, INIR, OUTI, OTIR)
- DD/FD-prefixed: IX/IY variants of HL instructions (LD, ADD, INC, DEC with displacement)
- DDCB/FDCB: IX/IY bit operations with displacement
- NMI and INT handling methods: `void nmi()`, `void interrupt()`

Due to the size of this file (~2000-3000 lines), implement in logical groups:
1. Core fetch/decode loop and helpers
2. 8-bit load group
3. 16-bit load group
4. 8-bit arithmetic group
5. 16-bit arithmetic group
6. Rotate/shift group
7. Jump/call/return group
8. Stack/exchange group
9. I/O group
10. CB prefix handler
11. ED prefix handler
12. DD/FD prefix handler
13. Interrupt handling

Each opcode must return the correct cycle count per Z80 documentation.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/emulator/z80_cpu_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emulator/z80_cpu.dart test/emulator/z80_cpu_test.dart
git commit -m "feat: implement Z80 CPU core with full instruction set"
```

---

### Task 4: Z80 CB/ED/DD/FD prefix tests

**Files:**
- Create: `test/emulator/z80_prefix_test.dart`

- [ ] **Step 1: Write tests for prefix instructions**

Create `test/emulator/z80_prefix_test.dart`:

```dart
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
    for (int i = 0; i < data.length; i++) memory[(address + i) & 0xFFFF] = data[i] & 0xFF;
  }
}

void main() {
  late Z80CPU cpu;
  late TestBus bus;

  setUp(() {
    bus = TestBus();
    cpu = Z80CPU(bus);
  });

  group('CB prefix', () {
    test('BIT 7, A — zero', () {
      bus.loadAt(0, [0x3E, 0x00, 0xCB, 0x7F]); // LD A,0; BIT 7,A
      cpu.step(); cpu.step();
      expect(cpu.regs.flagZ, true);
    });

    test('BIT 7, A — set', () {
      bus.loadAt(0, [0x3E, 0x80, 0xCB, 0x7F]); // LD A,0x80; BIT 7,A
      cpu.step(); cpu.step();
      expect(cpu.regs.flagZ, false);
    });

    test('SET 0, A', () {
      bus.loadAt(0, [0x3E, 0x00, 0xCB, 0xC7]); // LD A,0; SET 0,A
      cpu.step(); cpu.step();
      expect(cpu.regs.a, 0x01);
    });

    test('RES 7, A', () {
      bus.loadAt(0, [0x3E, 0xFF, 0xCB, 0xBF]); // LD A,0xFF; RES 7,A
      cpu.step(); cpu.step();
      expect(cpu.regs.a, 0x7F);
    });

    test('SLA A', () {
      bus.loadAt(0, [0x3E, 0x85, 0xCB, 0x27]); // LD A,0x85; SLA A
      cpu.step(); cpu.step();
      expect(cpu.regs.a, 0x0A);
      expect(cpu.regs.flagC, true);
    });

    test('SRL A', () {
      bus.loadAt(0, [0x3E, 0x85, 0xCB, 0x3F]); // LD A,0x85; SRL A
      cpu.step(); cpu.step();
      expect(cpu.regs.a, 0x42);
      expect(cpu.regs.flagC, true);
    });

    test('RL A (through carry)', () {
      bus.loadAt(0, [0x3E, 0x80, 0xCB, 0x17]); // LD A,0x80; RL A
      cpu.step(); cpu.step();
      expect(cpu.regs.a, 0x00); // carry was 0, bit7->carry
      expect(cpu.regs.flagC, true);
    });
  });

  group('ED prefix', () {
    test('IM 1', () {
      bus.loadAt(0, [0xED, 0x56]); // IM 1
      cpu.step();
      expect(cpu.regs.im, 1);
    });

    test('LD I, A', () {
      bus.loadAt(0, [0x3E, 0x42, 0xED, 0x47]); // LD A,0x42; LD I,A
      cpu.step(); cpu.step();
      expect(cpu.regs.i, 0x42);
    });

    test('LDIR', () {
      // Copy 3 bytes from 0x1000 to 0x2000
      bus.loadAt(0x1000, [0xAA, 0xBB, 0xCC]);
      bus.loadAt(0, [
        0x21, 0x00, 0x10, // LD HL, 0x1000
        0x11, 0x00, 0x20, // LD DE, 0x2000
        0x01, 0x03, 0x00, // LD BC, 3
        0xED, 0xB0,       // LDIR
      ]);
      for (int i = 0; i < 4; i++) cpu.step(); // LD HL, LD DE, LD BC, LDIR
      expect(bus.read(0x2000), 0xAA);
      expect(bus.read(0x2001), 0xBB);
      expect(bus.read(0x2002), 0xCC);
      expect(cpu.regs.bc, 0);
    });

    test('CPIR — find byte', () {
      bus.loadAt(0x1000, [0x11, 0x22, 0x33]);
      bus.loadAt(0, [
        0x3E, 0x22,       // LD A, 0x22
        0x21, 0x00, 0x10, // LD HL, 0x1000
        0x01, 0x03, 0x00, // LD BC, 3
        0xED, 0xB1,       // CPIR
      ]);
      cpu.step(); cpu.step(); cpu.step(); cpu.step();
      expect(cpu.regs.flagZ, true);
      expect(cpu.regs.hl, 0x1002);
    });

    test('NEG', () {
      bus.loadAt(0, [0x3E, 0x01, 0xED, 0x44]); // LD A,1; NEG
      cpu.step(); cpu.step();
      expect(cpu.regs.a, 0xFF);
      expect(cpu.regs.flagC, true);
    });
  });

  group('DD prefix (IX)', () {
    test('LD IX, nn', () {
      bus.loadAt(0, [0xDD, 0x21, 0x34, 0x12]); // LD IX, 0x1234
      cpu.step();
      expect(cpu.regs.ix, 0x1234);
    });

    test('LD A, (IX+d)', () {
      bus.write(0x1005, 0xAA);
      bus.loadAt(0, [0xDD, 0x21, 0x00, 0x10, 0xDD, 0x7E, 0x05]);
      // LD IX, 0x1000; LD A, (IX+5)
      cpu.step(); cpu.step();
      expect(cpu.regs.a, 0xAA);
    });

    test('LD (IX+d), n', () {
      bus.loadAt(0, [0xDD, 0x21, 0x00, 0x10, 0xDD, 0x36, 0x03, 0xBB]);
      // LD IX, 0x1000; LD (IX+3), 0xBB
      cpu.step(); cpu.step();
      expect(bus.read(0x1003), 0xBB);
    });
  });

  group('FD prefix (IY)', () {
    test('LD IY, nn', () {
      bus.loadAt(0, [0xFD, 0x21, 0x78, 0x56]); // LD IY, 0x5678
      cpu.step();
      expect(cpu.regs.iy, 0x5678);
    });

    test('LD B, (IY+d)', () {
      bus.write(0x5680, 0xCC);
      bus.loadAt(0, [0xFD, 0x21, 0x78, 0x56, 0xFD, 0x46, 0x08]);
      // LD IY, 0x5678; LD B, (IY+8)
      cpu.step(); cpu.step();
      expect(cpu.regs.b, 0xCC);
    });
  });

  group('Interrupts', () {
    test('NMI jumps to 0x0066', () {
      bus.loadAt(0, [0x31, 0x00, 0xE0]); // LD SP, 0xE000
      cpu.step();
      cpu.regs.pc = 0x1234;
      cpu.nmi();
      expect(cpu.regs.pc, 0x0066);
      expect(cpu.regs.iff1, false);
    });

    test('INT in IM1 jumps to 0x0038', () {
      bus.loadAt(0, [0x31, 0x00, 0xE0, 0xFB, 0xED, 0x56]);
      // LD SP, 0xE000; EI; IM 1
      cpu.step(); cpu.step(); cpu.step();
      cpu.regs.pc = 0x1234;
      cpu.interrupt();
      expect(cpu.regs.pc, 0x0038);
      expect(cpu.regs.iff1, false);
    });

    test('INT ignored when interrupts disabled', () {
      bus.loadAt(0, [0x31, 0x00, 0xE0, 0xF3]); // LD SP, 0xE000; DI
      cpu.step(); cpu.step();
      cpu.regs.pc = 0x1234;
      cpu.interrupt();
      expect(cpu.regs.pc, 0x1234); // Unchanged
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they pass** (should pass if Task 3 implementation is correct)

Run: `flutter test test/emulator/z80_prefix_test.dart`
Expected: All tests PASS.

- [ ] **Step 3: Fix any failing prefix tests**

If any tests fail, fix the corresponding prefix handler in `z80_cpu.dart`.

- [ ] **Step 4: Commit**

```bash
git add test/emulator/z80_prefix_test.dart
git commit -m "test: add Z80 CB/ED/DD/FD prefix and interrupt tests"
```

---

## Phase 2: Memory Bus & VDP

### Task 5: ROM Header Parsing

**Files:**
- Create: `lib/emulator/rom_header.dart`
- Create: `test/emulator/rom_header_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/emulator/rom_header_test.dart`:

```dart
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
    // Codemasters ROMs have 0x0000 as bank register
    // and specific checksum patterns — detect by ROM size + no TMR SEGA header
    final rom = Uint8List(256 * 1024);
    // No TMR SEGA header, but >48KB = likely Codemasters
    // For accurate detection, check for writes to $0000 in code
    // Simplified: detect based on header absence + size
    final header = RomHeader.parse(rom);
    expect(header.mapperType, MapperType.codemasters);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/emulator/rom_header_test.dart`
Expected: FAIL — `RomHeader` not found.

- [ ] **Step 3: Implement RomHeader**

Create `lib/emulator/rom_header.dart`:

```dart
import 'dart:typed_data';

enum MapperType { none, sega, codemasters }

class RomHeader {
  final MapperType mapperType;
  final bool hasCopierHeader;
  final int romSizeBytes;

  RomHeader({
    required this.mapperType,
    required this.hasCopierHeader,
    required this.romSizeBytes,
  });

  static RomHeader parse(Uint8List data) {
    bool copierHeader = (data.length % 1024) == 512;
    int offset = copierHeader ? 512 : 0;
    int romSize = data.length - offset;

    // Check for TMR SEGA magic at standard offsets
    bool hasMagic = _checkMagic(data, offset + 0x7FF0) ||
                    _checkMagic(data, offset + 0x3FF0) ||
                    _checkMagic(data, offset + 0x1FF0);

    MapperType mapper;
    if (romSize <= 48 * 1024) {
      mapper = MapperType.none;
    } else if (hasMagic) {
      mapper = MapperType.sega;
    } else {
      // No TMR SEGA header + large ROM = likely Codemasters
      mapper = MapperType.codemasters;
    }

    return RomHeader(
      mapperType: mapper,
      hasCopierHeader: copierHeader,
      romSizeBytes: romSize,
    );
  }

  static bool _checkMagic(Uint8List data, int offset) {
    if (offset + 8 > data.length) return false;
    const magic = [0x54, 0x4D, 0x52, 0x20, 0x53, 0x45, 0x47, 0x41]; // TMR SEGA
    for (int i = 0; i < 8; i++) {
      if (data[offset + i] != magic[i]) return false;
    }
    return true;
  }

  /// Strip copier header if present and return clean ROM data
  Uint8List cleanRom(Uint8List data) {
    if (hasCopierHeader) {
      return Uint8List.sublistView(data, 512);
    }
    return data;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/emulator/rom_header_test.dart`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emulator/rom_header.dart test/emulator/rom_header_test.dart
git commit -m "feat: add ROM header parsing and mapper detection"
```

---

### Task 6: Memory Bus with Sega Mapper

**Files:**
- Create: `lib/emulator/memory_bus.dart`
- Create: `test/emulator/memory_bus_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/emulator/memory_bus_test.dart`:

```dart
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
    // $0000-$3FFF = page 0
    expect(memBus.read(0x0000), 0);
    // $4000-$7FFF = page 1
    expect(memBus.read(0x4000), 1);
    // $8000-$BFFF = page 2
    expect(memBus.read(0x8000), 2);
  });

  test('RAM read/write at $C000-$DFFF', () {
    memBus.write(0xC000, 0xAA);
    expect(memBus.read(0xC000), 0xAA);
  });

  test('RAM mirror at $E000-$FFFF', () {
    memBus.write(0xC000, 0xBB);
    expect(memBus.read(0xE000), 0xBB);
    memBus.write(0xE100, 0xCC);
    expect(memBus.read(0xC100), 0xCC);
  });

  test('bank switching via $FFFF changes slot 2', () {
    memBus.write(0xFFFF, 5); // Map page 5 to slot 2
    expect(memBus.read(0x8000), 5);
  });

  test('bank switching via $FFFE changes slot 1', () {
    memBus.write(0xFFFE, 3); // Map page 3 to slot 1
    expect(memBus.read(0x4000), 3);
  });

  test('bank switching via $FFFD changes slot 0', () {
    memBus.write(0xFFFD, 4); // Map page 4 to slot 0
    // $0400-$3FFF should be page 4 (first 0x400 bytes always page 0)
    expect(memBus.read(0x0400), 4);
    // $0000-$03FF is always ROM first page
    expect(memBus.read(0x0000), 0);
  });

  test('$0000-$03FF always maps to ROM start regardless of slot 0 bank', () {
    memBus.write(0xFFFD, 7);
    expect(memBus.read(0x0000), 0); // Always page 0
    expect(memBus.read(0x03FF), 0);
    expect(memBus.read(0x0400), 7); // Switched
  });

  test('writes to ROM space are silently ignored', () {
    int original = memBus.read(0x0000);
    memBus.write(0x0000, 0xFF);
    expect(memBus.read(0x0000), original);
  });

  test('cartridge RAM enable via $FFFC', () {
    memBus.write(0xFFFC, 0x08); // Enable cart RAM in slot 2
    memBus.write(0x8000, 0xDD);
    expect(memBus.read(0x8000), 0xDD);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/emulator/memory_bus_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement MemoryBus**

Create `lib/emulator/memory_bus.dart`:

```dart
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
      if (address == 0x0000) { _cmSlot0 = value % _pageCount; return; }
      if (address == 0x4000) { _cmSlot1 = value % _pageCount; return; }
      if (address == 0x8000) { _cmSlot2 = value % _pageCount; return; }
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
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/emulator/memory_bus_test.dart`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emulator/memory_bus.dart test/emulator/memory_bus_test.dart
git commit -m "feat: implement MemoryBus with Sega and Codemasters mapper support"
```

---

### Task 7: VDP (Video Display Processor)

**Files:**
- Create: `lib/emulator/vdp.dart`
- Create: `test/emulator/vdp_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/emulator/vdp_test.dart`:

```dart
import 'dart:typed_data';
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
      // First byte: low address, second byte: high | command
      vdp.writeControl(0x00); // address low = 0x00
      vdp.writeControl(0x40); // address high = 0x00, command = 01 (VRAM write)
      vdp.writeData(0xAA);
      // Read back: set read address first
      vdp.writeControl(0x00);
      vdp.writeControl(0x00); // command = 00 (VRAM read)
      vdp.readData(); // first read returns buffer (discard)
      expect(vdp.readData(), 0xAA);
    });

    test('VDP register write', () {
      // Write 0xFF to register 0
      vdp.writeControl(0xFF); // data
      vdp.writeControl(0x80); // 10000000 = register 0
      expect(vdp.registers[0], 0xFF);
    });

    test('address latch resets on status read', () {
      vdp.writeControl(0x34); // first byte of address
      vdp.readStatus();       // should reset latch
      vdp.writeControl(0x00); // this should be treated as first byte again
      vdp.writeControl(0x40); // VRAM write command
      // If latch wasn't reset, this would be interpreted wrong
    });
  });

  group('CRAM writes', () {
    test('write to CRAM', () {
      vdp.writeControl(0x00); // address 0
      vdp.writeControl(0xC0); // command = 11 (CRAM write)
      vdp.writeData(0x3F);   // 6-bit color value
      expect(vdp.cram[0], 0x3F);
    });
  });

  group('status register', () {
    test('reading status clears flags and latch', () {
      vdp.setVBlankFlag();
      int status = vdp.readStatus();
      expect(status & 0x80, 0x80); // VBlank flag was set
      status = vdp.readStatus();
      expect(status & 0x80, 0x00); // Cleared after read
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
      // Write 0xAA to VRAM address 0
      vdp.writeControl(0x00);
      vdp.writeControl(0x40);
      vdp.writeData(0xAA);

      // Write 0xBB to VRAM address 1
      vdp.writeData(0xBB);

      // Set read address to 0
      vdp.writeControl(0x00);
      vdp.writeControl(0x00);

      // First read returns buffer (pre-fetch of addr 0)
      int first = vdp.readData();
      // Second read returns what was at addr 0 (0xAA), buffer now has addr 1
      int second = vdp.readData();
      expect(second, 0xAA);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/emulator/vdp_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement VDP**

Create `lib/emulator/vdp.dart`. Must implement:

- `Uint8List vram` (16KB), `Uint8List cram` (32 bytes), `List<int> registers` (16 registers)
- Internal state: `_addressRegister` (14-bit), `_writePending` (latch toggle), `_readBuffer`, `_statusRegister`
- `void writeControl(int value)` — handles address/register/command setup with latch
- `void writeData(int value)` — writes to VRAM or CRAM based on command
- `int readData()` — reads from VRAM with buffering
- `int readStatus()` — returns and clears status register, resets latch
- `int get vCounter`, `int get hCounter`
- `void renderScanline()` — renders one scanline:
  - For active lines (0-191): render background tiles + sprites to frame buffer
  - At line 192: set VBlank flag
  - Increment V counter, wrap at 262
  - Process line interrupt counter
- `Uint32List frameBuffer` (256x192) — ARGB pixel data
- `bool get interruptPending` — true if interrupt should fire
- Background tile rendering (Mode 4): decode name table, fetch tile patterns from VRAM, apply palette from CRAM, handle horizontal/vertical scroll
- Sprite rendering: scan SAT for sprites on current line, draw up to 8, set overflow flag
- Color conversion: 6-bit CRAM entry (--BBGGRR) to 32-bit ARGB
- `void setVBlankFlag()` helper

- [ ] **Step 4: Run tests**

Run: `flutter test test/emulator/vdp_test.dart`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emulator/vdp.dart test/emulator/vdp_test.dart
git commit -m "feat: implement VDP with Mode 4 rendering, VRAM/CRAM, and status register"
```

---

## Phase 3: PSG, I/O, and System Integration

### Task 8: PSG (Sound)

**Files:**
- Create: `lib/emulator/psg.dart`
- Create: `test/emulator/psg_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/emulator/psg_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/psg.dart';

void main() {
  late Psg psg;

  setUp(() {
    psg = Psg();
  });

  test('initial state — all channels silent', () {
    expect(psg.volumes[0], 0x0F); // 0x0F = muted
    expect(psg.volumes[1], 0x0F);
    expect(psg.volumes[2], 0x0F);
    expect(psg.volumes[3], 0x0F);
  });

  test('latch write sets channel and type', () {
    // Latch: 1 CC T DDDD
    // Channel 0, tone, data=0x0A
    psg.write(0x8A); // 1 00 0 1010 = chan0 tone low=0x0A
    expect(psg.toneRegisters[0] & 0x0F, 0x0A);
  });

  test('data write updates high bits of tone', () {
    psg.write(0x8A); // chan0 tone low=0x0A
    psg.write(0x01); // 0 0000001 = high bits = 0x01
    // Full tone = (0x01 << 4) | 0x0A = 0x1A
    expect(psg.toneRegisters[0], 0x1A);
  });

  test('volume write', () {
    // Channel 1, volume, data=0x05
    psg.write(0xB5); // 1 01 1 0101
    expect(psg.volumes[1], 0x05);
  });

  test('noise register write', () {
    // Channel 3 (noise), tone type
    psg.write(0xE4); // 1 11 0 0100 = white noise, clock/512
    expect(psg.noiseMode, 1); // white noise
    expect(psg.noiseShiftRate, 0); // rate bits
  });

  test('generate samples produces non-empty output', () {
    // Set channel 0 to audible tone
    psg.write(0x80); // chan0 tone low=0
    psg.write(0x01); // tone = 0x10
    psg.write(0x90); // chan0 volume = 0 (max)
    final samples = psg.generateSamples(44100 ~/ 60); // ~735 samples per frame
    expect(samples.length, 44100 ~/ 60);
    // At max volume with a tone, should not be all zeros
    expect(samples.any((s) => s != 0), true);
  });

  test('LFSR for white noise uses Sega taps (bit 0 XOR bit 3)', () {
    // Initial LFSR = 0x8000
    psg.write(0xE7); // white noise, use channel 3 freq
    psg.write(0xF0); // chan3 volume = 0 (max)
    // Just verify it produces output
    final samples = psg.generateSamples(100);
    expect(samples.any((s) => s != 0), true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/emulator/psg_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement PSG**

Create `lib/emulator/psg.dart`:

```dart
import 'dart:typed_data';

class Psg {
  // Tone registers (10-bit) for channels 0-2
  final List<int> toneRegisters = [0, 0, 0];
  // Volume registers (4-bit, 0=max, 15=mute)
  final List<int> volumes = [0x0F, 0x0F, 0x0F, 0x0F];
  // Noise register
  int _noiseRegister = 0;
  // LFSR for noise
  int _lfsr = 0x8000;

  // Internal counters
  final List<int> _toneCounters = [0, 0, 0];
  int _noiseCounter = 0;
  // Tone output flip-flops (+1 or -1)
  final List<int> _toneOutput = [1, 1, 1];
  int _noiseOutput = 1;

  // Latch state
  int _latchedChannel = 0;
  bool _latchedVolume = false;

  // Clock rate and sample rate
  static const int _clockRate = 3546895;
  static const int _clockDivider = 16; // PSG divides CPU clock by 16
  static const int _sampleRate = 44100;

  int get noiseMode => (_noiseRegister >> 2) & 1;
  int get noiseShiftRate => _noiseRegister & 3;

  // Volume table: 4-bit to linear amplitude
  static final Float64List _volumeTable = Float64List.fromList([
    1.0, 0.7943, 0.6310, 0.5012, 0.3981, 0.3162, 0.2512, 0.1995,
    0.1585, 0.1259, 0.1000, 0.0794, 0.0631, 0.0501, 0.0398, 0.0,
  ]);

  void write(int value) {
    value &= 0xFF;
    if (value & 0x80 != 0) {
      // Latch/data byte
      _latchedChannel = (value >> 5) & 3;
      _latchedVolume = (value & 0x10) != 0;
      int data = value & 0x0F;

      if (_latchedVolume) {
        volumes[_latchedChannel] = data;
      } else if (_latchedChannel < 3) {
        toneRegisters[_latchedChannel] =
            (toneRegisters[_latchedChannel] & 0x3F0) | data;
      } else {
        _noiseRegister = data;
        _lfsr = 0x8000;
      }
    } else {
      // Data byte (updates previously latched register)
      int data = value & 0x3F;
      if (_latchedVolume) {
        volumes[_latchedChannel] = data & 0x0F;
      } else if (_latchedChannel < 3) {
        toneRegisters[_latchedChannel] =
            (toneRegisters[_latchedChannel] & 0x0F) | (data << 4);
      } else {
        _noiseRegister = data & 0x07;
        _lfsr = 0x8000;
      }
    }
  }

  Float64List generateSamples(int count) {
    final output = Float64List(count);
    final cyclesPerSample = (_clockRate / _clockDivider) / _sampleRate;

    for (int i = 0; i < count; i++) {
      double sample = 0;

      // Update tone channels
      for (int ch = 0; ch < 3; ch++) {
        _toneCounters[ch] -= cyclesPerSample.toInt();
        if (_toneCounters[ch] <= 0) {
          if (toneRegisters[ch] == 0 || toneRegisters[ch] == 1) {
            _toneOutput[ch] = 1;
          } else {
            _toneOutput[ch] = -_toneOutput[ch];
          }
          _toneCounters[ch] += toneRegisters[ch];
        }
        sample += _toneOutput[ch] * _volumeTable[volumes[ch]];
      }

      // Update noise channel
      int noiseRate;
      switch (noiseShiftRate) {
        case 0: noiseRate = 0x10; break;
        case 1: noiseRate = 0x20; break;
        case 2: noiseRate = 0x40; break;
        case 3: noiseRate = toneRegisters[2]; break;
        default: noiseRate = 0x10;
      }
      _noiseCounter -= cyclesPerSample.toInt();
      if (_noiseCounter <= 0) {
        _noiseCounter += (noiseRate == 0) ? 1 : noiseRate;
        // Shift LFSR
        int feedback;
        if (noiseMode == 1) {
          // White noise: bit0 XOR bit3
          feedback = (_lfsr & 1) ^ ((_lfsr >> 3) & 1);
        } else {
          // Periodic: bit0
          feedback = _lfsr & 1;
        }
        _lfsr = (_lfsr >> 1) | (feedback << 15);
        _noiseOutput = (_lfsr & 1) != 0 ? 1 : -1;
      }
      sample += _noiseOutput * _volumeTable[volumes[3]];

      output[i] = sample / 4.0; // Mix 4 channels, normalize
    }
    return output;
  }

  void reset() {
    for (int i = 0; i < 3; i++) {
      toneRegisters[i] = 0;
      _toneCounters[i] = 0;
      _toneOutput[i] = 1;
    }
    volumes.fillRange(0, 4, 0x0F);
    _noiseRegister = 0;
    _noiseCounter = 0;
    _lfsr = 0x8000;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/emulator/psg_test.dart`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emulator/psg.dart test/emulator/psg_test.dart
git commit -m "feat: implement PSG (SN76489) with tone and noise channels"
```

---

### Task 9: I/O Ports

**Files:**
- Create: `lib/emulator/io_ports.dart`
- Create: `test/emulator/io_ports_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/emulator/io_ports_test.dart`:

```dart
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

  test('port $BF read returns VDP status', () {
    vdp.setVBlankFlag();
    int status = io.read(0xBF);
    expect(status & 0x80, 0x80);
  });

  test('port $BF write goes to VDP control', () {
    io.write(0xBF, 0xFF);
    io.write(0xBF, 0x80); // Register 0 = 0xFF
    expect(vdp.registers[0], 0xFF);
  });

  test('port $BE read returns VDP data', () {
    // Set up VRAM write
    io.write(0xBF, 0x00);
    io.write(0xBF, 0x40);
    io.write(0xBE, 0x42);
    // Set up VRAM read
    io.write(0xBF, 0x00);
    io.write(0xBF, 0x00);
    io.read(0xBE); // discard buffer
    expect(io.read(0xBE), 0x42);
  });

  test('port $7E write goes to PSG', () {
    io.write(0x7E, 0x9F); // Chan0 volume = 0xF (mute)
    expect(psg.volumes[0], 0x0F);
  });

  test('port $7E read returns V counter', () {
    int v = io.read(0x7E);
    expect(v, vdp.vCounter);
  });

  test('port $DC returns controller 1 state (all released)', () {
    expect(io.read(0xDC), 0xFF); // All buttons released = all bits high
  });

  test('port $DC reflects button presses', () {
    io.pressButton(Button.up);
    expect(io.read(0xDC) & 0x01, 0x00); // bit 0 = UP, pressed = low
    io.releaseButton(Button.up);
    expect(io.read(0xDC) & 0x01, 0x01);
  });

  test('port $3F returns export region', () {
    // Export mode: bits depend on nationalization write
    int val = io.read(0x3F);
    expect(val, isA<int>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/emulator/io_ports_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement IoPorts**

Create `lib/emulator/io_ports.dart`:

```dart
import 'package:sega3/emulator/vdp.dart';
import 'package:sega3/emulator/psg.dart';

enum Button { up, down, left, right, button1, button2, start }

class IoPorts {
  final Vdp vdp;
  final Psg psg;

  // Controller state: bit=1 means released, bit=0 means pressed
  int _controller1 = 0xFF;
  int _controller2 = 0xFF;
  int _nationalization = 0xFF; // Export mode

  IoPorts({required this.vdp, required this.psg});

  int read(int port) {
    port &= 0xFF;

    // Ports are partially decoded on SMS
    if (port <= 0x3F) {
      if (port & 1 == 0) return 0xFF; // $3E — not readable
      return _nationalization; // $3F
    }

    if (port >= 0x40 && port <= 0x7F) {
      if (port & 1 == 0) return vdp.vCounter; // $7E
      return vdp.hCounter; // $7F
    }

    if (port >= 0x80 && port <= 0xBF) {
      if (port & 1 == 0) return vdp.readData(); // $BE
      return vdp.readStatus(); // $BF
    }

    if (port >= 0xC0) {
      if (port & 1 == 0) return _controller1; // $DC
      return _controller2; // $DD
    }

    return 0xFF;
  }

  void write(int port, int value) {
    port &= 0xFF;
    value &= 0xFF;

    if (port <= 0x3F) {
      if (port & 1 == 0) {
        // $3E: Memory control — handled by MemoryBus, ignored here
      } else {
        _nationalization = value; // $3F
      }
      return;
    }

    if (port >= 0x40 && port <= 0x7F) {
      psg.write(value); // $7E/$7F both go to PSG
      return;
    }

    if (port >= 0x80 && port <= 0xBF) {
      if (port & 1 == 0) {
        vdp.writeData(value); // $BE
      } else {
        vdp.writeControl(value); // $BF
      }
      return;
    }

    // $C0+ writes are ignored
  }

  // Controller 1 button mapping in $DC:
  // bit 0: Up, bit 1: Down, bit 2: Left, bit 3: Right
  // bit 4: Button 1, bit 5: Button 2
  // Controller 2 bits 6-7 in $DC, rest in $DD

  void pressButton(Button button) {
    switch (button) {
      case Button.up:      _controller1 &= ~0x01; break;
      case Button.down:    _controller1 &= ~0x02; break;
      case Button.left:    _controller1 &= ~0x04; break;
      case Button.right:   _controller1 &= ~0x08; break;
      case Button.button1: _controller1 &= ~0x10; break;
      case Button.button2: _controller1 &= ~0x20; break;
      case Button.start:   break; // START = NMI, handled separately
    }
  }

  void releaseButton(Button button) {
    switch (button) {
      case Button.up:      _controller1 |= 0x01; break;
      case Button.down:    _controller1 |= 0x02; break;
      case Button.left:    _controller1 |= 0x04; break;
      case Button.right:   _controller1 |= 0x08; break;
      case Button.button1: _controller1 |= 0x10; break;
      case Button.button2: _controller1 |= 0x20; break;
      case Button.start:   break;
    }
  }

  void reset() {
    _controller1 = 0xFF;
    _controller2 = 0xFF;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/emulator/io_ports_test.dart`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emulator/io_ports.dart test/emulator/io_ports_test.dart
git commit -m "feat: implement I/O port routing with controller input"
```

---

### Task 10: System Emulator (Integration)

**Files:**
- Create: `lib/emulator/emulator.dart`
- Create: `test/emulator/emulator_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/emulator/emulator_test.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/emulator.dart';

void main() {
  test('Emulator initializes with ROM', () {
    // Minimal ROM: just a HALT instruction at $0000
    final rom = Uint8List(32 * 1024);
    rom[0] = 0x76; // HALT
    final emu = Emulator(rom);
    expect(emu.isRunning, false);
  });

  test('runFrame executes one frame of emulation', () {
    final rom = Uint8List(32 * 1024);
    // Simple program: LD SP, 0xDFF0; HALT
    rom[0] = 0x31; rom[1] = 0xF0; rom[2] = 0xDF;
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
    // No crash expected
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

    // Modify state
    emu.runFrame();

    // Restore
    emu.loadState(state);
    // After load, CPU A register should be 0x42 (from saved state)
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/emulator/emulator_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement Emulator**

Create `lib/emulator/emulator.dart`. This file integrates all components:

```dart
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

class Emulator extends ChangeNotifier {
  late final Z80CPU _cpu;
  late final Vdp _vdp;
  late final Psg _psg;
  late final MemoryBus _memoryBus;
  late final IoPorts _ioPorts;
  late final _SystemBus _systemBus;

  bool isRunning = false;

  static const int _cyclesPerScanline = 228;
  static const int _scanlinesPerFrame = 262;
  static const int _samplesPerFrame = 44100 ~/ 60; // ~735

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

  Uint32List get frameBuffer => _vdp.frameBuffer;

  void runFrame() {
    for (int scanline = 0; scanline < _scanlinesPerFrame; scanline++) {
      // Run CPU for one scanline worth of cycles
      int cyclesThisScanline = 0;
      while (cyclesThisScanline < _cyclesPerScanline) {
        cyclesThisScanline += _cpu.step();
      }

      // Render one scanline
      _vdp.renderScanline();

      // Check for VDP interrupt
      if (_vdp.interruptPending && _cpu.regs.iff1) {
        _cpu.interrupt();
      }
    }

    // Generate audio samples for this frame
    _psg.generateSamples(_samplesPerFrame);

    notifyListeners();
  }

  void pressButton(EmulatorButton button) {
    if (button == EmulatorButton.start) {
      _cpu.nmi();
      return;
    }
    _ioPorts.pressButton(_mapButton(button));
  }

  void releaseButton(EmulatorButton button) {
    if (button == EmulatorButton.start) return;
    _ioPorts.releaseButton(_mapButton(button));
  }

  Button _mapButton(EmulatorButton button) {
    switch (button) {
      case EmulatorButton.up: return Button.up;
      case EmulatorButton.down: return Button.down;
      case EmulatorButton.left: return Button.left;
      case EmulatorButton.right: return Button.right;
      case EmulatorButton.button1: return Button.button1;
      case EmulatorButton.button2: return Button.button2;
      case EmulatorButton.start: return Button.start;
    }
  }

  Uint8List saveState() {
    // Save state format: magic + version + component data
    final builder = BytesBuilder();
    builder.add([0x53, 0x4D, 0x53, 0x00]); // "SMS\0"
    builder.add([0x01, 0x00]); // version 1

    // Placeholder offsets (fill in after)
    // For simplicity, serialize sequentially
    // Z80 state
    final z80State = _serializeZ80();
    // VDP state
    final vdpState = _serializeVdp();
    // PSG state
    final psgState = _serializePsg();
    // Memory state
    final memState = _serializeMemory();

    // Write offsets
    int offset = 6 + 16; // header + 4 offsets
    _writeInt32(builder, offset); // Z80 offset
    offset += z80State.length;
    _writeInt32(builder, offset); // VDP offset
    offset += vdpState.length;
    _writeInt32(builder, offset); // PSG offset
    offset += psgState.length;
    _writeInt32(builder, offset); // Memory offset

    builder.add(z80State);
    builder.add(vdpState);
    builder.add(psgState);
    builder.add(memState);

    return builder.toBytes();
  }

  void loadState(Uint8List data) {
    // Verify magic
    if (data[0] != 0x53 || data[1] != 0x4D || data[2] != 0x53) return;
    // Read offsets and deserialize each component
    int z80Offset = _readInt32(data, 6);
    int vdpOffset = _readInt32(data, 10);
    int psgOffset = _readInt32(data, 14);
    int memOffset = _readInt32(data, 18);

    _deserializeZ80(data, z80Offset);
    _deserializeVdp(data, vdpOffset);
    _deserializePsg(data, psgOffset);
    _deserializeMemory(data, memOffset);
  }

  // Serialization helpers — implemented per component
  Uint8List _serializeZ80() {
    final b = BytesBuilder();
    final r = _cpu.regs;
    _writeInt16(b, r.af); _writeInt16(b, r.bc);
    _writeInt16(b, r.de); _writeInt16(b, r.hl);
    _writeInt16(b, r.ix); _writeInt16(b, r.iy);
    _writeInt16(b, r.sp); _writeInt16(b, r.pc);
    b.addByte(r.i); b.addByte(r.r);
    b.addByte(r.iff1 ? 1 : 0); b.addByte(r.iff2 ? 1 : 0);
    b.addByte(r.im); b.addByte(r.halted ? 1 : 0);
    // Shadow registers via exchange
    r.exAF(); _writeInt16(b, r.af); r.exAF();
    r.exx(); _writeInt16(b, r.bc); _writeInt16(b, r.de); _writeInt16(b, r.hl); r.exx();
    return b.toBytes();
  }

  Uint8List _serializeVdp() {
    final b = BytesBuilder();
    b.add(_vdp.vram);
    b.add(_vdp.cram);
    for (int i = 0; i < 16; i++) b.addByte(_vdp.registers[i]);
    return b.toBytes();
  }

  Uint8List _serializePsg() {
    final b = BytesBuilder();
    for (int i = 0; i < 3; i++) _writeInt16(b, _psg.toneRegisters[i]);
    for (int i = 0; i < 4; i++) b.addByte(_psg.volumes[i]);
    return b.toBytes();
  }

  Uint8List _serializeMemory() {
    final b = BytesBuilder();
    b.add(_memoryBus.ram);
    b.addByte(_memoryBus.slot0Bank);
    b.addByte(_memoryBus.slot1Bank);
    b.addByte(_memoryBus.slot2Bank);
    b.addByte(_memoryBus.ramControl);
    return b.toBytes();
  }

  void _deserializeZ80(Uint8List data, int offset) {
    final r = _cpu.regs;
    r.af = _readInt16(data, offset); offset += 2;
    r.bc = _readInt16(data, offset); offset += 2;
    r.de = _readInt16(data, offset); offset += 2;
    r.hl = _readInt16(data, offset); offset += 2;
    r.ix = _readInt16(data, offset); offset += 2;
    r.iy = _readInt16(data, offset); offset += 2;
    r.sp = _readInt16(data, offset); offset += 2;
    r.pc = _readInt16(data, offset); offset += 2;
    r.i = data[offset++]; r.r = data[offset++];
    r.iff1 = data[offset++] != 0; r.iff2 = data[offset++] != 0;
    r.im = data[offset++]; r.halted = data[offset++] != 0;
    r.exAF(); r.af = _readInt16(data, offset); offset += 2; r.exAF();
    r.exx();
    r.bc = _readInt16(data, offset); offset += 2;
    r.de = _readInt16(data, offset); offset += 2;
    r.hl = _readInt16(data, offset); offset += 2;
    r.exx();
  }

  void _deserializeVdp(Uint8List data, int offset) {
    for (int i = 0; i < 16384; i++) _vdp.vram[i] = data[offset++];
    for (int i = 0; i < 32; i++) _vdp.cram[i] = data[offset++];
    for (int i = 0; i < 16; i++) _vdp.registers[i] = data[offset++];
  }

  void _deserializePsg(Uint8List data, int offset) {
    for (int i = 0; i < 3; i++) {
      _psg.toneRegisters[i] = _readInt16(data, offset); offset += 2;
    }
    for (int i = 0; i < 4; i++) _psg.volumes[i] = data[offset++];
  }

  void _deserializeMemory(Uint8List data, int offset) {
    // Restore RAM and bank registers via writes to appropriate addresses
    for (int i = 0; i < 8192; i++) {
      _memoryBus.write(0xC000 + i, data[offset++]);
    }
    _memoryBus.write(0xFFFD, data[offset++]);
    _memoryBus.write(0xFFFE, data[offset++]);
    _memoryBus.write(0xFFFF, data[offset++]);
    _memoryBus.write(0xFFFC, data[offset++]);
  }

  void _writeInt16(BytesBuilder b, int value) {
    b.addByte(value & 0xFF);
    b.addByte((value >> 8) & 0xFF);
  }

  void _writeInt32(BytesBuilder b, int value) {
    b.addByte(value & 0xFF);
    b.addByte((value >> 8) & 0xFF);
    b.addByte((value >> 16) & 0xFF);
    b.addByte((value >> 24) & 0xFF);
  }

  int _readInt16(Uint8List data, int offset) {
    return data[offset] | (data[offset + 1] << 8);
  }

  int _readInt32(Uint8List data, int offset) {
    return data[offset] | (data[offset + 1] << 8) |
           (data[offset + 2] << 16) | (data[offset + 3] << 24);
  }

  void dispose() {
    super.dispose();
  }
}

/// Bridges MemoryBus and IoPorts into the Bus interface for Z80CPU
class _SystemBus implements Bus {
  final MemoryBus _memoryBus;
  final IoPorts _ioPorts;

  _SystemBus(this._memoryBus, this._ioPorts);

  @override
  int read(int address) => _memoryBus.read(address);

  @override
  void write(int address, int value) => _memoryBus.write(address, value);

  @override
  int ioRead(int port) => _ioPorts.read(port);

  @override
  void ioWrite(int port, int value) => _ioPorts.write(port, value);
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/emulator/emulator_test.dart`
Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/emulator/emulator.dart test/emulator/emulator_test.dart
git commit -m "feat: integrate all emulation components into Emulator class"
```

---

## Phase 4: Flutter UI

### Task 11: Screen Painter (CustomPainter)

**Files:**
- Create: `lib/ui/screen_painter.dart`

- [ ] **Step 1: Implement ScreenPainter**

Create `lib/ui/screen_painter.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ScreenPainter extends CustomPainter {
  final Uint32List frameBuffer;
  ui.Image? _cachedImage;

  ScreenPainter({required this.frameBuffer});

  @override
  void paint(Canvas canvas, Size size) {
    // Convert frame buffer to image
    final pixels = frameBuffer.buffer.asUint8List();
    final completer = ui.ImmutableBuffer.fromUint8List(pixels);

    // Use decodeImageFromPixels for now — optimize later if needed
    // For CustomPainter, we use a pre-built image approach
    if (_cachedImage != null) {
      final srcRect = Rect.fromLTWH(0, 0, 256, 192);
      final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(_cachedImage!, srcRect, dstRect, Paint()
        ..filterQuality = FilterQuality.low);
    }
  }

  @override
  bool shouldRepaint(ScreenPainter oldDelegate) => true;
}

/// Widget that efficiently renders the emulator frame buffer
class EmulatorDisplay extends StatefulWidget {
  final Uint32List frameBuffer;
  final VoidCallback? onFrameReady;

  const EmulatorDisplay({
    super.key,
    required this.frameBuffer,
    this.onFrameReady,
  });

  @override
  State<EmulatorDisplay> createState() => _EmulatorDisplayState();
}

class _EmulatorDisplayState extends State<EmulatorDisplay> {
  ui.Image? _image;

  @override
  void didUpdateWidget(EmulatorDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateImage();
  }

  @override
  void initState() {
    super.initState();
    _updateImage();
  }

  void _updateImage() {
    final pixels = widget.frameBuffer.buffer.asUint8List();
    ui.decodeImageFromPixels(
      pixels,
      256,
      192,
      ui.PixelFormat.bgra8888,
      (ui.Image img) {
        if (mounted) {
          setState(() {
            _image?.dispose();
            _image = img;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 256 / 192, // 4:3
      child: CustomPaint(
        painter: _ImagePainter(image: _image),
        size: Size.infinite,
      ),
    );
  }
}

class _ImagePainter extends CustomPainter {
  final ui.Image? image;
  _ImagePainter({this.image});

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.black);
      return;
    }
    final src = Rect.fromLTWH(0, 0, 256, 192);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image!, src, dst, Paint()
      ..filterQuality = FilterQuality.low);
  }

  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/ui/screen_painter.dart
git commit -m "feat: add EmulatorDisplay widget with CustomPainter rendering"
```

---

### Task 12: Virtual Pad

**Files:**
- Create: `lib/ui/virtual_pad.dart`

- [ ] **Step 1: Implement VirtualPad**

Create `lib/ui/virtual_pad.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:sega3/emulator/emulator.dart';

class VirtualPad extends StatelessWidget {
  final void Function(EmulatorButton) onButtonDown;
  final void Function(EmulatorButton) onButtonUp;

  const VirtualPad({
    super.key,
    required this.onButtonDown,
    required this.onButtonUp,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // D-Pad (left side)
          _buildDPad(),
          // Action buttons (right side)
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildDPad() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _padButton(EmulatorButton.up, Icons.arrow_drop_up, 56),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _padButton(EmulatorButton.left, Icons.arrow_left, 56),
              const SizedBox(width: 48, height: 48),
              _padButton(EmulatorButton.right, Icons.arrow_right, 56),
            ],
          ),
          _padButton(EmulatorButton.down, Icons.arrow_drop_down, 56),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton(EmulatorButton.button1, '1'),
            const SizedBox(width: 16),
            _actionButton(EmulatorButton.button2, '2'),
          ],
        ),
        const SizedBox(height: 16),
        _startButton(),
      ],
    );
  }

  Widget _padButton(EmulatorButton button, IconData icon, double size) {
    return GestureDetector(
      onTapDown: (_) => onButtonDown(button),
      onTapUp: (_) => onButtonUp(button),
      onTapCancel: () => onButtonUp(button),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _actionButton(EmulatorButton button, String label) {
    return GestureDetector(
      onTapDown: (_) => onButtonDown(button),
      onTapUp: (_) => onButtonUp(button),
      onTapCancel: () => onButtonUp(button),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.red[700],
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _startButton() {
    return GestureDetector(
      onTapDown: (_) => onButtonDown(EmulatorButton.start),
      onTapUp: (_) => onButtonUp(EmulatorButton.start),
      onTapCancel: () => onButtonUp(EmulatorButton.start),
      child: Container(
        width: 80,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey[600],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('START',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/ui/virtual_pad.dart
git commit -m "feat: add VirtualPad widget with D-pad and action buttons"
```

---

### Task 13: Home Screen and Game Screen

**Files:**
- Create: `lib/ui/home_screen.dart`
- Create: `lib/ui/game_screen.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Implement HomeScreen**

Create `lib/ui/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:sega3/ui/game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _loadRom(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sms', 'sg'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final romData = await file.readAsBytes();

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen(romData: Uint8List.fromList(romData)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SEGA Mark III',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Emulator',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => _loadRom(context),
              icon: const Icon(Icons.folder_open),
              label: const Text('ROM を読み込む'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement GameScreen**

Create `lib/ui/game_screen.dart`:

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sega3/emulator/emulator.dart';
import 'package:sega3/ui/screen_painter.dart';
import 'package:sega3/ui/virtual_pad.dart';

class GameScreen extends StatefulWidget {
  final Uint8List romData;

  const GameScreen({super.key, required this.romData});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late Emulator _emulator;
  late Ticker _ticker;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _emulator = Emulator(widget.romData);
    _emulator.addListener(_onFrame);
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!_paused) {
      _emulator.runFrame();
    }
  }

  void _onFrame() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    _emulator.removeListener(_onFrame);
    _emulator.dispose();
    super.dispose();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Menu bar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white),
                  onPressed: _togglePause,
                ),
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.white),
                  onPressed: () {
                    // TODO: save state dialog
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            // Game display
            Expanded(
              flex: 3,
              child: Center(
                child: EmulatorDisplay(frameBuffer: _emulator.frameBuffer),
              ),
            ),
            // Virtual pad
            Expanded(
              flex: 2,
              child: VirtualPad(
                onButtonDown: _emulator.pressButton,
                onButtonUp: _emulator.releaseButton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update main.dart**

Replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sega3/ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const Sega3App());
}

class Sega3App extends StatelessWidget {
  const Sega3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SEGA Mark III Emulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
```

- [ ] **Step 4: Run app build check**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/ui/home_screen.dart lib/ui/game_screen.dart
git commit -m "feat: add HomeScreen with ROM picker and GameScreen with Ticker-based emulation loop"
```

---

## Phase 5: Save State Persistence

### Task 14: Save/Load State with File Persistence

**Files:**
- Create: `lib/emulator/save_state.dart`
- Modify: `lib/ui/game_screen.dart`

- [ ] **Step 1: Implement SaveStateManager**

Create `lib/emulator/save_state.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class SaveStateManager {
  static const int maxSlots = 3;

  /// Get save directory for a given ROM name
  static Future<Directory> _getSaveDir(String romName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${appDir.path}/sega3_saves/$romName');
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
    return saveDir;
  }

  /// Save state to a numbered slot (0-2)
  static Future<void> saveToSlot(String romName, int slot, Uint8List stateData) async {
    if (slot < 0 || slot >= maxSlots) return;
    final dir = await _getSaveDir(romName);
    final file = File('${dir.path}/state_$slot.sav');
    await file.writeAsBytes(stateData);
  }

  /// Load state from a numbered slot
  static Future<Uint8List?> loadFromSlot(String romName, int slot) async {
    if (slot < 0 || slot >= maxSlots) return null;
    final dir = await _getSaveDir(romName);
    final file = File('${dir.path}/state_$slot.sav');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  /// Check which slots have saves
  static Future<List<bool>> getSlotStatus(String romName) async {
    final dir = await _getSaveDir(romName);
    final status = <bool>[];
    for (int i = 0; i < maxSlots; i++) {
      final file = File('${dir.path}/state_$i.sav');
      status.add(await file.exists());
    }
    return status;
  }

  /// Save battery backup RAM
  static Future<void> saveBatteryRam(String romName, Uint8List ram) async {
    final dir = await _getSaveDir(romName);
    final file = File('${dir.path}/battery.sram');
    await file.writeAsBytes(ram);
  }

  /// Load battery backup RAM
  static Future<Uint8List?> loadBatteryRam(String romName) async {
    final dir = await _getSaveDir(romName);
    final file = File('${dir.path}/battery.sram');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/emulator/save_state.dart
git commit -m "feat: add SaveStateManager for slot-based save/load and battery backup"
```

---

### Task 15: Integrate save/load into GameScreen UI

**Files:**
- Modify: `lib/ui/game_screen.dart`

- [ ] **Step 1: Add save/load dialog to GameScreen**

Update the save button's `onPressed` in `game_screen.dart` to show a dialog with 3 save slots and load/save options. Add a `_romName` getter that extracts the filename from the ROM path. Wire up `SaveStateManager.saveToSlot()` and `loadFromSlot()` with `_emulator.saveState()` and `_emulator.loadState()`.

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/ui/game_screen.dart
git commit -m "feat: add save/load state dialog with 3 slots"
```

---

## Phase 6: Clean-up and Delete Boilerplate

### Task 16: Remove boilerplate test, final cleanup

**Files:**
- Modify: `test/widget_test.dart` (delete)

- [ ] **Step 1: Remove default Flutter test**

Delete `test/widget_test.dart` (the default counter app test).

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git rm test/widget_test.dart
git commit -m "chore: remove boilerplate test, final cleanup"
```

---

---

## Critical Amendments (Post-Review)

The following amendments address critical issues identified during plan review. Implementers MUST incorporate these changes.

### Amendment A: Z80 CPU Task 3 MUST be split into sub-tasks

Task 3 is too large for a single implementation step (~2000-3000 lines). Split into:

- **Task 3a**: Core fetch/decode loop + 8-bit loads + 16-bit loads + NOP/HALT/DI/EI
- **Task 3b**: 8-bit arithmetic (ADD/ADC/SUB/SBC/AND/OR/XOR/CP/INC/DEC) + DAA + 16-bit arithmetic + rotates (RLCA/RRCA/RLA/RRA)
- **Task 3c**: Jumps (JP/JR/DJNZ), calls (CALL/RET/RST), stack (PUSH/POP), exchange (EX), I/O (IN/OUT)
- **Task 3d**: CB prefix (BIT/SET/RES/RLC/RRC/RL/RR/SLA/SRA/SRL)
- **Task 3e**: ED prefix (block ops LDI/LDIR/LDD/LDDR/CPI/CPIR/CPD/CPDR/INI/INIR/OUTI/OTIR, IM, NEG, RETI/RETN, LD I,A, LD A,I) + DD/FD prefix (IX/IY variants) + DDCB/FDCB

Run Task 3 tests after each sub-task. All must pass before proceeding.

**Additional required tests** (add to Task 4):
```dart
test('DAA after BCD addition', () {
  // 0x15 + 0x27 = 0x42 in BCD
  bus.loadAt(0, [0x3E, 0x15, 0xC6, 0x27, 0x27]); // LD A,0x15; ADD A,0x27; DAA
  cpu.step(); cpu.step(); cpu.step();
  expect(cpu.regs.a, 0x42);
});

test('OTIR — output block', () {
  bus.loadAt(0x1000, [0xAA, 0xBB, 0xCC]);
  bus.loadAt(0, [
    0x21, 0x00, 0x10, // LD HL, 0x1000
    0x01, 0x03, 0xBE, // LD BC, 0x03BE (B=3, C=0xBE)
    0xED, 0xB3,       // OTIR
  ]);
  cpu.step(); cpu.step(); cpu.step();
  expect(cpu.regs.b, 0);
  // Verify 3 bytes were output to port 0xBE
});

test('IN A,(C)', () {
  bus.ioPorts[0x42] = 0xDD;
  bus.loadAt(0, [0x0E, 0x42, 0xED, 0x78]); // LD C,0x42; IN A,(C)
  cpu.step(); cpu.step();
  expect(cpu.regs.a, 0xDD);
});
```

### Amendment B: VDP rendering implementation details

Task 7 Step 3 must include actual rendering code. Key implementation for Mode 4 background:

```dart
void _renderBackgroundLine(int line) {
  int nameTableBase = (registers[2] & 0x0E) << 10; // reg2 bits 1-3
  int hScroll = registers[8];
  int vScroll = registers[9];

  int row = ((line + vScroll) % 224);
  int tileRow = row ~/ 8;
  int fineY = row % 8;

  for (int col = 0; col < 32; col++) {
    int screenX = (col * 8 - hScroll) & 0xFF;

    // Fixed columns: right 8 columns don't scroll horizontally
    if (col >= 24 && (registers[0] & 0x80) != 0) {
      screenX = col * 8;
    }
    // Fixed rows: top 2 rows don't scroll vertically
    int actualRow = tileRow;
    int actualFineY = fineY;
    if (line < 16 && (registers[0] & 0x40) != 0) {
      actualRow = line ~/ 8;
      actualFineY = line % 8;
    }

    int nameAddr = nameTableBase + (actualRow * 32 + col) * 2;
    int word = vram[nameAddr] | (vram[nameAddr + 1] << 8);
    int tileIndex = word & 0x1FF;
    bool hFlip = (word & 0x200) != 0;
    bool vFlip = (word & 0x400) != 0;
    bool priority = (word & 0x1000) != 0;
    int palette = (word & 0x800) != 0 ? 16 : 0;

    int tileY = vFlip ? (7 - actualFineY) : actualFineY;
    int tileAddr = tileIndex * 32 + tileY * 4;

    // Decode planar 4bpp tile data
    int b0 = vram[tileAddr], b1 = vram[tileAddr + 1];
    int b2 = vram[tileAddr + 2], b3 = vram[tileAddr + 3];

    for (int px = 0; px < 8; px++) {
      int bit = hFlip ? px : (7 - px);
      int colorIdx = ((b0 >> bit) & 1) | (((b1 >> bit) & 1) << 1) |
                     (((b2 >> bit) & 1) << 2) | (((b3 >> bit) & 1) << 3);
      int x = (screenX + px) & 0xFF;
      if (x < 256 && line < 192) {
        int cramValue = cram[palette + colorIdx];
        frameBuffer[line * 256 + x] = _cramToArgb(cramValue);
      }
    }
  }
}

int _cramToArgb(int cramValue) {
  // CRAM format: --BBGGRR (6-bit)
  int r = (cramValue & 0x03) * 85;       // 0-3 -> 0-255
  int g = ((cramValue >> 2) & 0x03) * 85;
  int b = ((cramValue >> 4) & 0x03) * 85;
  return 0xFF000000 | (b << 16) | (g << 8) | r; // BGRA for Flutter
}
```

**IMPORTANT**: The VDP must output pixels in **BGRA** order (not ARGB) to match `ui.PixelFormat.bgra8888` used in `screen_painter.dart`. The `_cramToArgb` function above already does this (`0xFF000000 | (b << 16) | (g << 8) | r`).

Sprite rendering follows similar pattern: scan SAT at `(registers[5] & 0x7E) << 7`, check Y position against current line, fetch tile data, render up to 8 sprites per line.

**Additional VDP test** (add to Task 7):
```dart
test('background tile renders correct pixels', () {
  // Set up Mode 4
  vdp.writeControl(0x06); vdp.writeControl(0x80); // reg0 = 0x06 (Mode 4)
  vdp.writeControl(0x00); vdp.writeControl(0x81); // reg1 = 0x00
  vdp.writeControl(0xFF); vdp.writeControl(0x82); // reg2 = 0xFF (name table at 0x3800)

  // Write a tile pattern to VRAM at tile 0 (addr 0x0000)
  // Solid color tile (all pixels = color 1)
  vdp.writeControl(0x00); vdp.writeControl(0x40); // VRAM write at 0x0000
  for (int row = 0; row < 8; row++) {
    vdp.writeData(0xFF); // plane 0 = all 1s
    vdp.writeData(0x00); // plane 1 = all 0s
    vdp.writeData(0x00); // plane 2 = all 0s
    vdp.writeData(0x00); // plane 3 = all 0s
  }

  // Write name table entry at 0x3800 pointing to tile 0
  vdp.writeControl(0x00); vdp.writeControl(0x78); // VRAM write at 0x3800
  vdp.writeData(0x00); vdp.writeData(0x00); // tile 0, no flags

  // Write CRAM color 1
  vdp.writeControl(0x01); vdp.writeControl(0xC0); // CRAM write at index 1
  vdp.writeData(0x03); // Red (RR=11)

  // Render scanline 0
  vdp.renderScanline();

  // Check that pixels at the start of the scanline are color 1 (red)
  int pixel = vdp.frameBuffer[0]; // first pixel, line 0
  // BGRA: 0xFF0000FF would be wrong, should be 0xFF000003*85 = 0xFF0000FF
  expect(pixel & 0x00FFFFFF, isNot(0)); // Not black
});
```

### Amendment C: Audio output pipeline

**Add Task 10b** between Task 10 and Task 11:

**Task 10b: Audio Output Pipeline**

**Files:**
- Create: `lib/emulator/audio_output.dart`
- Modify: `lib/emulator/emulator.dart`
- Modify: `lib/ui/game_screen.dart`

Create an `AudioOutput` class that:
1. Initializes `flutter_soloud` on startup
2. Provides a `void pushSamples(Float64List samples)` method
3. Converts Float64List to Int16 PCM and writes to a streaming audio buffer
4. Handles audio lifecycle (init, dispose)

Update `Emulator.runFrame()` to pass PSG samples to AudioOutput:
```dart
final samples = _psg.generateSamples(_samplesPerFrame);
_audioOutput?.pushSamples(samples);
```

Update `GameScreen` to initialize and dispose `AudioOutput`.

### Amendment D: Fix PSG fractional cycle accumulation

In PSG `generateSamples()`, replace integer truncation with fractional accumulator:

```dart
double _toneAccum0 = 0, _toneAccum1 = 0, _toneAccum2 = 0;
double _noiseAccum = 0;

// In the loop, instead of:
//   _toneCounters[ch] -= cyclesPerSample.toInt();
// Use:
//   _toneAccum += cyclesPerSample;
//   while (_toneAccum >= toneRegisters[ch]) { flip; _toneAccum -= toneRegisters[ch]; }
```

### Amendment E: Fix state save/load bank register corruption

In `_deserializeMemory()`, add a `restoreRamDirect()` method to MemoryBus that writes to RAM without triggering bank register logic:

```dart
// Add to MemoryBus:
void restoreRamDirect(Uint8List data) {
  for (int i = 0; i < 8192 && i < data.length; i++) {
    _ram[i] = data[i];
  }
}
void restoreBankRegisters(int ramCtrl, int s0, int s1, int s2) {
  _ramControl = ramCtrl;
  _slot0Bank = s0 % _pageCount;
  _slot1Bank = s1 % _pageCount;
  _slot2Bank = s2 % _pageCount;
}
```

Update `_deserializeMemory()` to use these methods instead of `write()`.

### Amendment F: Cycle overshoot carry-over

In `Emulator.runFrame()`, carry excess cycles to the next scanline:

```dart
int _excessCycles = 0;

void runFrame() {
  for (int scanline = 0; scanline < _scanlinesPerFrame; scanline++) {
    int cyclesThisScanline = _excessCycles;
    while (cyclesThisScanline < _cyclesPerScanline) {
      cyclesThisScanline += _cpu.step();
    }
    _excessCycles = cyclesThisScanline - _cyclesPerScanline;
    // ... rest of scanline
  }
}
```

### Amendment G: Battery backup lifecycle integration

Update `GameScreen` to:
1. Load battery RAM on init (if exists) and apply to emulator MemoryBus
2. Save battery RAM on dispose and on `AppLifecycleState.paused` (via `WidgetsBindingObserver`)
3. Add `Emulator.loadBatteryRam(Uint8List)` and `Emulator.getBatteryRam()` methods

### Amendment H: ROM validation

Update `HomeScreen._loadRom()` to validate:
- Minimum ROM size (16KB)
- Maximum ROM size (4MB)
- Show error dialog on failure

---

## Summary

| Phase | Tasks | What it delivers |
|-------|-------|-----------------|
| 1: CPU Core | Tasks 1-4 (Task 3 split into 3a-3e) | Z80 CPU with full instruction set, tested |
| 2: Memory & Video | Tasks 5-7 | ROM loading, memory mapping, VDP rendering |
| 3: Sound & Integration | Tasks 8-10, 10b | PSG audio with playback, I/O routing, full system loop |
| 4: Flutter UI | Tasks 11-13 | Screen display, virtual pad, home/game screens |
| 5: Save System | Tasks 14-15 | State save/load with 3 slots + battery backup |
| 6: Cleanup | Task 16 | Remove boilerplate, verify all tests pass |

**Total: 20 tasks (after splitting), ~100 steps**

After completing all tasks and amendments, the emulator should boot and run the target games (Alex Kidd, Hang-On, Fantasy Zone) on Android and iOS with touch controls, audio, and save states.
