import 'dart:async';
import 'package:flutter/foundation.dart';

/// 하드웨어 제어를 위한 인터페이스 정의
/// 나중에 팀원이 ESP32 블루투스 연결을 완성하면 
/// 이 클래스를 상속받는 BluetoothDeviceService를 만들면 됩니다.
abstract class DeviceService {
  ValueNotifier<bool> get isConnected;
  ValueNotifier<bool> get isOperating;
  ValueNotifier<bool> get isStalled; // 과부하(걸림) 상태 추가

  Future<bool> connect(String deviceId);
  Future<void> disconnect();
  Future<void> sendMotorCommand({required int sensitivity, required int speed});
  void resetStall(); // 과부하 상태 초기화
}

/// 하드웨어 없이 테스트하기 위한 가상 서비스
class MockDeviceService implements DeviceService {
  @override
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  @override
  final ValueNotifier<bool> isOperating = ValueNotifier<bool>(false);
  @override
  final ValueNotifier<bool> isStalled = ValueNotifier<bool>(false);

  @override
  Future<bool> connect(String deviceId) async {
    print('Mock: 연결 시도 중... ($deviceId)');
    await Future.delayed(const Duration(seconds: 1));
    isConnected.value = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    isConnected.value = false;
  }

  @override
  void resetStall() {
    isStalled.value = false;
    print('Mock: 과부하 상태 초기화');
  }

  @override
  Future<void> sendMotorCommand({required int sensitivity, required int speed}) async {
    if (!isConnected.value) return;

    isOperating.value = true;
    isStalled.value = false;
    print('Mock: 명령 전송 -> {"cmd": "ST", "sen": $sensitivity, "spd": $speed}');
    
    // 시뮬레이션: 감도가 90 이상이면 무조건 과부하 발생 (테스트 용이성을 위해 100%로 변경)
    await Future.delayed(const Duration(seconds: 1));
    
    if (sensitivity >= 90) {
      isStalled.value = true;
      isOperating.value = false;
      print('Mock: !!! 과부하(Stall) 감지 !!!');
      return;
    }

    await Future.delayed(const Duration(seconds: 1));
    isOperating.value = false;
    print('Mock: 작동 완료');
  }
}
