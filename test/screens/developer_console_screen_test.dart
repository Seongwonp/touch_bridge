import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/settings/developer_console_screen.dart';

void main() {
  testWidgets('개발자 콘솔은 작은 화면에서도 주요 제어를 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: DeveloperConsoleScreen()));
    await tester.pumpAndSettle();

    expect(find.text('홈 복귀 \$H'), findsOneWidget);
    expect(find.text('STOP'), findsOneWidget);
    expect(find.text('Z 테스트'), findsOneWidget);
    expect(find.text('dry-run'), findsOneWidget);
    expect(find.text('이동 단위:'), findsOneWidget);
  });
}
