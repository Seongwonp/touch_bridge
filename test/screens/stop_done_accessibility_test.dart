import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/safety/stop_done_screen.dart';
import 'package:touch_bridge/screens/voice/voice_listening_screen.dart';
import 'package:touch_bridge/services/power_status_service.dart';

void main() {
  testWidgets('화면읽기에서는 완료 화면의 홈 이동이 한 번의 앱 활성화로 끝난다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const StopDoneScreen(completed: true),
                ),
              ),
              child: const Text('완료 화면 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('완료 화면 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('홈으로 돌아가기'));
    await tester.pumpAndSettle();

    expect(find.text('완료 화면 열기'), findsOneWidget);
    expect(find.byType(StopDoneScreen), findsNothing);
  });

  // 끝난 화면은 볼 수 없어도 할 수 있는 일만 안내한다(외부 평가).
  test('전류 센서 보고가 없으면 앱이 모른다고 말하고 종료음을 들어 보라고 한다', () {
    final text = StopDoneScreenPowerText.of(PowerState.unknown);
    expect(text, contains('확인할 수 없습니다'));
    expect(text, contains('종료음'));
    expect(StopDoneScreenPowerText.of(PowerState.off), contains('꺼졌습니다'));
    expect(StopDoneScreenPowerText.of(PowerState.on), contains('켜져 있습니다'));
  });

  testWidgets('정지 완료 화면은 가전 취소 버튼을 눌러 주는 버튼을 둔다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StopDoneScreen()));
    await tester.pump();

    expect(find.textContaining('가전의 취소 버튼을 눌러 주세요'), findsNothing);
    final cancel = find.byKey(const Key('stop_done_cancel_appliance'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(VoiceListeningScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('시간 종료 화면에는 가전 취소 버튼을 두지 않는다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StopDoneScreen(completed: true)));
    await tester.pump();
    expect(find.byKey(const Key('stop_done_cancel_appliance')), findsNothing);
  });
}
