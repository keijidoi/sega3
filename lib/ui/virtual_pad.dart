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
          _buildDPad(),
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
