abstract class Bus {
  int read(int address);
  void write(int address, int value);
  int ioRead(int port);
  void ioWrite(int port, int value);
}
