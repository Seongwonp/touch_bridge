import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/safety/stop_done_screen.dart';
import 'package:touch_bridge/services/tts_service.dart';
import 'package:touch_bridge/widgets/global_emergency_action.dart';
import 'package:touch_bridge/widgets/top_app_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // FakeAsync(testWidgets) 환경에서는 TTS 플랫폼 채널이 영원히 완료되지 않아
    // speak()를 await하는 위젯 로직이 멈춘다 — 엔진 호출만 생략한다.
    TtsService().disableEngineForTest = true;
  });

  tearDown(() {
    TtsService().disableEngineForTest = false;
  });

  Widget wrap(Widget appBarHolder) => MaterialApp(home: appBarHolder);

  group('전역 비상 정지 버튼 (TopAppBar 상주)', () {
    testWidgets('TopAppBar에 기본으로 노출된다', (tester) async {
      await tester.pumpWidget(
        wrap(const Scaffold(appBar: TopAppBar(title: '테스트 화면'))),
      );
      expect(find.byType(GlobalEmergencyAction), findsOneWidget);
      expect(find.bySemanticsLabel('비상 정지'), findsOneWidget);
    });

    testWidgets('showEmergency:false면 노출되지 않는다 (비상 계열 화면 중복 방지)',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const Scaffold(
            appBar: TopAppBar(title: '비상 정지', showEmergency: false),
          ),
        ),
      );
      expect(find.byType(GlobalEmergencyAction), findsNothing);
    });

    testWidgets('첫 탭은 실행하지 않고 arm 상태만 만든다 (이중 탭 원칙)', (tester) async {
      await tester.pumpWidget(
        wrap(const Scaffold(appBar: TopAppBar(title: '테스트 화면'))),
      );

      await tester.tap(find.byType(GlobalEmergencyAction));
      await tester.pump();

      // arm 상태가 Semantics value로 노출된다 (스크린리더 병행 채널).
      final semantics = tester.getSemantics(
        find.bySemanticsLabel('비상 정지'),
      );
      expect(semantics.value, '실행 대기 중');
      // 실행되지 않았으므로 완료 화면으로 이동하지 않는다.
      expect(find.byType(StopDoneScreen), findsNothing);

      // 타이머 정리 (arm 20초 타이머가 테스트를 오염시키지 않도록).
      await tester.pump(const Duration(seconds: 21));
    });

    testWidgets('둘째 탭에서 정지를 실행하고, 미확인이면 완료 화면으로 가지 않는다',
        (tester) async {
      await tester.pumpWidget(
        wrap(const Scaffold(appBar: TopAppBar(title: '테스트 화면'))),
      );

      await tester.tap(find.byType(GlobalEmergencyAction));
      await tester.pump();
      await tester.tap(find.byType(GlobalEmergencyAction));
      // 정지 시도(테스트 환경: 연결 없음 → 즉시 실패 outcome) 처리 대기.
      // pumpAndSettle은 진행 스피너(무한 애니메이션) 프레임 때문에 쓸 수 없다 —
      // 유한 pump로 비동기 흐름을 흘려보낸다.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      // 정지 시도가 끝나 스피너가 해제되어야 하고(버튼 잠김 방지),
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '_stopping이 해제되지 않으면 전역 버튼이 영구 잠긴다');
      // ACK가 확인되지 않았으므로 "안전하게 중단" 완료 화면으로 이동하면 안 된다.
      expect(find.byType(StopDoneScreen), findsNothing);
    });
  });
}
