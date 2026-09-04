import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/mapping/photo_mapping_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('작은 화면에서도 원점 설정과 검증 기록 진입점을 제공한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: PhotoMappingScreen(deviceId: 'test-device')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('검증 전 원점 설정'), findsOneWidget);
    expect(find.text('아직 저장된 위치 검증 결과가 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('아직 저장된 위치 검증 결과가 없습니다.'));
    await tester.pumpAndSettle();

    expect(find.text('최근 위치 검증 기록'), findsOneWidget);
    expect(find.text('아직 기록이 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
