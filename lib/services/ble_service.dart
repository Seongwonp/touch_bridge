// TODO(hardware): BLE 연동 구현 — ESP32 GATT 서버와 통신
//
// 연결 순서:
//   1. flutter_blue_plus 패키지 추가 (pubspec.yaml)
//   2. BleService.scan() → ESP32 광고 패킷 감지
//   3. BleService.connect(deviceId) → GATT 연결
//   4. BleService.sendCommand(x, y) → Characteristic 쓰기
//
// ESP32 GATT 스펙:
//   Service UUID    : 0000FFE0-0000-1000-8000-00805F9B34FB
//   Characteristic  : 0000FFE1-0000-1000-8000-00805F9B34FB
//
// 명령 포맷 (JSON string):
//   { "action": "press", "x": 0, "y": 1, "deviceId": "microwave_1" }
//
// 참고: CLAUDE.md "하드웨어 BLE 프로토콜" 섹션

// ignore_for_file: unused_element

import 'package:flutter/foundation.dart';

class BleService {
  BleService._();
  static final BleService instance = BleService._();

  bool get isConnected => false; // TODO(hardware): 실제 연결 상태 반환

  // TODO(hardware): 주변 ESP32 기기 스캔 시작
  Future<List<BleDeviceInfo>> scan({Duration timeout = const Duration(seconds: 5)}) async {
    if (kDebugMode) debugPrint('[BLE] scan() — not implemented yet');
    return [];
  }

  // TODO(hardware): 기기에 연결
  Future<bool> connect(String deviceId) async {
    if (kDebugMode) debugPrint('[BLE] connect($deviceId) — not implemented yet');
    return false;
  }

  // TODO(hardware): 연결 해제
  Future<void> disconnect() async {
    if (kDebugMode) debugPrint('[BLE] disconnect() — not implemented yet');
  }

  // TODO(hardware): 버튼 좌표를 ESP32로 전송
  // x, y: 0-based 그리드 인덱스 (3x3 → 0~2)
  Future<bool> sendPress({required int x, required int y, required String deviceId}) async {
    if (kDebugMode) {
      debugPrint('[BLE] sendPress(x:$x, y:$y, deviceId:$deviceId) — not implemented yet');
    }
    // TODO(hardware): flutter_blue_plus로 Characteristic write 구현
    // final characteristic = _getCharacteristic();
    // final payload = jsonEncode({'action': 'press', 'x': x, 'y': y, 'deviceId': deviceId});
    // await characteristic.write(utf8.encode(payload));
    return false;
  }

  // TODO(hardware): 비상 정지 신호 전송
  Future<void> sendEmergencyStop(String deviceId) async {
    if (kDebugMode) debugPrint('[BLE] sendEmergencyStop($deviceId) — not implemented yet');
    // TODO(hardware): { "action": "stop", "deviceId": deviceId } 전송
  }
}

class BleDeviceInfo {
  const BleDeviceInfo({required this.id, required this.name, required this.rssi});
  final String id;
  final String name;
  final int rssi;
}
