import 'package:sega3/emulator/vdp.dart';
import 'package:sega3/emulator/psg.dart';

enum Button { up, down, left, right, button1, button2, start }

class IoPorts {
  final Vdp vdp;
  final Psg psg;

  int _controller1 = 0xFF;
  int _controller2 = 0xFF;
  int _nationalization = 0xFF;

  IoPorts({required this.vdp, required this.psg});

  int read(int port) {
    port &= 0xFF;

    if (port <= 0x3F) {
      if (port & 1 == 0) return 0xFF;
      return _nationalization;
    }

    if (port >= 0x40 && port <= 0x7F) {
      if (port & 1 == 0) return vdp.vCounter;
      return vdp.hCounter;
    }

    if (port >= 0x80 && port <= 0xBF) {
      if (port & 1 == 0) return vdp.readData();
      return vdp.readStatus();
    }

    if (port >= 0xC0) {
      if (port & 1 == 0) return _controller1;
      return _controller2;
    }

    return 0xFF;
  }

  void write(int port, int value) {
    port &= 0xFF;
    value &= 0xFF;

    if (port <= 0x3F) {
      if (port & 1 == 0) {
        // Memory control - ignored
      } else {
        _nationalization = value;
      }
      return;
    }

    if (port >= 0x40 && port <= 0x7F) {
      psg.write(value);
      return;
    }

    if (port >= 0x80 && port <= 0xBF) {
      if (port & 1 == 0) {
        vdp.writeData(value);
      } else {
        vdp.writeControl(value);
      }
      return;
    }
  }

  void pressButton(Button button) {
    switch (button) {
      case Button.up:      _controller1 &= ~0x01; break;
      case Button.down:    _controller1 &= ~0x02; break;
      case Button.left:    _controller1 &= ~0x04; break;
      case Button.right:   _controller1 &= ~0x08; break;
      case Button.button1: _controller1 &= ~0x10; break;
      case Button.button2: _controller1 &= ~0x20; break;
      case Button.start:   break;
    }
  }

  void releaseButton(Button button) {
    switch (button) {
      case Button.up:      _controller1 |= 0x01; break;
      case Button.down:    _controller1 |= 0x02; break;
      case Button.left:    _controller1 |= 0x04; break;
      case Button.right:   _controller1 |= 0x08; break;
      case Button.button1: _controller1 |= 0x10; break;
      case Button.button2: _controller1 |= 0x20; break;
      case Button.start:   break;
    }
  }

  void reset() {
    _controller1 = 0xFF;
    _controller2 = 0xFF;
  }
}
