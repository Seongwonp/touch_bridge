import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 홈 화면에 등록된 기기 목록(SharedPreferences `home_devices` 키)의 단일 접근 지점.
///
/// 저장 형식을 바꿀 때 이 파일만 고치면 되도록, 다른 곳에서 `home_devices`를
/// 직접 읽지 않는다.
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
