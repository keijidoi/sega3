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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _buildDPad())),
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _buildActionButtons())),
        ],
      ),
    );
  }

  Widget _buildDPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _padButton(EmulatorButton.up, Icons.arrow_drop_up, 52),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _padButton(EmulatorButton.left, Icons.arrow_left, 52),
            const SizedBox(width: 44, height: 44),
            _padButton(EmulatorButton.right, Icons.arrow_right, 52),
          ],
        ),
        _padButton(EmulatorButton.down, Icons.arrow_drop_down, 52),
      ],
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
