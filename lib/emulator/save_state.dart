import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class SaveStateManager {
  static const int maxSlots = 3;

  static Future<Directory> _getSaveDir(String romName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${appDir.path}/sega3_saves/$romName');
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
    return saveDir;
  }

  static Future<void> saveToSlot(String romName, int slot, Uint8List stateData) async {
    if (slot < 0 || slot >= maxSlots) return;
    final dir = await _getSaveDir(romName);
    final file = File('${dir.path}/state_$slot.sav');
    await file.writeAsBytes(stateData);
  }

  static Future<Uint8List?> loadFromSlot(String romName, int slot) async {
    if (slot < 0 || slot >= maxSlots) return null;
    final dir = await _getSaveDir(romName);
    final file = File('${dir.path}/state_$slot.sav');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  static Future<List<bool>> getSlotStatus(String romName) async {
    final dir = await _getSaveDir(romName);
    final status = <bool>[];
    for (int i = 0; i < maxSlots; i++) {
      final file = File('${dir.path}/state_$i.sav');
      status.add(await file.exists());
    }
    return status;
  }

  static Future<void> saveBatteryRam(String romName, Uint8List ram) async {
    final dir = await _getSaveDir(romName);
    final file = File('${dir.path}/battery.sram');
    await file.writeAsBytes(ram);
  }

  static Future<Uint8List?> loadBatteryRam(String romName) async {
    final dir = await _getSaveDir(romName);
    final file = File('${dir.path}/battery.sram');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }
}
