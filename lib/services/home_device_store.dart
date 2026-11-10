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
  ///
  /// 화면이 들고 있던 목록을 통째로 저장하면 다른 화면(홈·기기 관리 탭은 함께
  /// 살아 있다)이 그사이 바꾼 내용을 덮어쓴다. 한 기기만 바꿀 때는 아래
  /// [findById]·[removeById]·[updateById]처럼 저장소를 다시 읽어 고치는 함수를 쓴다.
  static Future<void> saveDevices(List<Map<String, dynamic>> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(devices));
  }

  /// [id] 기기 기록. 없으면 null.
  static Future<Map<String, dynamic>?> findById(String id) async {
    for (final d in await loadDevices()) {
      if (d['id'] == id) return d;
    }
    return null;
  }

  /// 저장소에서 [id] 기기를 지운다. 지웠으면 true.
  static Future<bool> removeById(String id) async {
    final devices = await loadDevices();
    final before = devices.length;
    devices.removeWhere((d) => d['id'] == id);
    if (devices.length == before) return false;
    await saveDevices(devices);
    return true;
  }

  /// 저장소의 [id] 기기에 [changes]를 덮어쓴다. 찾았으면 true.
  static Future<bool> updateById(String id, Map<String, dynamic> changes) async {
    final devices = await loadDevices();
    final i = devices.indexWhere((d) => d['id'] == id);
    if (i < 0) return false;
    devices[i] = {...devices[i], ...changes};
    await saveDevices(devices);
    return true;
  }
}
