import 'package:flutter_test/flutter_test.dart';

import 'package:touch_bridge/main.dart';

void main() {
  testWidgets('Touch Bridge home screen smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TouchBridgeApp());

    expect(find.text('Touch Bridge'), findsOneWidget);
    expect(find.text('내 기기'), findsOneWidget);
  });
}
