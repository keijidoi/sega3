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

  // Internal counters - use fractional accumulators (Amendment D)
  double _toneAccum0 = 0, _toneAccum1 = 0, _toneAccum2 = 0;
  double _noiseAccum = 0;

  // Tone output flip-flops (+1 or -1)
  final List<int> _toneOutput = [1, 1, 1];
  int _noiseOutput = 1;

  // Latch state
  int _latchedChannel = 0;
  bool _latchedVolume = false;

  // Clock rate and sample rate
  static const int _clockRate = 3546895;
  static const int _clockDivider = 16;
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
    final accums = [_toneAccum0, _toneAccum1, _toneAccum2];

    for (int i = 0; i < count; i++) {
      double sample = 0;

      // Update tone channels using fractional accumulators (Amendment D)
      for (int ch = 0; ch < 3; ch++) {
        accums[ch] += cyclesPerSample;
        int period = toneRegisters[ch];
        if (period == 0 || period == 1) {
          _toneOutput[ch] = 1;
        } else {
          while (accums[ch] >= period) {
            _toneOutput[ch] = -_toneOutput[ch];
            accums[ch] -= period;
          }
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
      _noiseAccum += cyclesPerSample;
      int noisePeriod = (noiseRate == 0) ? 1 : noiseRate;
      while (_noiseAccum >= noisePeriod) {
        // Shift LFSR
        int feedback;
        if (noiseMode == 1) {
          // White noise: bit0 XOR bit3 (Sega-specific taps)
          feedback = (_lfsr & 1) ^ ((_lfsr >> 3) & 1);
        } else {
          // Periodic: bit0
          feedback = _lfsr & 1;
        }
        _lfsr = (_lfsr >> 1) | (feedback << 15);
        _noiseOutput = (_lfsr & 1) != 0 ? 1 : -1;
        _noiseAccum -= noisePeriod;
      }
      sample += _noiseOutput * _volumeTable[volumes[3]];

      output[i] = sample / 4.0; // Mix 4 channels, normalize
    }

    _toneAccum0 = accums[0];
    _toneAccum1 = accums[1];
    _toneAccum2 = accums[2];

    return output;
  }

  void reset() {
    for (int i = 0; i < 3; i++) {
      toneRegisters[i] = 0;
      _toneOutput[i] = 1;
    }
    _toneAccum0 = _toneAccum1 = _toneAccum2 = _noiseAccum = 0;
    volumes.fillRange(0, 4, 0x0F);
    _noiseRegister = 0;
    _noiseOutput = 1;
    _lfsr = 0x8000;
  }
}
