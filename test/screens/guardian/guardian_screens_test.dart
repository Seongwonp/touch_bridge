import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/guardian/guardian_device_screen.dart';
import 'package:touch_bridge/screens/guardian/guardian_hub_screen.dart';
import 'package:touch_bridge/screens/home/home_screen.dart';
import 'package:touch_bridge/screens/settings/settings_screen.dart';
import 'package:touch_bridge/services/accessibility_settings.dart';
import 'package:touch_bridge/services/active_device_service.dart';
import 'package:touch_bridge/services/home_device_store.dart';

/// 보호자 기능(가전 등록·버튼 위치·이름·삭제)은 설정의 보호자 설정 한곳에 모았다.
/// 사용자 화면(홈)에는 이 기능이 끼어들지 않아야 한다.
void main() {
  final device = {
    'id': 'dev-1',
    'name': '전자레인지',
    'status': '작동 대기 중',
    'iconCodePoint': Icons.microwave.codePoint,
    'bleId': 'BLE-1',
    'bleName': '테스트 브리지',
    'deviceType': 'microwave',
  };

  Future<void> seed({List<Map<String, Object>>? devices, Map<String, Object> extra = const {}}) async {
    SharedPreferences.setMockInitialValues({
      'home_devices': jsonEncode(devices ?? [device]),
      'quick_start_seen': true,
      ...extra,
    });
    await AccessibilitySettings.instance.load();
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('설정에는 켜고 끄는 모드 없이 보호자 설정 입구가 늘 있다', (tester) async {
    await seed();
    await pump(tester, const SettingsScreen());

    expect(find.text('보호자 설정'), findsWidgets);
    expect(find.text('보호자 안내 모드'), findsNothing);

    await tester.tap(find.text('가전 추가, 버튼 위치 수정, 장치 점검'));
    await tester.pumpAndSettle();
    expect(find.byType(GuardianHubScreen), findsOneWidget);
  });

  testWidgets('보호자 설정은 등록된 가전과 가전 추가를 보여 주고, 가전을 누르면 그 가전 설정을 연다', (tester) async {
    await seed();
    await pump(tester, const GuardianHubScreen());

    expect(find.text('전자레인지'), findsOneWidget);
    expect(find.text('가전 추가'), findsOneWidget);
    expect(find.text('원점 복귀'), findsOneWidget);

    await tester.tap(find.text('전자레인지'));
    await tester.pumpAndSettle();
    expect(find.byType(GuardianDeviceScreen), findsOneWidget);
    expect(find.text('버튼 위치 수정'), findsOneWidget);
    expect(find.text('사진으로 버튼 다시 찾기'), findsOneWidget);
  });

  testWidgets('이름을 바꾸면 저장소와 활성 기기 이름이 함께 바뀐다', (tester) async {
    await seed();
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: 'dev-1',
      deviceName: '전자레인지',
      bleId: 'BLE-1',
      bleName: '테스트 브리지',
    );
    await pump(tester, const GuardianDeviceScreen(deviceId: 'dev-1'));

    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '부엌 전자레인지');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    final stored = await HomeDeviceStore.findById('dev-1');
    expect(stored?['name'], '부엌 전자레인지');
    expect(ActiveDeviceService.instance.getActiveDeviceName(), '부엌 전자레인지');
    expect(ActiveDeviceService.instance.getActiveDeviceType(), 'microwave');
  });

  testWidgets('삭제하면 기기와 버튼 위치 설정을 지우고 활성 기기도 비운다', (tester) async {
    await seed(extra: {'mapping_profile_dev-1': '{}'});
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: 'dev-1',
      deviceName: '전자레인지',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GuardianDeviceScreen(deviceId: 'dev-1'),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('기기 삭제'), 200);
    await tester.tap(find.text('기기 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '삭제'));
    await tester.pumpAndSettle();

    expect(await HomeDeviceStore.findById('dev-1'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('mapping_profile_dev-1'), isFalse);
    expect(ActiveDeviceService.instance.getActiveDeviceId(), isNull);
    // 삭제 뒤에는 가전 설정 화면을 닫는다.
    expect(find.byType(GuardianDeviceScreen), findsNothing);
  });

  testWidgets('삭제 확인에서 취소하면 아무것도 지우지 않는다', (tester) async {
    await seed();
    await pump(tester, const GuardianDeviceScreen(deviceId: 'dev-1'));

    await tester.scrollUntilVisible(find.text('기기 삭제'), 200);
    await tester.tap(find.text('기기 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(await HomeDeviceStore.findById('dev-1'), isNotNull);
  });

  testWidgets('홈에는 가전 추가 카드가 없고, 옛 보호자 모드 값이 켜져 있어도 관리 기능이 끼어들지 않는다', (tester) async {
    await seed(extra: {'guardian_mode': true});
    await pump(tester, const HomeScreen());

    expect(find.text('전자레인지'), findsWidgets);
    expect(find.text('새 기기 추가하기'), findsNothing);
    expect(find.textContaining('삭제'), findsNothing);
  });

  testWidgets('가전이 없는 홈은 보호자 설정을 여는 버튼만 둔다', (tester) async {
    await seed(devices: []);
    await pump(tester, const HomeScreen());

    expect(find.text('기기 추가하기'), findsNothing);
    await tester.tap(find.text('보호자 설정 열기'));
    await tester.pumpAndSettle();
    expect(find.byType(GuardianHubScreen), findsOneWidget);
  });
}
