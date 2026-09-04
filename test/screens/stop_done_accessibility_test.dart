import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/safety/stop_done_screen.dart';

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
}
