import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'active_device_service.dart';
import 'ble_service.dart';
import 'device_mapping_service.dart';
import 'home_device_store.dart';

/// [디버그/데모 전용] 시뮬레이터에서 "실제 작동 루트"를 소리로 테스트하기 위한 임시 시드.
///
/// 등록 기기 1대 + 3x3 매핑 프로필을 저장하고, BLE 데모 모드(전송 성공 흉내)를 켠다.
/// 이렇게 하면 하드웨어 없이도 음성/버튼 명령이 성공 경로를 타서 성공 earcon까지 들린다.
///
/// 릴리스 빌드에서는 [seed]가 즉시 반환하므로 아무 영향이 없다.
/// 테스트가 끝나면 main.dart의 호출과 이 파일을 지우면 된다.
class DemoSeed {
  DemoSeed._();

  /// 데모 데이터는 debug 빌드라는 이유만으로 자동 주입하지 않는다.
  /// 실제 하드웨어 검증을 가짜 성공 경로로 오인하지 않도록 명시적인
  /// `--dart-define=TOUCH_BRIDGE_DEMO=true`가 있을 때만 활성화한다.
  static const bool enabled = bool.fromEnvironment(
    'TOUCH_BRIDGE_DEMO',
    defaultValue: false,
  );

  static const String bleId = 'DEMO-BLE-0001';
  static const String deviceId = 'demo-microwave';
  static const String deviceName = '데모 전자레인지';

  static Future<void> seed() async {
    if (!kDebugMode || !enabled) return;

    // 1) 등록 기기 1대
    await HomeDeviceStore.saveDevices([
      {
        'id': deviceId,
        'name': deviceName,
        'status': '작동 대기 중',
        'iconCodePoint': Icons.microwave.codePoint,
        'bleId': bleId,
        'bleName': '데모 브리지',
      },
    ]);

    // 2) 3x3 매핑 프로필 (BT-01~BT-09)
    const profile = DeviceMappingProfile(
      rows: 3,
      cols: 3,
      originX: 10,
      originY: 10,
      pitchX: 20,
      pitchY: 20,
      buttonMap: {
        'BT-01': (row: 0, col: 0),
        'BT-02': (row: 0, col: 1),
        'BT-03': (row: 0, col: 2),
        'BT-04': (row: 1, col: 0),
        'BT-05': (row: 1, col: 1),
        'BT-06': (row: 1, col: 2),
        'BT-07': (row: 2, col: 0),
        'BT-08': (row: 2, col: 1),
        'BT-09': (row: 2, col: 2),
      },
    );
    await DeviceMappingService.instance.save(deviceId, profile);

    // 3) BLE 데모 모드(전송 성공 흉내) + 활성 기기 지정
    BleService.instance.enableDemoMode(bleId);
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      bleId: bleId,
      bleName: '데모 브리지',
    );
  }
}
