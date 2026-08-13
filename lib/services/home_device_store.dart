import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 홈 화면에 등록된 기기 목록(SharedPreferences `home_devices` 키)의 단일 접근 지점.
///
/// 이전에는 home_screen/device_management_screen/device_connect_screen/
/// photo_mapping_view_model/voice_listening_screen/active_device_service 6곳에서
/// 각자 `prefs.getString('home_devices')` + `jsonDecode`를 반복하고 있었음 —
/// 저장 형식을 바꾸려면 6곳을 동시에 고쳐야 하는 구조였음. 이 서비스로 단일화.
class HomeDeviceStore {
  HomeDeviceStore._();

  static const String _key = 'home_devices';

  /// 등록된 기기 목록을 불러온다. 저장된 값이 없으면 빈 리스트를 반환한다.
  static Future<List<Map<String, dynamic>>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final decoded = jsonDecode(jsonStr) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// 기기 목록 전체를 저장한다.
  static Future<void> saveDevices(List<Map<String, dynamic>> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(devices));
  }
}
