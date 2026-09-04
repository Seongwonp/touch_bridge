import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/main_navigation_screen.dart';
import 'package:touch_bridge/services/accessibility_settings.dart';

Future<void> _pumpWithGuardianMode(
  WidgetTester tester, {
  required bool enabled,
  bool accessibleNavigation = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'guardian_mode': enabled,
    'quick_start_seen': true,
  });
  await AccessibilitySettings.instance.load();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(accessibleNavigation: accessibleNavigation),
      child: const MaterialApp(home: MainNavigationScreen()),
    ),
  );
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

  testWidgets('화면읽기 사용자는 하단 화면 이동에 앱 추가 확인이 필요 없다', (tester) async {
    await _pumpWithGuardianMode(
      tester,
      enabled: false,
      accessibleNavigation: true,
    );

    await tester.tap(find.text('비상'));
    await tester.pumpAndSettle();

    expect(find.text('비상 정지'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('이동 대기 중')), findsNothing);
  });

  testWidgets('화면읽기가 꺼져 있으면 기존 화면 이동 확인을 유지한다', (tester) async {
    await _pumpWithGuardianMode(tester, enabled: false);

    await tester.tap(find.text('비상'));
    await tester.pump();

    expect(find.text('비상 정지'), findsNothing);
    await tester.tap(find.text('비상'));
    await tester.pumpAndSettle();
    expect(find.text('비상 정지'), findsWidgets);
  });
}
