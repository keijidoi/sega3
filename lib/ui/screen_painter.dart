import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class EmulatorDisplay extends StatefulWidget {
  final Uint32List frameBuffer;
  final VoidCallback? onFrameReady;

  const EmulatorDisplay({
    super.key,
    required this.frameBuffer,
    this.onFrameReady,
  });

  @override
  State<EmulatorDisplay> createState() => _EmulatorDisplayState();
}

class _EmulatorDisplayState extends State<EmulatorDisplay> {
  ui.Image? _image;

  @override
  void didUpdateWidget(EmulatorDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateImage();
  }

  @override
  void initState() {
    super.initState();
    _updateImage();
  }

  void _updateImage() {
    final pixels = widget.frameBuffer.buffer.asUint8List();
    ui.decodeImageFromPixels(
      pixels,
      256,
      192,
      ui.PixelFormat.bgra8888,
      (ui.Image img) {
        if (mounted) {
          setState(() {
            _image?.dispose();
            _image = img;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 256 / 192,
      child: CustomPaint(
        painter: _ImagePainter(image: _image),
        size: Size.infinite,
      ),
    );
  }
}

class _ImagePainter extends CustomPainter {
  final ui.Image? image;
  _ImagePainter({this.image});

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = Colors.black);
      return;
    }
    final src = Rect.fromLTWH(0, 0, 256, 192);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image!, src, dst, Paint()
      ..filterQuality = FilterQuality.low);
  }

  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image;
}
