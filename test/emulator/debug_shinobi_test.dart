import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/emulator.dart';

void main() {
  const romPath =
      r'C:/Users/doike/Downloads/Shinobi (USA, Europe)/Shinobi (USA, Europe).sms';

  test('Shinobi deep diagnostic - 600 frames', () {
    final romFile = File(romPath);
    if (!romFile.existsSync()) {
      print('[SKIP] ROM not found at $romPath');
      return;
    }
    final romData = romFile.readAsBytesSync();
    print('ROM loaded: ${romData.length} bytes');

    final emu = Emulator(romData);
    final cpu = emu.cpu;
    final vdp = emu.vdp;
    final fb = emu.frameBuffer;

    for (int frame = 1; frame <= 600; frame++) {
      emu.runFrame();

      if (frame % 100 == 0) {
        print('\n========== FRAME $frame ==========');

        // CPU state
        print('CPU: PC=0x${cpu.regs.pc.toRadixString(16).padLeft(4, "0")}  '
            'SP=0x${cpu.regs.sp.toRadixString(16).padLeft(4, "0")}  '
            'AF=0x${cpu.regs.af.toRadixString(16).padLeft(4, "0")}');
        print('     IFF1=${cpu.regs.iff1}  IM=${cpu.regs.im}  halted=${cpu.regs.halted}');

        // VDP registers 0-10
        final regStr = StringBuffer('VDP regs: ');
        for (int i = 0; i <= 10; i++) {
          regStr.write('R$i=0x${vdp.registers[i].toRadixString(16).padLeft(2, "0")} ');
        }
        print(regStr);

        // CRAM first 32 bytes
        int nonZeroCram = 0;
        final cramStr = StringBuffer('CRAM[0..31]: ');
        for (int i = 0; i < 32; i++) {
          if (vdp.cram[i] != 0) nonZeroCram++;
          cramStr.write('${vdp.cram[i].toRadixString(16).padLeft(2, "0")} ');
        }
        print(cramStr);
        print('Non-zero CRAM entries: $nonZeroCram / 32');

        // Non-zero pixels
        int nonZeroPixels = 0;
        for (int i = 0; i < fb.length; i++) {
          if ((fb[i] & 0x00FFFFFF) != 0) nonZeroPixels++;
        }
        print('Non-zero pixels in frameBuffer: $nonZeroPixels / ${fb.length}');

        // VRAM first 8KB non-zero count
        int vramNonZero = 0;
        for (int i = 0; i < 8192; i++) {
          if (vdp.vram[i] != 0) vramNonZero++;
        }
        print('Non-zero bytes in VRAM[0..8191]: $vramNonZero / 8192');

        // Frame 600: extra dumps
        if (frame == 600) {
          print('\n--- FRAME 600 DETAILED DUMP ---');

          // First 64 bytes of VRAM
          final vramStr = StringBuffer('VRAM[0..63]: ');
          for (int i = 0; i < 64; i++) {
            vramStr.write('${vdp.vram[i].toRadixString(16).padLeft(2, "0")} ');
            if ((i + 1) % 16 == 0) {
              print(vramStr);
              vramStr.clear();
              if (i < 63) vramStr.write('VRAM[${i + 1}..${i + 16 > 63 ? 63 : i + 16}]: ');
            }
          }

          // All 32 CRAM entries
          final cramFull = StringBuffer('All CRAM: ');
          for (int i = 0; i < 32; i++) {
            cramFull.write('${vdp.cram[i].toRadixString(16).padLeft(2, "0")} ');
          }
          print(cramFull);

          // FrameBuffer pixels at y=96, x=120-135
          print('FrameBuffer y=96 x=120..135:');
          final pixStr = StringBuffer();
          for (int x = 120; x <= 135; x++) {
            final pixel = fb[96 * 256 + x];
            pixStr.write('  [$x]=0x${pixel.toRadixString(16).padLeft(8, "0")}');
          }
          print(pixStr);

          // Also check a few more rows
          for (int y in [0, 48, 96, 144, 191]) {
            int rowNonZero = 0;
            for (int x = 0; x < 256; x++) {
              if ((fb[y * 256 + x] & 0x00FFFFFF) != 0) rowNonZero++;
            }
            print('  Row y=$y: $rowNonZero/256 non-zero pixels');
          }

          // Check total VRAM non-zero
          int totalVramNonZero = 0;
          for (int i = 0; i < vdp.vram.length; i++) {
            if (vdp.vram[i] != 0) totalVramNonZero++;
          }
          print('Total VRAM non-zero: $totalVramNonZero / ${vdp.vram.length}');

          // VDP status
          print('VDP statusRegister=0x${vdp.statusRegister.toRadixString(16).padLeft(2, "0")}');
        }
      }
    }

    print('\n========== DIAGNOSTIC COMPLETE ==========');
  });
}
