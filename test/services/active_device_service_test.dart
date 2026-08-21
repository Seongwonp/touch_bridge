import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/active_device_service.dart';
import 'package:touch_bridge/services/ble_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BleService.instance.clearTestOverrides();
  });

  group('setActiveDevice BLE 연결 결과 전파', () {
    // 과거 버그: ensureConnected의 실패 bool을 버려서, 기기 선택은 성공처럼
    // 보이는데 실제 연결은 안 된 상태가 첫 명령 실패로만 드러났다.
    test('BLE 연결 실패 시 false를 반환하되 선택 자체는 저장한다', () async {
      BleService.instance.setTestOverrides(connect: (_) async => false);

      final ok = await ActiveDeviceService.instance.setActiveDevice(
        deviceId: 'device-fail',
        deviceName: '전자레인지',
        bleId: 'AA:BB:CC:DD:EE:FF',
      );

      expect(ok, isFalse);
      expect(ActiveDeviceService.instance.getActiveDeviceId(), 'device-fail');
      expect(
        ActiveDeviceService.instance.getActiveBleId(),
        'AA:BB:CC:DD:EE:FF',
      );
    });

    test('BLE 연결 성공 시 true를 반환한다', () async {
      BleService.instance.setTestOverrides(connect: (_) async => true);

      final ok = await ActiveDeviceService.instance.setActiveDevice(
        deviceId: 'device-ok',
        bleId: 'AA:BB:CC:DD:EE:FF',
      );

      expect(ok, isTrue);
    });

    test('bleId가 없으면 연결할 것이 없으므로 true를 반환한다', () async {
      final ok = await ActiveDeviceService.instance.setActiveDevice(
        deviceId: 'device-no-ble',
        bleId: null,
      );

      expect(ok, isTrue);
    });
  });

  test('stores and resolves the active device context including BLE info', () async {
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: 'device-123',
      deviceName: '전자레인지',
      bleId: 'XX:XX:XX:XX:XX:XX',
      bleName: 'ESP32-Hub',
    );

    expect(ActiveDeviceService.instance.getActiveDeviceId(), 'device-123');
    expect(ActiveDeviceService.instance.getActiveDeviceName(), '전자레인지');
    expect(ActiveDeviceService.instance.getActiveBleId(), 'XX:XX:XX:XX:XX:XX');
    expect(await ActiveDeviceService.instance.getActiveBleName(), 'ESP32-Hub');
  });

  test('clears BLE info when null is passed', () async {
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: 'device-123',
      bleId: 'some-id',
    );
    expect(ActiveDeviceService.instance.getActiveBleId(), 'some-id');

    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: 'device-123',
      bleId: null,
    );
    expect(ActiveDeviceService.instance.getActiveBleId(), isNull);
  });
}
