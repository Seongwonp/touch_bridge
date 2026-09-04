import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/home/widgets/camera_alignment_guide.dart';

void main() {
  testWidgets('촬영 전에 네 단계 방향 안내를 완료하거나 취소할 수 있다', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showCameraAlignmentGuide(context);
            },
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('기기 전체가 잘리면 뒤로 이동'), findsOneWidget);

    await tester.tap(find.text('다음 안내'));
    await tester.pumpAndSettle();
    expect(find.text('좌우 여백 맞추기'), findsOneWidget);
    await tester.tap(find.text('다음 안내'));
    await tester.pumpAndSettle();
    expect(find.text('위아래 여백 맞추기'), findsOneWidget);
    await tester.tap(find.text('다음 안내'));
    await tester.pumpAndSettle();
    expect(find.text('수평과 반사 확인'), findsOneWidget);

    await tester.tap(find.text('카메라 열기'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
