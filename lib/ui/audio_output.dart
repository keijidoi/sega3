import 'dart:typed_data';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

class AudioOutput {
  bool _initialized = false;

  static const int sampleRate = 44100;

  Future<void> init() async {
    if (_initialized) return;
    await FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
    await FlutterPcmSound.setFeedThreshold(4410);
    _initialized = true;
  }

  void feed(Float64List samples) {
    if (!_initialized) return;

    // Convert Float64 (-1..1) to Int16 PCM
    final pcm = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      double s = samples[i].clamp(-1.0, 1.0);
      pcm[i] = (s * 32767).toInt();
    }

    FlutterPcmSound.feed(PcmArrayInt16(bytes: pcm.buffer.asByteData()));
  }

  Future<void> dispose() async {
    if (_initialized) {
      await FlutterPcmSound.release();
      _initialized = false;
    }
  }
}
