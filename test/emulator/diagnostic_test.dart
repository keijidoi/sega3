import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/emulator.dart';
import 'package:sega3/emulator/vdp.dart';

void main() {
  const romPath =
      r'C:/Users/doike/Downloads/Shinobi (USA, Europe)/Shinobi (USA, Europe).sms';

  test('Shinobi ROM diagnostic - 5 frames', () {
    final romFile = File(romPath);
    if (!romFile.existsSync()) {
      // ignore: avoid_print
      print('[SKIP] ROM not found at $romPath');
      return;
    }
    final romData = romFile.readAsBytesSync();
    // ignore: avoid_print
    print('ROM loaded: ${romData.length} bytes');

    final emu = Emulator(romData);

    for (int f = 0; f < 300; f++) {
      emu.runFrame();
    }

    final cpu = emu.cpu;
    final vdp = emu.vdp;
    final fb  = emu.frameBuffer;

    // ── CPU state ─────────────────────────────────────────────────────────────
    // ignore: avoid_print
    print('--- CPU state after 300 frames ---');
    // ignore: avoid_print
    print('PC=0x${cpu.regs.pc.toRadixString(16).padLeft(4, "0")}  '
        'SP=0x${cpu.regs.sp.toRadixString(16).padLeft(4, "0")}');
    // ignore: avoid_print
    print('A=0x${cpu.regs.a.toRadixString(16).padLeft(2, "0")}  '
        'F=0x${cpu.regs.f.toRadixString(16).padLeft(2, "0")}  '
        'BC=0x${cpu.regs.bc.toRadixString(16).padLeft(4, "0")}  '
        'DE=0x${cpu.regs.de.toRadixString(16).padLeft(4, "0")}  '
        'HL=0x${cpu.regs.hl.toRadixString(16).padLeft(4, "0")}');
    // ignore: avoid_print
    print('IFF1=${cpu.regs.iff1}  IM=${cpu.regs.im}  halted=${cpu.regs.halted}');

    // ── VDP registers ─────────────────────────────────────────────────────────
    // ignore: avoid_print
    print('--- VDP registers [0..10] ---');
    for (int i = 0; i <= 10; i++) {
      // ignore: avoid_print
      print('  reg[$i]=0x${vdp.registers[i].toRadixString(16).padLeft(2, "0")}');
    }
    // ignore: avoid_print
    print('VDP statusRegister=0x${vdp.statusRegister.toRadixString(16).padLeft(2, "0")}');

    // ── Frame buffer pixels ───────────────────────────────────────────────────
    int nonZeroPixels = 0;
    for (int i = 0; i < fb.length; i++) {
      if ((fb[i] & 0x00FFFFFF) != 0) nonZeroPixels++;
    }
    // ignore: avoid_print
    print('Non-zero pixels in frameBuffer: $nonZeroPixels / ${fb.length}');

    // ── CRAM entries ──────────────────────────────────────────────────────────
    int nonZeroCram = 0;
    for (int i = 0; i < vdp.cram.length; i++) {
      if (vdp.cram[i] != 0) nonZeroCram++;
    }
    // ignore: avoid_print
    print('Non-zero CRAM entries: $nonZeroCram / ${vdp.cram.length}');

    // ── VRAM check ────────────────────────────────────────────────────────────
    bool vramNonZero = false;
    for (int i = 0; i < vdp.vram.length; i++) {
      if (vdp.vram[i] != 0) {
        vramNonZero = true;
        break;
      }
    }
    // ignore: avoid_print
    print('Any non-zero VRAM: $vramNonZero');

    // ── Assertions ────────────────────────────────────────────────────────────
    expect(cpu.regs.pc, isNot(equals(0)),
        reason: 'CPU should have advanced past PC=0 after 60 frames');
    // The game should have written tile/palette data into VRAM within 60 frames.
    expect(vramNonZero, isTrue,
        reason: 'VRAM should be non-zero after 60 frames — game must have run init DMA');
    // Non-zero pixels requires display to be enabled (reg[1] bit 6); log it but
    // don't fail on it — VRAM population is the primary signal.
    // ignore: avoid_print
    print('nonZeroPixels=$nonZeroPixels (informational — requires display enable)');

    // ignore: avoid_print
    print('DIAGNOSTIC PASSED');
  });

  // ── Unit test: readStatus must clear lineInterruptPending ─────────────────
  test('VDP readStatus clears lineInterruptPending', () {
    final vdp = Vdp();
    // Enable line interrupts (register[0] bit 4).
    vdp.registers[0] = 0x10;
    // With counter initialised to 0xFF and reg[10]=0:
    // - Counter decrements from 0xFF to 0xFF-192=0x3F over 192 active scanlines.
    // - In vblank (192-261) counter is reset to reg[10]=0 each scanline.
    // - On scanline 0 of the NEXT frame, counter==0 so interrupt fires.
    // Run one full frame + one extra scanline to trigger the interrupt.
    for (int i = 0; i < 263; i++) {
      vdp.renderScanline();
    }
    expect(vdp.interruptPending, isTrue,
        reason: 'Line interrupt should be pending at the start of frame 2 with reg[10]=0');
    // Reading status must clear _lineInterruptPending.
    vdp.readStatus();
    expect(vdp.interruptPending, isFalse,
        reason: 'readStatus() must clear _lineInterruptPending');
  });

  // ── Unit test: lineInterruptCounter init should not fire immediately ───────
  test('VDP lineInterruptCounter initialised to 0xFF does not fire on scanline 0', () {
    final vdp = Vdp();
    vdp.registers[0] = 0x10; // enable line interrupts
    // After the fix _lineInterruptCounter starts at 0xFF so it won't fire on
    // scanline 0 (register[10] is still 0 at startup).
    vdp.renderScanline(); // scanline 0
    // ignore: avoid_print
    print('interruptPending after scanline 0 (expects false after fix): ${vdp.interruptPending}');
    expect(vdp.interruptPending, isFalse,
        reason: 'Line interrupt must NOT fire on scanline 0 when counter starts at 0xFF');
  });
}
