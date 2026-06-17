import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/active_device_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
