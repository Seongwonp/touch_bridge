import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/practice/practice_screen.dart';
import 'package:touch_bridge/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TtsService().disableEngineForTest = true;
  });

  tearDown(() {
    TtsService().disableEngineForTest = false;
  });

  Future<void> pumpPractice(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PracticeScreen()));
    // STT initialize 등 초기 비동기 흐름을 흘려보낸다.
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('연습 모드', () {
    testWidgets('세 가지 레슨이 모두 표시된다', (tester) async {
      await pumpPractice(tester);

      expect(find.text('1. 이중 탭 연습'), findsOneWidget);
      expect(find.text('2. 비상 정지 연습'), findsOneWidget);
      expect(find.text('3. 음성 명령 연습'), findsOneWidget);
      // 핵심 약속: 아무것도 실제로 실행되지 않는다는 안내.
      expect(find.textContaining('실제로 실행되지 않아요'), findsOneWidget);
    });

    testWidgets('이중 탭: 첫 탭은 arm만, 둘째 탭에서 성공 카운트가 오른다', (tester) async {
      await pumpPractice(tester);

      await tester.ensureVisible(find.text('연습 시작'));
      await tester.tap(find.text('연습 시작'));
      await tester.pump();

      // 첫 탭: 실행 아님 — 성공 카운트 0 유지, armed 표시.
      expect(find.text('연습 시작 (다시 누르기)'), findsOneWidget);
      expect(find.text('성공 1번 ✓'), findsNothing);

      await tester.tap(find.text('연습 시작 (다시 누르기)'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('성공 1번 ✓'), findsOneWidget);
    });

    testWidgets('이중 탭: 20초가 지나면 자동으로 arm이 해제된다 (WCAG 2.2.1 학습)',
        (tester) async {
      await pumpPractice(tester);

      await tester.ensureVisible(find.text('연습 시작'));
      await tester.tap(find.text('연습 시작'));
      await tester.pump();
      expect(find.text('연습 시작 (다시 누르기)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 21));

      expect(find.text('연습 시작'), findsOneWidget);
      expect(find.text('연습 시작 (다시 누르기)'), findsNothing);
    });

    testWidgets('3초 홀드를 완주하면 성공, 중간에 떼면 실패다', (tester) async {
      await pumpPractice(tester);

      final holdButton = find.text('길게 눌러 중단 (연습)');
      await tester.ensureVisible(holdButton);

      // 중간에 떼기: ~1초만 누르고 해제 → 성공 카운트 없음.
      // (FakeAsync에서 Ticker의 첫 프레임은 기준점이라 프레임을 나눠 pump해야
      // 애니메이션이 진행된다.)
      final gesture1 = await tester.startGesture(tester.getCenter(holdButton));
      await tester.pump(const Duration(milliseconds: 600)); // long-press 인식
      await tester.pump(const Duration(milliseconds: 100)); // ticker 기준점
      await tester.pump(const Duration(milliseconds: 400)); // 진행 ~0.4초
      await gesture1.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('성공 1번'), findsNothing);

      // 3초 완주 → 성공.
      final gesture2 = await tester.startGesture(tester.getCenter(
        find.text('길게 눌러 중단 (연습)'),
      ));
      await tester.pump(const Duration(milliseconds: 600)); // long-press 인식
      await tester.pump(const Duration(milliseconds: 100)); // ticker 기준점
      await tester.pump(const Duration(milliseconds: 3200)); // 3초 완주
      await gesture2.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('성공 1번 ✓'), findsOneWidget);
    });

    testWidgets('음성 인식 불가 환경에서는 정직하게 사용 불가로 표시한다', (tester) async {
      // 테스트 환경에는 STT 플랫폼이 없다 — 가짜로 되는 척하지 않아야 한다.
      await pumpPractice(tester);
      await tester.ensureVisible(find.text('3. 음성 명령 연습'));

      expect(find.text('음성 인식 사용 불가'), findsOneWidget);
    });
  });
}
