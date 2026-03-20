/// Z80 register file for the Sega Master System emulator.
///
/// Models all Z80 registers including shadow (alternate) registers,
/// index registers, special registers, interrupt state, and flag accessors.
class Z80Registers {
  // ── 8-bit main registers ──────────────────────────────────────────────────
  int _a = 0, _f = 0;
  int _b = 0, _c = 0;
  int _d = 0, _e = 0;
  int _h = 0, _l = 0;

  // ── 8-bit shadow (alternate) registers ───────────────────────────────────
  int _a2 = 0, _f2 = 0;
  int _b2 = 0, _c2 = 0;
  int _d2 = 0, _e2 = 0;
  int _h2 = 0, _l2 = 0;

  // ── 16-bit index / special registers ─────────────────────────────────────
  int _ix = 0, _iy = 0;
  int _pc = 0, _sp = 0;

  // ── 8-bit special registers ───────────────────────────────────────────────
  int _i = 0, _r = 0;

  // ── Interrupt / halt state ────────────────────────────────────────────────
  bool iff1 = false;
  bool iff2 = false;
  int im = 0;
  bool halted = false;

  // ── 8-bit register accessors (masked to 0xFF) ─────────────────────────────
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

  // ── 16-bit register pair accessors (masked to 0xFFFF) ────────────────────
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

  // ── Index registers (16-bit, masked to 0xFFFF) ───────────────────────────
  int get ix => _ix;
  set ix(int v) => _ix = v & 0xFFFF;

  int get iy => _iy;
  set iy(int v) => _iy = v & 0xFFFF;

  // ── Program counter / stack pointer ──────────────────────────────────────
  int get pc => _pc;
  set pc(int v) => _pc = v & 0xFFFF;

  int get sp => _sp;
  set sp(int v) => _sp = v & 0xFFFF;

  // ── Flag accessors ────────────────────────────────────────────────────────
  // F register bit layout: S Z - H - PV N C
  //                        7 6   4    2  1 0

  /// Carry flag (bit 0)
  bool get flagC => (_f & 0x01) != 0;
  set flagC(bool v) => _f = v ? (_f | 0x01) : (_f & ~0x01 & 0xFF);

  /// Subtract flag (bit 1)
  bool get flagN => (_f & 0x02) != 0;
  set flagN(bool v) => _f = v ? (_f | 0x02) : (_f & ~0x02 & 0xFF);

  /// Parity/Overflow flag (bit 2)
  bool get flagPV => (_f & 0x04) != 0;
  set flagPV(bool v) => _f = v ? (_f | 0x04) : (_f & ~0x04 & 0xFF);

  /// Half-carry flag (bit 4)
  bool get flagH => (_f & 0x10) != 0;
  set flagH(bool v) => _f = v ? (_f | 0x10) : (_f & ~0x10 & 0xFF);

  /// Zero flag (bit 6)
  bool get flagZ => (_f & 0x40) != 0;
  set flagZ(bool v) => _f = v ? (_f | 0x40) : (_f & ~0x40 & 0xFF);

  /// Sign flag (bit 7)
  bool get flagS => (_f & 0x80) != 0;
  set flagS(bool v) => _f = v ? (_f | 0x80) : (_f & ~0x80 & 0xFF);

  // ── Exchange operations ───────────────────────────────────────────────────

  /// EX AF, AF' — swap AF with shadow AF
  void exAF() {
    final tmpA = _a, tmpF = _f;
    _a = _a2; _f = _f2;
    _a2 = tmpA; _f2 = tmpF;
  }

  /// EXX — swap BC/DE/HL with their shadow counterparts
  void exx() {
    int tmp;
    tmp = _b; _b = _b2; _b2 = tmp;
    tmp = _c; _c = _c2; _c2 = tmp;
    tmp = _d; _d = _d2; _d2 = tmp;
    tmp = _e; _e = _e2; _e2 = tmp;
    tmp = _h; _h = _h2; _h2 = tmp;
    tmp = _l; _l = _l2; _l2 = tmp;
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  /// Reset all registers and state to zero / false.
  void reset() {
    _a = _f = _b = _c = _d = _e = _h = _l = 0;
    _a2 = _f2 = _b2 = _c2 = _d2 = _e2 = _h2 = _l2 = 0;
    _ix = _iy = _pc = _sp = 0;
    _i = _r = 0;
    iff1 = iff2 = false;
    im = 0;
    halted = false;
  }
}
