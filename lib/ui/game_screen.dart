import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sega3/emulator/emulator.dart';
import 'package:sega3/ui/screen_painter.dart';
import 'package:sega3/ui/virtual_pad.dart';
import 'package:sega3/ui/audio_output.dart';
import 'package:sega3/emulator/save_state.dart';

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
  final AudioOutput _audio = AudioOutput();
  bool _paused = false;
  String get _romName => 'rom_${widget.romData.length}';

  @override
  void initState() {
    super.initState();
    _emulator = Emulator(widget.romData);
    _emulator.addListener(_onFrame);
    _audio.init();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!_paused) {
      _emulator.runFrame();
      final samples = _emulator.audioSamples;
      if (samples != null) {
        _audio.feed(samples);
      }
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
    _audio.dispose();
    super.dispose();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  void _showSaveLoadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _SaveLoadDialog(
        romName: _romName,
        onSave: (slot) async {
          final state = _emulator.saveState();
          await SaveStateManager.saveToSlot(_romName, slot, state);
        },
        onLoad: (slot) async {
          final state = await SaveStateManager.loadFromSlot(_romName, slot);
          if (state != null) {
            _emulator.loadState(state);
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
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
                  onPressed: _showSaveLoadDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              flex: 3,
              child: Center(
                child: EmulatorDisplay(frameBuffer: _emulator.frameBuffer),
              ),
            ),
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

class _SaveLoadDialog extends StatefulWidget {
  final String romName;
  final Future<void> Function(int slot) onSave;
  final Future<void> Function(int slot) onLoad;

  const _SaveLoadDialog({
    required this.romName,
    required this.onSave,
    required this.onLoad,
  });

  @override
  State<_SaveLoadDialog> createState() => _SaveLoadDialogState();
}

class _SaveLoadDialogState extends State<_SaveLoadDialog> {
  List<bool> _slotStatus = [false, false, false];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await SaveStateManager.getSlotStatus(widget.romName);
    if (mounted) setState(() { _slotStatus = status; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('セーブ / ロード'),
      content: _loading
        ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
        : Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (slot) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _slotStatus[slot] ? Icons.save : Icons.save_outlined,
                    color: _slotStatus[slot] ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text('スロット ${slot + 1}'),
                  if (_slotStatus[slot])
                    const Text(' (データあり)',
                      style: TextStyle(fontSize: 12, color: Colors.green)),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      await widget.onSave(slot);
                      if (mounted) await _loadStatus();
                    },
                    child: const Text('セーブ'),
                  ),
                  TextButton(
                    onPressed: _slotStatus[slot] ? () => widget.onLoad(slot) : null,
                    child: const Text('ロード'),
                  ),
                ],
              ),
            ],
          ),
        )),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
