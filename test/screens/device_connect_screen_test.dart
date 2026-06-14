import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/connection/device_connect_screen.dart';
import 'package:touch_bridge/services/ble_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BleService.instance.clearTestOverrides();
  });

  tearDown(() {
    BleService.instance.clearTestOverrides();
  });

  testWidgets('블루투스 검색 결과가 없으면 상태 문구를 갱신한다', (tester) async {
    BleService.instance.setTestOverrides(
      scan: (_) async => const [],
    );

    await tester.pumpWidget(
      const MaterialApp(home: DeviceConnectScreen()),
    );

    expect(find.text('연결 가능한 기기 감지됨'), findsOneWidget);
    await tester.tap(find.text('블루투스 연결'));
    await tester.pumpAndSettle();

    expect(find.text('검색된 BLE 기기가 없습니다.'), findsOneWidget);
  });

  testWidgets('블루투스 기기를 선택해 연결 성공 상태를 표시한다', (tester) async {
    BleService.instance.setTestOverrides(
      scan: (_) async => const [
        BleDeviceInfo(id: 'esp32_001', name: 'ESP32 Hub', rssi: -42),
      ],
      connect: (deviceId) async => deviceId == 'esp32_001',
    );

    await tester.pumpWidget(
      const MaterialApp(home: DeviceConnectScreen()),
    );

    await tester.tap(find.text('블루투스 연결'));
    await tester.pumpAndSettle();
    expect(find.text('ESP32 Hub'), findsWidgets);

    await tester.tap(find.textContaining('RSSI'));
    await tester.pumpAndSettle();

    expect(find.text('BLE 연결 완료'), findsOneWidget);
  });
}
