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
    TtsService().resetForTest();
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

    testWidgets('한 번 탭으로 바로 정지를 시도하고, 미확인이면 완료 화면으로 가지 않는다',
        (tester) async {
      await tester.pumpWidget(
        wrap(const Scaffold(appBar: TopAppBar(title: '테스트 화면'))),
      );

      await tester.tap(find.byType(GlobalEmergencyAction));
      // 정지 시도(테스트 환경: 연결 없음 → 즉시 실패 outcome) 처리 대기.
      // pumpAndSettle은 진행 스피너(무한 애니메이션) 때문에 쓸 수 없다.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(TtsService().getRecentLog().any((l) => l.contains('즉시 중단합니다')), isTrue,
          reason: '정지는 확인 없이 첫 탭에서 바로 요청한다');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '_stopping이 해제되지 않으면 전역 버튼이 영구 잠긴다');
      // ACK가 확인되지 않았으므로 정지 완료 화면으로 이동하면 안 된다.
      expect(find.byType(StopDoneScreen), findsNothing);
    });

    testWidgets('낭독기 두 번 탭(semantics tap)으로도 바로 정지를 시도한다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(const Scaffold(appBar: TopAppBar(title: '테스트 화면'))),
      );
      tester.semantics.tap(find.semantics.byLabel('비상 정지'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(TtsService().getRecentLog().any((l) => l.contains('즉시 중단합니다')), isTrue);
      handle.dispose();
    });

    testWidgets('터치 영역이 56dp 이상이다', (tester) async {
      await tester.pumpWidget(
        wrap(const Scaffold(appBar: TopAppBar(title: '테스트 화면'))),
      );
      final size = tester.getSize(find.byType(GlobalEmergencyAction));
      expect(size.width, greaterThanOrEqualTo(56));
      expect(size.height, greaterThanOrEqualTo(56));
    });
  });
}
