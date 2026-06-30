import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/main_navigation_screen.dart';
import 'package:touch_bridge/services/accessibility_settings.dart';

Future<void> _pumpWithGuardianMode(
  WidgetTester tester, {
  required bool enabled,
}) async {
  SharedPreferences.setMockInitialValues({
    'guardian_mode': enabled,
    'quick_start_seen': true,
  });
  await AccessibilitySettings.instance.load();
  await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('사용자 모드 하단 바는 홈/비상/설정만 표시한다', (tester) async {
    await _pumpWithGuardianMode(tester, enabled: false);

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('비상'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('연결'), findsNothing);
    expect(find.text('음성'), findsNothing);
    expect(find.text('기기 관리'), findsNothing);
  });

  testWidgets('보호자 모드 하단 바는 기기 관리를 표시한다', (tester) async {
    await _pumpWithGuardianMode(tester, enabled: true);

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('기기 관리'), findsOneWidget);
    expect(find.text('비상'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('연결'), findsNothing);
    expect(find.text('음성'), findsNothing);
  });
}
