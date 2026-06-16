import 'package:shared_preferences/shared_preferences.dart';
import 'ble_service.dart';

class ActiveDeviceService {
  ActiveDeviceService._();
  static final ActiveDeviceService instance = ActiveDeviceService._();

  static const _kActiveDeviceId = 'active_device_id';
  static const _kActiveDeviceName = 'active_device_name';
  static const _kActiveBleId = 'active_ble_id';
  static const _kActiveBleName = 'active_ble_name';

  Future<void> setActiveDevice({
    required String deviceId,
    String? deviceName,
    String? bleId,
    String? bleName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveDeviceId, deviceId);

    final name = deviceName?.trim();
    if (name != null && name.isNotEmpty) {
      await prefs.setString(_kActiveDeviceName, name);
    } else {
      await prefs.remove(_kActiveDeviceName);
    }

    if (bleId != null) {
      await prefs.setString(_kActiveBleId, bleId);
      // Automatically attempt to connect to the new ESP32
      await BleService.instance.ensureConnected(bleId);
    } else {
      await prefs.remove(_kActiveBleId);
      await BleService.instance.disconnect();
    }

    if (bleName != null) {
      await prefs.setString(_kActiveBleName, bleName);
    } else {
      await prefs.remove(_kActiveBleName);
    }
  }

  Future<String?> getActiveDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveDeviceId);
  }

  Future<String?> getActiveDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveDeviceName);
  }

  Future<String?> getActiveBleId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveBleId);
  }

  Future<String?> getActiveBleName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveBleName);
  }
}
