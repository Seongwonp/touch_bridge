import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/voice/widgets/press_progress_view.dart';
import 'package:touch_bridge/services/emergency_intent.dart';
import 'package:touch_bridge/services/single_tap_stop_controller.dart';

/// 실행 중 화면의 단일 탭 비상 정지 (리뷰 #3).
///
/// 음성 화면 전체는 STT·TTS·저장소 싱글톤에 묶여 있어 여기서는 진행 뷰 위젯만
/// 띄운다. 검증: 실행 중 버튼 노출, 한 번 탭으로 정지 경로 호출, 진행 중 중복 탭
/// 무시, 결과별(확인/미확인/실패) 안내, 실패 뒤 재시도, 완료 화면에서는 버튼 없음.
/// CircularProgressIndicator가 무한 애니메이션이라 pumpAndSettle은 타임아웃된다.
/// 비동기 정지 결과가 반영될 만큼만 프레임을 돌린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  Widget host({
    required SingleTapStopController controller,
    required VoidCallback onStopTap,
    bool done = false,
    String label = '2번 버튼을 누르는 중입니다.',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: PressProgressView(
            label: label,
            done: done,
            stopController: controller,
            onStopTap: onStopTap,
          ),
        ),
      ),
    );
  }

  testWidgets('실행 중에는 단일 탭 정지 버튼이 보이고 완료 화면에는 없다', (tester) async {
    final c = SingleTapStopController(
      stop: () async => EmergencyStopOutcome.fromAck('STOPPED'),
    );

    await tester.pumpWidget(host(controller: c, onStopTap: () {}));
    expect(find.byKey(PressProgressView.stopButtonKey), findsOneWidget);
    expect(find.text('즉시 정지'), findsOneWidget);
    expect(find.textContaining('한 번 누르세요'), findsOneWidget);

    await tester.pumpWidget(host(controller: c, onStopTap: () {}, done: true, label: '전달했습니다.'));
    expect(find.byKey(PressProgressView.stopButtonKey), findsNothing);
  });

  testWidgets('한 번 탭으로 확인 단계 없이 정지 경로가 호출된다', (tester) async {
    var stops = 0;
    final c = SingleTapStopController(stop: () async {
      stops++;
      return EmergencyStopOutcome.fromAck('STOPPED');
    });

    await tester.pumpWidget(host(controller: c, onStopTap: () => c.requestStop()));
    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await settle(tester);

    expect(stops, 1, reason: '두 번째 탭·확인창·길게 누르기 없이 한 번에 실행');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('기기를 멈췄습니다. 안전합니다.'), findsOneWidget);
  });

  testWidgets('정지 요청 중에는 버튼이 비활성이고 중복 탭이 새 요청을 만들지 않는다', (tester) async {
    var stops = 0;
    final gate = Completer<EmergencyStopOutcome>();
    final c = SingleTapStopController(stop: () {
      stops++;
      return gate.future;
    });

    await tester.pumpWidget(host(controller: c, onStopTap: () => c.requestStop()));
    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await tester.pump();

    expect(find.text('정지 요청 중'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(PressProgressView.stopButtonKey));
    expect(button.onPressed, isNull, reason: '진행 중에는 탭이 무시돼야 한다');
    await tester.tap(find.byKey(PressProgressView.stopButtonKey), warnIfMissed: false);
    await tester.tap(find.byKey(PressProgressView.stopButtonKey), warnIfMissed: false);
    await tester.pump();
    expect(stops, 1);

    gate.complete(EmergencyStopOutcome.fromAck('STOPPED'));
    await settle(tester);
    expect(find.text('기기를 멈췄습니다. 안전합니다.'), findsOneWidget);
  });

  testWidgets('미확인 결과는 정지 완료라고 말하지 않고 다시 정지를 허용한다', (tester) async {
    final acks = ['ERROR:TIMEOUT', 'STOPPED'];
    var i = 0;
    final c = SingleTapStopController(
      stop: () async => EmergencyStopOutcome.fromAck(acks[i++]),
    );

    await tester.pumpWidget(host(controller: c, onStopTap: () => c.requestStop()));
    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await settle(tester);

    final outcomeText = tester.widget<Text>(find.byKey(const Key('press_progress_stop_outcome')));
    expect(outcomeText.data, contains('응답을 확인하지 못했습니다'));
    expect(outcomeText.data, isNot(contains('멈췄습니다')));
    expect(find.text('다시 정지'), findsOneWidget);

    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await settle(tester);
    expect(find.text('기기를 멈췄습니다. 안전합니다.'), findsOneWidget);
    expect(c.requestCount, 2);
  });

  testWidgets('전송 실패 결과는 실패 문구를 보이고 재시도 버튼을 준다', (tester) async {
    final c = SingleTapStopController(
      stop: () async => EmergencyStopOutcome.fromAck('ERROR:NOT_CONNECTED'),
    );

    await tester.pumpWidget(host(controller: c, onStopTap: () => c.requestStop()));
    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await settle(tester);

    expect(find.text('연결된 기기가 없습니다. 기기 전원을 확인해 주세요.'), findsOneWidget);
    expect(find.text('다시 정지'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(PressProgressView.stopButtonKey));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('정지 버튼은 스크린리더에 버튼 역할·활성 상태로 노출된다', (tester) async {
    final handle = tester.ensureSemantics();
    final c = SingleTapStopController(
      stop: () async => EmergencyStopOutcome.fromAck('STOPPED'),
    );
    await tester.pumpWidget(host(controller: c, onStopTap: () {}));

    expect(
      tester.getSemantics(find.text('즉시 정지')),
      isSemantics(
        label: '즉시 정지',
        hint: '한 번 누르면 바로 정지 명령을 보냅니다',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
