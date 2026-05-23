import 'dart:async';
import 'package:flutter/foundation.dart';

/// 하드웨어 제어를 위한 인터페이스 정의
/// 나중에 팀원이 ESP32 블루투스 연결을 완성하면 
/// 이 클래스를 상속받는 BluetoothDeviceService를 만들면 됩니다.
abstract class DeviceService {
  ValueNotifier<bool> get isConnected;
  ValueNotifier<bool> get isOperating;

  Future<bool> connect(String deviceId);
  Future<void> disconnect();
  
  /// 모터 제어 명령 전송
  /// [sensitivity]: 누르는 힘 (10~100)
  /// [speed]: 이동 속도 (10~100)
  Future<void> sendMotorCommand({required int sensitivity, required int speed});
}

/// 하드웨어 없이 테스트하기 위한 가상 서비스
class MockDeviceService implements DeviceService {
  @override
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  @override
  final ValueNotifier<bool> isOperating = ValueNotifier<bool>(false);

  @override
  Future<bool> connect(String deviceId) async {
    print('Mock: 연결 시도 중... ($deviceId)');
    await Future.delayed(const Duration(seconds: 1));
    isConnected.value = true;
    print('Mock: 연결 성공');
    return true;
  }

  @override
  Future<void> disconnect() async {
    print('Mock: 연결 해제');
    isConnected.value = false;
  }

  @override
  Future<void> sendMotorCommand({required int sensitivity, required int speed}) async {
    if (!isConnected.value) {
      print('Mock Error: 기기가 연결되어 있지 않습니다.');
      return;
    }

    print('Mock: 명령 전송 -> {"cmd": "ST", "sen": $sensitivity, "spd": $speed}');
    
    isOperating.value = true;
    // 실제 모터가 작동하는 시간을 시뮬레이션
    await Future.delayed(const Duration(seconds: 2));
    isOperating.value = false;
    
    print('Mock: 작동 완료');
  }
}
