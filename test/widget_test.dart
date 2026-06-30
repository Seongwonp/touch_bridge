import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touch_bridge/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Touch Bridge home screen smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TouchBridgeApp());
    await tester.pumpAndSettle();

    expect(find.text('내 기기'), findsOneWidget);
  });
}
