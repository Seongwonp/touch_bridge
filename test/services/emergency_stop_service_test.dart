import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/active_device_service.dart';
import 'package:touch_bridge/services/ble_service.dart';
import 'package:touch_bridge/services/emergency_stop_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BleService.instance.clearTestOverrides();
  });

  group('EmergencyStopService.stopActiveDevice (3개 화면 복제 로직의 단일화)', () {
    test('연결/활성 기기가 없으면 전송 없이 정직하게 실패를 보고한다', () async {
      // 활성 기기의 BLE id를 비운다 (싱글톤 잔여 상태 정리).
      await ActiveDeviceService.instance.setActiveDevice(
        deviceId: 'no-ble-device',
        bleId: null,
      );

      final outcome = await EmergencyStopService.instance.stopActiveDevice();

      expect(outcome.sent, isFalse);
      expect(outcome.acknowledged, isFalse);
      expect(outcome.message, contains('연결된 기기가 없습니다'));
    });

    test('활성 기기 연결 실패 시 acknowledged=false로 보고한다 (거짓 완료 금지)', () async {
      BleService.instance.setTestOverrides(connect: (_) async => false);
      await ActiveDeviceService.instance.setActiveDevice(
        deviceId: 'device-1',
        bleId: 'AA:BB:CC:DD:EE:01',
      );

      final outcome = await EmergencyStopService.instance.stopActiveDevice();

      expect(outcome.acknowledged, isFalse,
          reason: '전송/연결이 안 됐는데 "멈췄습니다"로 안내되면 안 된다');
      expect(outcome.message, isNotEmpty);
    });
  });
}
