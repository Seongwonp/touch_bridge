import 'package:shared_preferences/shared_preferences.dart';

class ActiveDeviceService {
  ActiveDeviceService._();
  static final ActiveDeviceService instance = ActiveDeviceService._();

  static const _kActiveDeviceId = 'active_device_id';
  static const _kActiveDeviceName = 'active_device_name';

  Future<void> setActiveDevice({
    required String deviceId,
    String? deviceName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveDeviceId, deviceId);
    final name = deviceName?.trim();
    if (name != null && name.isNotEmpty) {
      await prefs.setString(_kActiveDeviceName, name);
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
}
