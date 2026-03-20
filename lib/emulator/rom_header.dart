import 'dart:typed_data';

enum MapperType { none, sega, codemasters }

class RomHeader {
  final MapperType mapperType;
  final bool hasCopierHeader;
  final int romSizeBytes;

  RomHeader({
    required this.mapperType,
    required this.hasCopierHeader,
    required this.romSizeBytes,
  });

  static RomHeader parse(Uint8List data) {
    bool copierHeader = (data.length % 1024) == 512;
    int offset = copierHeader ? 512 : 0;
    int romSize = data.length - offset;

    // Amendment H: ROM validation — minimum 16KB, maximum 4MB
    if (romSize < 16 * 1024) {
      throw ArgumentError(
        'ROM size $romSize bytes is below the minimum of ${16 * 1024} bytes (16KB).',
      );
    }
    if (romSize > 4 * 1024 * 1024) {
      throw ArgumentError(
        'ROM size $romSize bytes exceeds the maximum of ${4 * 1024 * 1024} bytes (4MB).',
      );
    }

    // Check for TMR SEGA magic at standard offsets
    bool hasMagic = _checkMagic(data, offset + 0x7FF0) ||
                    _checkMagic(data, offset + 0x3FF0) ||
                    _checkMagic(data, offset + 0x1FF0);

    MapperType mapper;
    if (romSize <= 48 * 1024) {
      mapper = MapperType.none;
    } else if (hasMagic) {
      mapper = MapperType.sega;
    } else {
      // No TMR SEGA header + large ROM = likely Codemasters
      mapper = MapperType.codemasters;
    }

    return RomHeader(
      mapperType: mapper,
      hasCopierHeader: copierHeader,
      romSizeBytes: romSize,
    );
  }

  static bool _checkMagic(Uint8List data, int offset) {
    if (offset + 8 > data.length) return false;
    const magic = [0x54, 0x4D, 0x52, 0x20, 0x53, 0x45, 0x47, 0x41]; // TMR SEGA
    for (int i = 0; i < 8; i++) {
      if (data[offset + i] != magic[i]) return false;
    }
    return true;
  }

  /// Strip copier header if present and return clean ROM data
  Uint8List cleanRom(Uint8List data) {
    if (hasCopierHeader) {
      return Uint8List.sublistView(data, 512);
    }
    return data;
  }
}
