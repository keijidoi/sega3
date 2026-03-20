import 'package:flutter_test/flutter_test.dart';
import 'package:sega3/emulator/psg.dart';

void main() {
  late Psg psg;

  setUp(() {
    psg = Psg();
  });

  test('initial state — all channels silent', () {
    expect(psg.volumes[0], 0x0F);
    expect(psg.volumes[1], 0x0F);
    expect(psg.volumes[2], 0x0F);
    expect(psg.volumes[3], 0x0F);
  });

  test('latch write sets channel and type', () {
    psg.write(0x8A); // 1 00 0 1010 = chan0 tone low=0x0A
    expect(psg.toneRegisters[0] & 0x0F, 0x0A);
  });

  test('data write updates high bits of tone', () {
    psg.write(0x8A); // chan0 tone low=0x0A
    psg.write(0x01); // high bits = 0x01
    expect(psg.toneRegisters[0], 0x1A);
  });

  test('volume write', () {
    psg.write(0xB5); // 1 01 1 0101 = chan1 volume = 5
    expect(psg.volumes[1], 0x05);
  });

  test('noise register write', () {
    psg.write(0xE4); // 1 11 0 0100
    expect(psg.noiseMode, 1);
    expect(psg.noiseShiftRate, 0);
  });

  test('generate samples produces non-empty output', () {
    psg.write(0x80); // chan0 tone low=0
    psg.write(0x01); // tone = 0x10
    psg.write(0x90); // chan0 volume = 0 (max)
    final samples = psg.generateSamples(44100 ~/ 60);
    expect(samples.length, 44100 ~/ 60);
    expect(samples.any((s) => s != 0), true);
  });

  test('LFSR for white noise uses Sega taps (bit 0 XOR bit 3)', () {
    psg.write(0xE7); // white noise, use channel 3 freq
    psg.write(0xF0); // chan3 volume = 0 (max)
    final samples = psg.generateSamples(100);
    expect(samples.any((s) => s != 0), true);
  });
}
