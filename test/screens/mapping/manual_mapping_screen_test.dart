import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/mapping/manual_mapping_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('보호자용 위치 맞추기 UI를 노출하고 Z축 제어를 제거한다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ManualMappingScreen(
          deviceId: 'test-microwave',
          deviceName: '전자레인지',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('보호자 설정 · 위치 맞추기'), findsOneWidget);
    expect(find.text('조이스틱으로 미세 조정'), findsOneWidget);
    expect(find.text('현재 위치 · 앱 기준'), findsOneWidget);
    expect(find.text('버튼 선택 · 0개 등록됨'), findsOneWidget);
    expect(find.text('버튼 추가'), findsOneWidget);
    expect(find.text('스위치봇 눌러보기'), findsOneWidget);
    expect(find.text('고급 그리드 설정'), findsOneWidget);
    expect(find.text('Z+10'), findsNothing);
    expect(find.text('Z-10'), findsNothing);
  });

  testWidgets('버튼 추가 창을 취소해도 화면 오류가 발생하지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ManualMappingScreen(
          deviceId: 'test-microwave',
          deviceName: '전자레인지',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('버튼 추가'));
    await tester.pumpAndSettle();
    expect(find.text('버튼 이름'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('조이스틱으로 미세 조정'), findsOneWidget);
  });
}
