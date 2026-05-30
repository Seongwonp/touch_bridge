import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/active_device_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores and resolves the active device context', () async {
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: 'device-123',
      deviceName: '전자레인지',
    );

    expect(await ActiveDeviceService.instance.getActiveDeviceId(), 'device-123');
    expect(await ActiveDeviceService.instance.getActiveDeviceName(), '전자레인지');
  });
}
