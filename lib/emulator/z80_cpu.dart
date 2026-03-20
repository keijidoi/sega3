import 'bus.dart';
import 'z80_registers.dart';

/// Complete Z80 CPU emulator.
class Z80CPU {
  final Bus _bus;
  final Z80Registers regs = Z80Registers();

  Z80CPU(this._bus);

  // ── Helper methods ────────────────────────────────────────────────────────

  /// Fetch byte at PC, increment PC and R register (lower 7 bits).
  int _fetch() {
    final value = _bus.read(regs.pc);
    regs.pc = (regs.pc + 1) & 0xFFFF;
    regs.r = (regs.r & 0x80) | ((regs.r + 1) & 0x7F);
    return value;
  }

  /// Fetch 16-bit value (little-endian) at PC.
  int _fetch16() {
    final lo = _fetch();
    final hi = _fetch();
    return (hi << 8) | lo;
  }

  /// Read 16-bit value from memory (little-endian).
  int _read16(int address) {
    final lo = _bus.read(address & 0xFFFF);
    final hi = _bus.read((address + 1) & 0xFFFF);
    return (hi << 8) | lo;
  }

  /// Write 16-bit value to memory (little-endian).
  void _write16(int address, int value) {
    _bus.write(address & 0xFFFF, value & 0xFF);
    _bus.write((address + 1) & 0xFFFF, (value >> 8) & 0xFF);
  }

  /// Sign-extend an 8-bit value to a signed integer.
  int _signExtend(int byte) {
    return (byte < 128) ? byte : byte - 256;
  }

  /// Push 16-bit value onto stack.
  void _push16(int value) {
    regs.sp = (regs.sp - 1) & 0xFFFF;
    _bus.write(regs.sp, (value >> 8) & 0xFF);
    regs.sp = (regs.sp - 1) & 0xFFFF;
    _bus.write(regs.sp, value & 0xFF);
  }

  /// Pop 16-bit value from stack.
  int _pop16() {
    final lo = _bus.read(regs.sp);
    regs.sp = (regs.sp + 1) & 0xFFFF;
    final hi = _bus.read(regs.sp);
    regs.sp = (regs.sp + 1) & 0xFFFF;
    return (hi << 8) | lo;
  }

  /// Parity: true if even number of 1-bits.
  bool _parity(int value) {
    value &= 0xFF;
    int bits = 0;
    for (int i = 0; i < 8; i++) {
      if ((value & (1 << i)) != 0) bits++;
    }
    return (bits & 1) == 0;
  }

  /// Set S, Z, and PV (parity) flags for a result byte.
  void _setSZP(int result) {
    result &= 0xFF;
    regs.flagS = (result & 0x80) != 0;
    regs.flagZ = result == 0;
    regs.flagPV = _parity(result);
  }

  // ── 8-bit register access by index ────────────────────────────────────────
  // Index: 0=B, 1=C, 2=D, 3=E, 4=H, 5=L, 6=(HL), 7=A

  int _getReg8(int index) {
    switch (index) {
      case 0: return regs.b;
      case 1: return regs.c;
      case 2: return regs.d;
      case 3: return regs.e;
      case 4: return regs.h;
      case 5: return regs.l;
      case 6: return _bus.read(regs.hl);
      case 7: return regs.a;
      default: return 0;
    }
  }

  void _setReg8(int index, int value) {
    value &= 0xFF;
    switch (index) {
      case 0: regs.b = value; break;
      case 1: regs.c = value; break;
      case 2: regs.d = value; break;
      case 3: regs.e = value; break;
      case 4: regs.h = value; break;
      case 5: regs.l = value; break;
      case 6: _bus.write(regs.hl, value); break;
      case 7: regs.a = value; break;
    }
  }

  // ── 16-bit register pair access ───────────────────────────────────────────
  // Index: 0=BC, 1=DE, 2=HL, 3=SP

  int _getReg16(int index) {
    switch (index) {
      case 0: return regs.bc;
      case 1: return regs.de;
      case 2: return regs.hl;
      case 3: return regs.sp;
      default: return 0;
    }
  }

  void _setReg16(int index, int value) {
    value &= 0xFFFF;
    switch (index) {
      case 0: regs.bc = value; break;
      case 1: regs.de = value; break;
      case 2: regs.hl = value; break;
      case 3: regs.sp = value; break;
    }
  }

  // Push/Pop pairs: 0=BC, 1=DE, 2=HL, 3=AF
  int _getReg16AF(int index) {
    switch (index) {
      case 0: return regs.bc;
      case 1: return regs.de;
      case 2: return regs.hl;
      case 3: return regs.af;
      default: return 0;
    }
  }

  void _setReg16AF(int index, int value) {
    value &= 0xFFFF;
    switch (index) {
      case 0: regs.bc = value; break;
      case 1: regs.de = value; break;
      case 2: regs.hl = value; break;
      case 3: regs.af = value; break;
    }
  }

  // ── Condition evaluation ──────────────────────────────────────────────────
  // 0=NZ, 1=Z, 2=NC, 3=C, 4=PO, 5=PE, 6=P, 7=M

  bool _evalCondition(int cc) {
    switch (cc) {
      case 0: return !regs.flagZ;
      case 1: return regs.flagZ;
      case 2: return !regs.flagC;
      case 3: return regs.flagC;
      case 4: return !regs.flagPV;
      case 5: return regs.flagPV;
      case 6: return !regs.flagS;
      case 7: return regs.flagS;
      default: return false;
    }
  }

  // ── INC/DEC flags ─────────────────────────────────────────────────────────

  int _incFlags(int value) {
    final result = (value + 1) & 0xFF;
    regs.flagS = (result & 0x80) != 0;
    regs.flagZ = result == 0;
    regs.flagH = (value & 0x0F) == 0x0F;
    regs.flagPV = value == 0x7F;
    regs.flagN = false;
    return result;
  }

  int _decFlags(int value) {
    final result = (value - 1) & 0xFF;
    regs.flagS = (result & 0x80) != 0;
    regs.flagZ = result == 0;
    regs.flagH = (value & 0x0F) == 0x00;
    regs.flagPV = value == 0x80;
    regs.flagN = true;
    return result;
  }

  // ── 8-bit arithmetic/logic ────────────────────────────────────────────────

  void _addA(int value) {
    final a = regs.a;
    final result = a + value;
    final r8 = result & 0xFF;
    regs.flagS = (r8 & 0x80) != 0;
    regs.flagZ = r8 == 0;
    regs.flagH = ((a ^ value ^ result) & 0x10) != 0;
    regs.flagPV = ((~(a ^ value) & (a ^ result)) & 0x80) != 0;
    regs.flagN = false;
    regs.flagC = result > 0xFF;
    regs.a = r8;
  }

  void _adcA(int value) {
    final a = regs.a;
    final c = regs.flagC ? 1 : 0;
    final result = a + value + c;
    final r8 = result & 0xFF;
    regs.flagS = (r8 & 0x80) != 0;
    regs.flagZ = r8 == 0;
    regs.flagH = ((a ^ value ^ result) & 0x10) != 0;
    regs.flagPV = ((~(a ^ value) & (a ^ result)) & 0x80) != 0;
    regs.flagN = false;
    regs.flagC = result > 0xFF;
    regs.a = r8;
  }

  void _subA(int value) {
    final a = regs.a;
    final result = a - value;
    final r8 = result & 0xFF;
    regs.flagS = (r8 & 0x80) != 0;
    regs.flagZ = r8 == 0;
    regs.flagH = ((a ^ value ^ result) & 0x10) != 0;
    regs.flagPV = (((a ^ value) & (a ^ result)) & 0x80) != 0;
    regs.flagN = true;
    regs.flagC = result < 0;
    regs.a = r8;
  }

  void _sbcA(int value) {
    final a = regs.a;
    final c = regs.flagC ? 1 : 0;
    final result = a - value - c;
    final r8 = result & 0xFF;
    regs.flagS = (r8 & 0x80) != 0;
    regs.flagZ = r8 == 0;
    regs.flagH = ((a ^ value ^ result) & 0x10) != 0;
    regs.flagPV = (((a ^ value) & (a ^ result)) & 0x80) != 0;
    regs.flagN = true;
    regs.flagC = result < 0;
    regs.a = r8;
  }

  void _andA(int value) {
    regs.a = regs.a & value & 0xFF;
    regs.flagS = (regs.a & 0x80) != 0;
    regs.flagZ = regs.a == 0;
    regs.flagH = true;
    regs.flagPV = _parity(regs.a);
    regs.flagN = false;
    regs.flagC = false;
  }

  void _orA(int value) {
    regs.a = (regs.a | value) & 0xFF;
    regs.flagS = (regs.a & 0x80) != 0;
    regs.flagZ = regs.a == 0;
    regs.flagH = false;
    regs.flagPV = _parity(regs.a);
    regs.flagN = false;
    regs.flagC = false;
  }

  void _xorA(int value) {
    regs.a = (regs.a ^ value) & 0xFF;
    regs.flagS = (regs.a & 0x80) != 0;
    regs.flagZ = regs.a == 0;
    regs.flagH = false;
    regs.flagPV = _parity(regs.a);
    regs.flagN = false;
    regs.flagC = false;
  }

  void _cpA(int value) {
    final a = regs.a;
    final result = a - value;
    final r8 = result & 0xFF;
    regs.flagS = (r8 & 0x80) != 0;
    regs.flagZ = r8 == 0;
    regs.flagH = ((a ^ value ^ result) & 0x10) != 0;
    regs.flagPV = (((a ^ value) & (a ^ result)) & 0x80) != 0;
    regs.flagN = true;
    regs.flagC = result < 0;
  }

  /// Perform ALU operation by index: 0=ADD, 1=ADC, 2=SUB, 3=SBC, 4=AND, 5=XOR, 6=OR, 7=CP
  void _alu(int op, int value) {
    switch (op) {
      case 0: _addA(value); break;
      case 1: _adcA(value); break;
      case 2: _subA(value); break;
      case 3: _sbcA(value); break;
      case 4: _andA(value); break;
      case 5: _xorA(value); break;
      case 6: _orA(value); break;
      case 7: _cpA(value); break;
    }
  }

  // ── 16-bit arithmetic ─────────────────────────────────────────────────────

  void _addHL(int value) {
    final hl = regs.hl;
    final result = hl + value;
    regs.flagH = ((hl ^ value ^ result) & 0x1000) != 0;
    regs.flagN = false;
    regs.flagC = result > 0xFFFF;
    regs.hl = result & 0xFFFF;
  }

  void _adcHL(int value) {
    final hl = regs.hl;
    final c = regs.flagC ? 1 : 0;
    final result = hl + value + c;
    final r16 = result & 0xFFFF;
    regs.flagS = (r16 & 0x8000) != 0;
    regs.flagZ = r16 == 0;
    regs.flagH = ((hl ^ value ^ result) & 0x1000) != 0;
    regs.flagPV = ((~(hl ^ value) & (hl ^ result)) & 0x8000) != 0;
    regs.flagN = false;
    regs.flagC = result > 0xFFFF;
    regs.hl = r16;
  }

  void _sbcHL(int value) {
    final hl = regs.hl;
    final c = regs.flagC ? 1 : 0;
    final result = hl - value - c;
    final r16 = result & 0xFFFF;
    regs.flagS = (r16 & 0x8000) != 0;
    regs.flagZ = r16 == 0;
    regs.flagH = ((hl ^ value ^ result) & 0x1000) != 0;
    regs.flagPV = (((hl ^ value) & (hl ^ result)) & 0x8000) != 0;
    regs.flagN = true;
    regs.flagC = result < 0;
    regs.hl = r16;
  }

  // ── IX/IY arithmetic helpers ──────────────────────────────────────────────

  int _addIXIY(int base, int value) {
    final result = base + value;
    regs.flagH = ((base ^ value ^ result) & 0x1000) != 0;
    regs.flagN = false;
    regs.flagC = result > 0xFFFF;
    return result & 0xFFFF;
  }

  // ── DAA ───────────────────────────────────────────────────────────────────

  void _daa() {
    int a = regs.a;
    int correction = 0;
    bool carry = regs.flagC;

    if (regs.flagN) {
      // After subtraction
      if (regs.flagH || (a & 0x0F) > 9) {
        correction |= 0x06;
      }
      if (carry || a > 0x99) {
        correction |= 0x60;
        carry = true;
      }
      a = (a - correction) & 0xFF;
    } else {
      // After addition
      if (regs.flagH || (a & 0x0F) > 9) {
        correction |= 0x06;
      }
      if (carry || a > 0x99) {
        correction |= 0x60;
        carry = true;
      }
      a = (a + correction) & 0xFF;
    }

    regs.a = a;
    regs.flagS = (a & 0x80) != 0;
    regs.flagZ = a == 0;
    regs.flagH = ((regs.a ^ correction ^ a) & 0x10) != 0; // Simplified
    regs.flagPV = _parity(a);
    regs.flagC = carry;
  }

  // ── CB prefix operations ──────────────────────────────────────────────────

  int _cbOperation(int op, int bit, int value) {
    switch (op) {
      case 0: // Rotate/shift
        return _cbRotShift(bit, value);
      case 1: // BIT
        _bitTest(bit, value);
        return value; // unchanged
      case 2: // RES
        return value & ~(1 << bit) & 0xFF;
      case 3: // SET
        return value | (1 << bit) & 0xFF;
      default: return value;
    }
  }

  int _cbRotShift(int op, int value) {
    int result;
    switch (op) {
      case 0: // RLC
        final bit7 = (value >> 7) & 1;
        result = ((value << 1) | bit7) & 0xFF;
        regs.flagC = bit7 != 0;
        break;
      case 1: // RRC
        final bit0 = value & 1;
        result = ((value >> 1) | (bit0 << 7)) & 0xFF;
        regs.flagC = bit0 != 0;
        break;
      case 2: // RL
        final bit7 = (value >> 7) & 1;
        result = ((value << 1) | (regs.flagC ? 1 : 0)) & 0xFF;
        regs.flagC = bit7 != 0;
        break;
      case 3: // RR
        final bit0 = value & 1;
        result = ((value >> 1) | (regs.flagC ? 0x80 : 0)) & 0xFF;
        regs.flagC = bit0 != 0;
        break;
      case 4: // SLA
        regs.flagC = (value & 0x80) != 0;
        result = (value << 1) & 0xFF;
        break;
      case 5: // SRA
        regs.flagC = (value & 1) != 0;
        result = ((value >> 1) | (value & 0x80)) & 0xFF;
        break;
      case 6: // SLL (undocumented - shift left, bit 0 = 1)
        regs.flagC = (value & 0x80) != 0;
        result = ((value << 1) | 1) & 0xFF;
        break;
      case 7: // SRL
        regs.flagC = (value & 1) != 0;
        result = (value >> 1) & 0xFF;
        break;
      default:
        result = value;
    }
    regs.flagS = (result & 0x80) != 0;
    regs.flagZ = result == 0;
    regs.flagH = false;
    regs.flagN = false;
    regs.flagPV = _parity(result);
    return result;
  }

  void _bitTest(int bit, int value) {
    final test = value & (1 << bit);
    regs.flagZ = test == 0;
    regs.flagH = true;
    regs.flagN = false;
    regs.flagS = (bit == 7) && !regs.flagZ;
    regs.flagPV = regs.flagZ;
  }

  // ── NMI / Interrupt ───────────────────────────────────────────────────────

  void nmi() {
    regs.halted = false;
    regs.iff1 = false;
    _push16(regs.pc);
    regs.pc = 0x0066;
  }

  void interrupt() {
    if (!regs.iff1) return;
    regs.halted = false;
    regs.iff1 = false;
    regs.iff2 = false;
    _push16(regs.pc);
    switch (regs.im) {
      case 0:
      case 1:
        regs.pc = 0x0038;
        break;
      case 2:
        final addr = (regs.i << 8) | 0xFF;
        regs.pc = _read16(addr);
        break;
    }
  }

  // ── Main step ─────────────────────────────────────────────────────────────

  int step() {
    if (regs.halted) {
      // Still consume a NOP's worth of cycles and increment R
      regs.r = (regs.r & 0x80) | ((regs.r + 1) & 0x7F);
      return 4;
    }

    final opcode = _fetch();
    return _executeMain(opcode);
  }

  int _executeMain(int opcode) {
    // Decode by top 2 bits
    final x = (opcode >> 6) & 3;
    final y = (opcode >> 3) & 7;
    final z = opcode & 7;
    final p = (y >> 1) & 3;
    final q = y & 1;

    switch (x) {
      case 0:
        return _executeX0(y, z, p, q, opcode);
      case 1:
        // LD r, r' or HALT
        if (z == 6 && y == 6) {
          // HALT
          regs.halted = true;
          return 4;
        }
        if (y == 6) {
          // LD (HL), r
          _bus.write(regs.hl, _getReg8(z));
          return 7;
        }
        if (z == 6) {
          // LD r, (HL)
          _setReg8(y, _bus.read(regs.hl));
          return 7;
        }
        // LD r, r'
        _setReg8(y, _getReg8(z));
        return 4;
      case 2:
        // ALU A, r
        final val = _getReg8(z);
        _alu(y, val);
        return z == 6 ? 7 : 4;
      case 3:
        return _executeX3(y, z, p, q, opcode);
      default:
        return 4;
    }
  }

  int _executeX0(int y, int z, int p, int q, int opcode) {
    switch (z) {
      case 0:
        switch (y) {
          case 0: return 4; // NOP
          case 1: // EX AF, AF'
            regs.exAF();
            return 4;
          case 2: // DJNZ e
            final offset = _signExtend(_fetch());
            regs.b = (regs.b - 1) & 0xFF;
            if (regs.b != 0) {
              regs.pc = (regs.pc + offset) & 0xFFFF;
              return 13;
            }
            return 8;
          case 3: // JR e
            final offset = _signExtend(_fetch());
            regs.pc = (regs.pc + offset) & 0xFFFF;
            return 12;
          default: // JR cc, e (y=4..7 -> cc=y-4)
            final offset = _signExtend(_fetch());
            if (_evalCondition(y - 4)) {
              regs.pc = (regs.pc + offset) & 0xFFFF;
              return 12;
            }
            return 7;
        }
      case 1:
        if (q == 0) {
          // LD rr, nn
          _setReg16(p, _fetch16());
          return 10;
        } else {
          // ADD HL, rr
          _addHL(_getReg16(p));
          return 11;
        }
      case 2:
        if (q == 0) {
          switch (p) {
            case 0: // LD (BC), A
              _bus.write(regs.bc, regs.a);
              return 7;
            case 1: // LD (DE), A
              _bus.write(regs.de, regs.a);
              return 7;
            case 2: // LD (nn), HL
              final addr = _fetch16();
              _write16(addr, regs.hl);
              return 16;
            case 3: // LD (nn), A
              final addr = _fetch16();
              _bus.write(addr, regs.a);
              return 13;
          }
        } else {
          switch (p) {
            case 0: // LD A, (BC)
              regs.a = _bus.read(regs.bc);
              return 7;
            case 1: // LD A, (DE)
              regs.a = _bus.read(regs.de);
              return 7;
            case 2: // LD HL, (nn)
              final addr = _fetch16();
              regs.hl = _read16(addr);
              return 16;
            case 3: // LD A, (nn)
              final addr = _fetch16();
              regs.a = _bus.read(addr);
              return 13;
          }
        }
        return 4;
      case 3:
        if (q == 0) {
          // INC rr
          _setReg16(p, (_getReg16(p) + 1) & 0xFFFF);
          return 6;
        } else {
          // DEC rr
          _setReg16(p, (_getReg16(p) - 1) & 0xFFFF);
          return 6;
        }
      case 4:
        // INC r
        if (y == 6) {
          final val = _bus.read(regs.hl);
          _bus.write(regs.hl, _incFlags(val));
          return 11;
        }
        _setReg8(y, _incFlags(_getReg8(y)));
        return 4;
      case 5:
        // DEC r
        if (y == 6) {
          final val = _bus.read(regs.hl);
          _bus.write(regs.hl, _decFlags(val));
          return 11;
        }
        _setReg8(y, _decFlags(_getReg8(y)));
        return 4;
      case 6:
        // LD r, n
        final n = _fetch();
        if (y == 6) {
          _bus.write(regs.hl, n);
          return 10;
        }
        _setReg8(y, n);
        return 7;
      case 7:
        switch (y) {
          case 0: // RLCA
            final bit7 = (regs.a >> 7) & 1;
            regs.a = ((regs.a << 1) | bit7) & 0xFF;
            regs.flagC = bit7 != 0;
            regs.flagH = false;
            regs.flagN = false;
            return 4;
          case 1: // RRCA
            final bit0 = regs.a & 1;
            regs.a = ((regs.a >> 1) | (bit0 << 7)) & 0xFF;
            regs.flagC = bit0 != 0;
            regs.flagH = false;
            regs.flagN = false;
            return 4;
          case 2: // RLA
            final bit7 = (regs.a >> 7) & 1;
            regs.a = ((regs.a << 1) | (regs.flagC ? 1 : 0)) & 0xFF;
            regs.flagC = bit7 != 0;
            regs.flagH = false;
            regs.flagN = false;
            return 4;
          case 3: // RRA
            final bit0 = regs.a & 1;
            regs.a = ((regs.a >> 1) | (regs.flagC ? 0x80 : 0)) & 0xFF;
            regs.flagC = bit0 != 0;
            regs.flagH = false;
            regs.flagN = false;
            return 4;
          case 4: // DAA
            _daa();
            return 4;
          case 5: // CPL
            regs.a = (~regs.a) & 0xFF;
            regs.flagH = true;
            regs.flagN = true;
            return 4;
          case 6: // SCF
            regs.flagC = true;
            regs.flagH = false;
            regs.flagN = false;
            return 4;
          case 7: // CCF
            regs.flagH = regs.flagC;
            regs.flagC = !regs.flagC;
            regs.flagN = false;
            return 4;
        }
        return 4;
      default:
        return 4;
    }
  }

  int _executeX3(int y, int z, int p, int q, int opcode) {
    switch (z) {
      case 0:
        // RET cc
        if (_evalCondition(y)) {
          regs.pc = _pop16();
          return 11;
        }
        return 5;
      case 1:
        if (q == 0) {
          // POP rr
          _setReg16AF(p, _pop16());
          return 10;
        } else {
          switch (p) {
            case 0: // RET
              regs.pc = _pop16();
              return 10;
            case 1: // EXX
              regs.exx();
              return 4;
            case 2: // JP (HL)
              regs.pc = regs.hl;
              return 4;
            case 3: // LD SP, HL
              regs.sp = regs.hl;
              return 6;
          }
        }
        return 4;
      case 2:
        // JP cc, nn
        final addr = _fetch16();
        if (_evalCondition(y)) {
          regs.pc = addr;
        }
        return 10;
      case 3:
        switch (y) {
          case 0: // JP nn
            regs.pc = _fetch16();
            return 10;
          case 1: // CB prefix
            return _executeCB();
          case 2: // OUT (n), A
            final port = _fetch();
            _bus.ioWrite(port, regs.a);
            return 11;
          case 3: // IN A, (n)
            final port = _fetch();
            regs.a = _bus.ioRead(port);
            return 11;
          case 4: // EX (SP), HL
            final lo = _bus.read(regs.sp);
            final hi = _bus.read((regs.sp + 1) & 0xFFFF);
            _bus.write(regs.sp, regs.l);
            _bus.write((regs.sp + 1) & 0xFFFF, regs.h);
            regs.l = lo;
            regs.h = hi;
            return 19;
          case 5: // EX DE, HL
            final tmp = regs.de;
            regs.de = regs.hl;
            regs.hl = tmp;
            return 4;
          case 6: // DI
            regs.iff1 = false;
            regs.iff2 = false;
            return 4;
          case 7: // EI
            regs.iff1 = true;
            regs.iff2 = true;
            return 4;
        }
        return 4;
      case 4:
        // CALL cc, nn
        final addr = _fetch16();
        if (_evalCondition(y)) {
          _push16(regs.pc);
          regs.pc = addr;
          return 17;
        }
        return 10;
      case 5:
        if (q == 0) {
          // PUSH rr
          _push16(_getReg16AF(p));
          return 11;
        } else {
          switch (p) {
            case 0: // CALL nn
              final addr = _fetch16();
              _push16(regs.pc);
              regs.pc = addr;
              return 17;
            case 1: // DD prefix (IX)
              return _executeDDFD(true);
            case 2: // ED prefix
              return _executeED();
            case 3: // FD prefix (IY)
              return _executeDDFD(false);
          }
        }
        return 4;
      case 6:
        // ALU A, n
        final n = _fetch();
        _alu(y, n);
        return 7;
      case 7:
        // RST
        _push16(regs.pc);
        regs.pc = y * 8;
        return 11;
      default:
        return 4;
    }
  }

  // ── CB prefix ─────────────────────────────────────────────────────────────

  int _executeCB() {
    final cbOp = _fetch();
    final x = (cbOp >> 6) & 3;
    final y = (cbOp >> 3) & 7;
    final z = cbOp & 7;

    if (z == 6) {
      // (HL) operations
      final val = _bus.read(regs.hl);
      final result = _cbOperation(x, y, val);
      if (x != 1) {
        // BIT doesn't write back
        _bus.write(regs.hl, result);
      }
      return x == 1 ? 12 : 15;
    }

    final val = _getReg8(z);
    final result = _cbOperation(x, y, val);
    if (x != 1) {
      _setReg8(z, result);
    }
    return 8;
  }

  // ── ED prefix ─────────────────────────────────────────────────────────────

  int _executeED() {
    final edOp = _fetch();
    final x = (edOp >> 6) & 3;
    final y = (edOp >> 3) & 7;
    final z = edOp & 7;
    final p = (y >> 1) & 3;
    final q = y & 1;

    if (x == 1) {
      switch (z) {
        case 0: // IN r, (C) / IN (C) if y==6
          final val = _bus.ioRead(regs.c);
          if (y != 6) {
            _setReg8(y, val);
          }
          regs.flagS = (val & 0x80) != 0;
          regs.flagZ = val == 0;
          regs.flagH = false;
          regs.flagN = false;
          regs.flagPV = _parity(val);
          return 12;
        case 1: // OUT (C), r / OUT (C), 0 if y==6
          final val = y == 6 ? 0 : _getReg8(y);
          _bus.ioWrite(regs.c, val);
          return 12;
        case 2: // SBC HL, rr / ADC HL, rr
          if (q == 0) {
            _sbcHL(_getReg16(p));
          } else {
            _adcHL(_getReg16(p));
          }
          return 15;
        case 3: // LD (nn), rr / LD rr, (nn)
          final addr = _fetch16();
          if (q == 0) {
            _write16(addr, _getReg16(p));
          } else {
            _setReg16(p, _read16(addr));
          }
          return 20;
        case 4: // NEG
          final a = regs.a;
          regs.a = 0;
          _subA(a);
          return 8;
        case 5: // RETN / RETI
          regs.pc = _pop16();
          regs.iff1 = regs.iff2;
          return 14;
        case 6: // IM
          switch (y) {
            case 0: case 4: regs.im = 0; break;
            case 1: case 5: regs.im = 0; break;
            case 2: case 6: regs.im = 1; break;
            case 3: case 7: regs.im = 2; break;
          }
          return 8;
        case 7:
          switch (y) {
            case 0: // LD I, A
              regs.i = regs.a;
              return 9;
            case 1: // LD R, A
              regs.r = regs.a;
              return 9;
            case 2: // LD A, I
              regs.a = regs.i;
              regs.flagS = (regs.a & 0x80) != 0;
              regs.flagZ = regs.a == 0;
              regs.flagH = false;
              regs.flagN = false;
              regs.flagPV = regs.iff2;
              return 9;
            case 3: // LD A, R
              regs.a = regs.r;
              regs.flagS = (regs.a & 0x80) != 0;
              regs.flagZ = regs.a == 0;
              regs.flagH = false;
              regs.flagN = false;
              regs.flagPV = regs.iff2;
              return 9;
            case 4: // RRD
              final hl = _bus.read(regs.hl);
              final newHL = ((regs.a & 0x0F) << 4) | ((hl >> 4) & 0x0F);
              regs.a = (regs.a & 0xF0) | (hl & 0x0F);
              _bus.write(regs.hl, newHL & 0xFF);
              _setSZP(regs.a);
              regs.flagH = false;
              regs.flagN = false;
              return 18;
            case 5: // RLD
              final hl = _bus.read(regs.hl);
              final newHL = ((hl << 4) & 0xF0) | (regs.a & 0x0F);
              regs.a = (regs.a & 0xF0) | ((hl >> 4) & 0x0F);
              _bus.write(regs.hl, newHL & 0xFF);
              _setSZP(regs.a);
              regs.flagH = false;
              regs.flagN = false;
              return 18;
            case 6: return 8; // NOP
            case 7: return 8; // NOP
          }
          return 8;
      }
    } else if (x == 2 && y >= 4) {
      // Block instructions
      return _executeBlock(y, z);
    }

    // Undefined ED opcode -> NOP
    return 8;
  }

  int _executeBlock(int y, int z) {
    switch (z) {
      case 0: // LDI/LDD/LDIR/LDDR
        return _blockLD(y);
      case 1: // CPI/CPD/CPIR/CPDR
        return _blockCP(y);
      case 2: // INI/IND/INIR/INDR
        return _blockIN(y);
      case 3: // OUTI/OUTD/OTIR/OTDR
        return _blockOUT(y);
      default:
        return 8;
    }
  }

  int _blockLD(int y) {
    final inc = (y & 1) == 0 ? 1 : -1; // y=4,6: inc; y=5,7: dec
    final repeat = y >= 6;
    int cycles = 16;

    do {
      final val = _bus.read(regs.hl);
      _bus.write(regs.de, val);
      regs.hl = (regs.hl + inc) & 0xFFFF;
      regs.de = (regs.de + inc) & 0xFFFF;
      regs.bc = (regs.bc - 1) & 0xFFFF;

      regs.flagH = false;
      regs.flagN = false;
      regs.flagPV = regs.bc != 0;

      if (!repeat || regs.bc == 0) break;
      cycles += 21;
    } while (true);

    return cycles;
  }

  int _blockCP(int y) {
    final inc = (y & 1) == 0 ? 1 : -1;
    final repeat = y >= 6;
    int cycles = 16;

    do {
      final val = _bus.read(regs.hl);
      final result = (regs.a - val) & 0xFF;
      regs.hl = (regs.hl + inc) & 0xFFFF;
      regs.bc = (regs.bc - 1) & 0xFFFF;

      regs.flagS = (result & 0x80) != 0;
      regs.flagZ = result == 0;
      regs.flagH = ((regs.a ^ val ^ result) & 0x10) != 0;
      regs.flagN = true;
      regs.flagPV = regs.bc != 0;

      if (!repeat || regs.bc == 0 || regs.flagZ) break;
      cycles += 21;
    } while (true);

    return cycles;
  }

  int _blockIN(int y) {
    final inc = (y & 1) == 0 ? 1 : -1;
    final repeat = y >= 6;
    int cycles = 16;

    do {
      final val = _bus.ioRead(regs.c);
      _bus.write(regs.hl, val);
      regs.b = (regs.b - 1) & 0xFF;
      regs.hl = (regs.hl + inc) & 0xFFFF;

      regs.flagZ = regs.b == 0;
      regs.flagN = true;

      if (!repeat || regs.b == 0) break;
      cycles += 21;
    } while (true);

    return cycles;
  }

  int _blockOUT(int y) {
    final inc = (y & 1) == 0 ? 1 : -1;
    final repeat = y >= 6;
    int cycles = 16;

    do {
      final val = _bus.read(regs.hl);
      regs.b = (regs.b - 1) & 0xFF;
      _bus.ioWrite(regs.c, val);
      regs.hl = (regs.hl + inc) & 0xFFFF;

      regs.flagZ = regs.b == 0;
      regs.flagN = true;

      if (!repeat || regs.b == 0) break;
      cycles += 21;
    } while (true);

    return cycles;
  }

  // ── DD/FD prefix (IX/IY) ─────────────────────────────────────────────────

  int _executeDDFD(bool isIX) {
    final opcode = _fetch();
    final x = (opcode >> 6) & 3;
    final y = (opcode >> 3) & 7;
    final z = opcode & 7;
    final p = (y >> 1) & 3;
    final q = y & 1;

    int getIXIY() => isIX ? regs.ix : regs.iy;
    void setIXIY(int v) { if (isIX) { regs.ix = v; } else { regs.iy = v; } }
    int getIXIYH() => (getIXIY() >> 8) & 0xFF;
    int getIXIYL() => getIXIY() & 0xFF;
    void setIXIYH(int v) { setIXIY((v << 8) | (getIXIY() & 0xFF)); }
    void setIXIYL(int v) { setIXIY((getIXIY() & 0xFF00) | (v & 0xFF)); }

    // Get reg with IX/IY substitution: H->IXH, L->IXL, (HL)->(IX+d)
    int getRegIXIY(int idx, int? disp) {
      switch (idx) {
        case 4: return getIXIYH();
        case 5: return getIXIYL();
        case 6: return _bus.read((getIXIY() + (disp ?? 0)) & 0xFFFF);
        default: return _getReg8(idx);
      }
    }

    void setRegIXIY(int idx, int value, int? disp) {
      switch (idx) {
        case 4: setIXIYH(value); break;
        case 5: setIXIYL(value); break;
        case 6: _bus.write((getIXIY() + (disp ?? 0)) & 0xFFFF, value & 0xFF); break;
        default: _setReg8(idx, value); break;
      }
    }

    switch (x) {
      case 0:
        return _executeDDFDX0(y, z, p, q, isIX, getIXIY, setIXIY, getRegIXIY, setRegIXIY);
      case 1:
        // LD r, r' with IX/IY substitution
        if (y == 6 && z == 6) {
          // HALT - treat as normal
          regs.halted = true;
          return 8;
        }
        if (y == 6 || z == 6) {
          // Involves (IX+d)
          final d = _signExtend(_fetch());
          if (y == 6) {
            // LD (IX+d), r - z must not be 4 or 5 with IXH/IXL
            _bus.write((getIXIY() + d) & 0xFFFF, _getReg8(z));
          } else {
            // LD r, (IX+d)
            _setReg8(y, _bus.read((getIXIY() + d) & 0xFFFF));
          }
          return 19;
        }
        // LD with IXH/IXL substitution (undocumented)
        final src = getRegIXIY(z, null);
        setRegIXIY(y, src, null);
        return 8;
      case 2:
        // ALU A, r with IX/IY substitution
        if (z == 6) {
          final d = _signExtend(_fetch());
          _alu(y, _bus.read((getIXIY() + d) & 0xFFFF));
          return 19;
        }
        _alu(y, getRegIXIY(z, null));
        return 8;
      case 3:
        return _executeDDFDX3(y, z, p, q, opcode, isIX, getIXIY, setIXIY);
      default:
        return 8;
    }
  }

  int _executeDDFDX0(int y, int z, int p, int q, bool isIX,
      int Function() getIXIY, void Function(int) setIXIY,
      int Function(int, int?) getRegIXIY, void Function(int, int, int?) setRegIXIY) {
    switch (z) {
      case 1:
        if (q == 0) {
          if (p == 2) {
            // LD IX, nn
            setIXIY(_fetch16());
            return 14;
          }
          // Other LD rr, nn - normal
          _setReg16(p, _fetch16());
          return 14;
        } else {
          if (p == 2) {
            // ADD IX, rr
            final rr = _getReg16DDFD(p, isIX);
            setIXIY(_addIXIY(getIXIY(), rr));
            return 15;
          }
          // ADD IX, rr
          final rr = p == 2 ? getIXIY() : _getReg16(p);
          setIXIY(_addIXIY(getIXIY(), rr));
          return 15;
        }
      case 2:
        if (q == 0) {
          if (p == 2) {
            // LD (nn), IX
            final addr = _fetch16();
            _write16(addr, getIXIY());
            return 20;
          }
        } else {
          if (p == 2) {
            // LD IX, (nn)
            final addr = _fetch16();
            setIXIY(_read16(addr));
            return 20;
          }
        }
        // Fall through to normal behavior
        return _executeX0(y, z, p, q, 0) + 4;
      case 3:
        if (p == 2) {
          if (q == 0) {
            // INC IX
            setIXIY((getIXIY() + 1) & 0xFFFF);
            return 10;
          } else {
            // DEC IX
            setIXIY((getIXIY() - 1) & 0xFFFF);
            return 10;
          }
        }
        return _executeX0(y, z, p, q, 0) + 4;
      case 4:
        // INC r (with IX/IY sub)
        if (y == 6) {
          final d = _signExtend(_fetch());
          final addr = (getIXIY() + d) & 0xFFFF;
          _bus.write(addr, _incFlags(_bus.read(addr)));
          return 23;
        }
        if (y == 4 || y == 5) {
          setRegIXIY(y, _incFlags(getRegIXIY(y, null)), null);
          return 8;
        }
        _setReg8(y, _incFlags(_getReg8(y)));
        return 8;
      case 5:
        // DEC r (with IX/IY sub)
        if (y == 6) {
          final d = _signExtend(_fetch());
          final addr = (getIXIY() + d) & 0xFFFF;
          _bus.write(addr, _decFlags(_bus.read(addr)));
          return 23;
        }
        if (y == 4 || y == 5) {
          setRegIXIY(y, _decFlags(getRegIXIY(y, null)), null);
          return 8;
        }
        _setReg8(y, _decFlags(_getReg8(y)));
        return 8;
      case 6:
        // LD r, n (with IX/IY sub)
        if (y == 6) {
          final d = _signExtend(_fetch());
          final n = _fetch();
          _bus.write((getIXIY() + d) & 0xFFFF, n);
          return 19;
        }
        if (y == 4 || y == 5) {
          setRegIXIY(y, _fetch(), null);
          return 11;
        }
        _setReg8(y, _fetch());
        return 11;
      default:
        // For z=0 and z=7, just execute normally with +4 cycles
        return _executeX0(y, z, p, q, 0) + 4;
    }
  }

  int _getReg16DDFD(int p, bool isIX) {
    switch (p) {
      case 0: return regs.bc;
      case 1: return regs.de;
      case 2: return isIX ? regs.ix : regs.iy;
      case 3: return regs.sp;
      default: return 0;
    }
  }

  int _executeDDFDX3(int y, int z, int p, int q, int opcode, bool isIX,
      int Function() getIXIY, void Function(int) setIXIY) {
    switch (z) {
      case 1:
        if (q == 1) {
          if (p == 2) {
            // JP (IX)
            regs.pc = getIXIY();
            return 8;
          }
          if (p == 3) {
            // LD SP, IX
            regs.sp = getIXIY();
            return 10;
          }
        }
        if (q == 0 && p == 2) {
          // POP IX
          setIXIY(_pop16());
          return 14;
        }
        return _executeX3(y, z, p, q, opcode) + 4;
      case 3:
        if (y == 1) {
          // DDCB / FDCB prefix
          return _executeDDFDCB(isIX);
        }
        if (y == 4) {
          // EX (SP), IX
          final lo = _bus.read(regs.sp);
          final hi = _bus.read((regs.sp + 1) & 0xFFFF);
          final ixiy = getIXIY();
          _bus.write(regs.sp, ixiy & 0xFF);
          _bus.write((regs.sp + 1) & 0xFFFF, (ixiy >> 8) & 0xFF);
          setIXIY((hi << 8) | lo);
          return 23;
        }
        return _executeX3(y, z, p, q, opcode) + 4;
      case 5:
        if (q == 0 && p == 2) {
          // PUSH IX
          _push16(getIXIY());
          return 15;
        }
        return _executeX3(y, z, p, q, opcode) + 4;
      default:
        return _executeX3(y, z, p, q, opcode) + 4;
    }
  }

  // ── DDCB / FDCB prefix ───────────────────────────────────────────────────

  int _executeDDFDCB(bool isIX) {
    final d = _signExtend(_fetch());
    final cbOp = _fetch();
    final x = (cbOp >> 6) & 3;
    final y = (cbOp >> 3) & 7;
    final z = cbOp & 7;

    final addr = ((isIX ? regs.ix : regs.iy) + d) & 0xFFFF;
    final val = _bus.read(addr);

    final result = _cbOperation(x, y, val);

    if (x == 1) {
      // BIT: don't write back, don't store in register
      return 20;
    }

    // Write result back to memory
    _bus.write(addr, result);

    // Also store in register if z != 6
    if (z != 6) {
      _setReg8(z, result);
    }

    return 23;
  }
}
