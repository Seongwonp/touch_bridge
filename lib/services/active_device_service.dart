import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ble_service.dart';
import 'home_device_store.dart';

class ActiveDeviceService {
  ActiveDeviceService._();
  static final ActiveDeviceService instance = ActiveDeviceService._();

  // 기기 목록 변경 알림을 위한 노티파이어 추가
  final ValueNotifier<int> deviceListUpdateNotifier = ValueNotifier<int>(0);

  void notifyDeviceListChanged() {
    deviceListUpdateNotifier.value++;
  }

  // 메모리 캐시
  String? _activeDeviceId;
  String? _activeDeviceName;
  String? _activeBleId;
  String? _activeDeviceType;

  static const _kActiveDeviceId = 'active_device_id';
  static const _kActiveDeviceName = 'active_device_name';
  static const _kActiveBleId = 'active_ble_id';
  static const _kActiveBleName = 'active_ble_name';
  static const _kActiveDeviceType = 'active_device_type';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _activeDeviceId = prefs.getString(_kActiveDeviceId);
    _activeDeviceName = prefs.getString(_kActiveDeviceName);
    _activeBleId = prefs.getString(_kActiveBleId);
    _activeDeviceType = prefs.getString(_kActiveDeviceType);
  }

  Future<void> setActiveDevice({
    required String deviceId,
    String? deviceName,
    String? bleId,
    String? bleName,
    String? deviceType,
  }) async {
    _activeDeviceId = deviceId;
    _activeDeviceName = deviceName;
    _activeBleId = bleId;
    _activeDeviceType = deviceType;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveDeviceId, deviceId);
    
    if (deviceName != null && deviceName.isNotEmpty) {
      await prefs.setString(_kActiveDeviceName, deviceName);
    } else {
      await prefs.remove(_kActiveDeviceName);
    }
    
    if (bleId != null) {
      await prefs.setString(_kActiveBleId, bleId);
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

    if (deviceType != null && deviceType.isNotEmpty) {
      await prefs.setString(_kActiveDeviceType, deviceType);
    } else {
      await prefs.remove(_kActiveDeviceType);
    }
  }

  String? getActiveDeviceId() => _activeDeviceId;
  String? getActiveDeviceName() => _activeDeviceName;
  String? getActiveBleId() => _activeBleId;
  String? getActiveDeviceType() => _activeDeviceType;
  
  Future<String?> getActiveBleName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kActiveBleName);
  }

  /// 기기가 선택되어 있지 않을 때, 등록된 기기 중 첫 번째를 자동으로 활성화함
  Future<bool> autoPickFirstDevice() async {
    if (_activeDeviceId != null && _activeDeviceId!.isNotEmpty) return true;

    final devices = await HomeDeviceStore.loadDevices();
    if (devices.isEmpty) return false;

    final first = devices.first;
    await setActiveDevice(
      deviceId: first['id'] ?? '',
      deviceName: first['name'],
      bleId: first['bleId'],
      bleName: first['bleName'],
    );
    return true;
  }
}
