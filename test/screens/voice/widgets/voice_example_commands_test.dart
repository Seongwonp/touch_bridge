import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/voice/widgets/voice_example_commands.dart';

/// 예시 칩은 가전 버튼을 누르는 물리 동작이다. 첫 탭(낭독기 두 번 탭 포함)에 실행되면
/// 칩을 훑어보던 시각장애인이 의도치 않게 가전을 작동시킨다.
void main() {
  late List<String> armed;
  late List<String> confirmed;

  setUp(() {
    armed = [];
    confirmed = [];
  });

  Widget wrap() => MaterialApp(
    home: Scaffold(
      body: VoiceExampleCommands(
        scale: 1,
        onArmed: armed.add,
        onConfirmed: confirmed.add,
      ),
    ),
  );

  Finder chipFinder() => find.bySemanticsLabel('예시 명령, 30초 돌려줘');

  testWidgets('첫 탭은 확인만 하고 실행하지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(chipFinder());
    await tester.pump();

    expect(armed, ['30초 돌려줘']);
    expect(confirmed, isEmpty);
  });

  testWidgets('같은 칩을 다시 탭하면 실행한다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(chipFinder());
    await tester.pump();
    await tester.tap(chipFinder());
    await tester.pump();

    expect(confirmed, ['30초 돌려줘']);
  });

  testWidgets('다른 칩을 탭하면 실행하지 않고 그 칩으로 확인을 옮긴다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(chipFinder());
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('예시 명령, 해동해줘'));
    await tester.pump();

    expect(armed, ['30초 돌려줘', '해동해줘']);
    expect(confirmed, isEmpty);
  });

  testWidgets('20초가 지나면 확인이 풀려 다시 탭해도 실행하지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(chipFinder());
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await tester.tap(chipFinder());
    await tester.pump();

    expect(confirmed, isEmpty);
    expect(armed, ['30초 돌려줘', '30초 돌려줘']);
  });

  testWidgets('낭독기의 두 번 탭(semantics tap)도 첫 번째는 확인만 한다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap());

    tester.semantics.tap(find.semantics.byLabel('예시 명령, 30초 돌려줘'));
    await tester.pump();
    expect(confirmed, isEmpty);
    expect(tester.getSemantics(chipFinder()).value, '한 번 더 누르면 실행');

    tester.semantics.tap(find.semantics.byLabel('예시 명령, 30초 돌려줘'));
    await tester.pump();
    expect(confirmed, ['30초 돌려줘']);

    handle.dispose();
  });

  testWidgets('칩 높이는 48dp 이상이다', (tester) async {
    await tester.pumpWidget(wrap());
    expect(tester.getSize(chipFinder()).height, greaterThanOrEqualTo(48));
  });
}
