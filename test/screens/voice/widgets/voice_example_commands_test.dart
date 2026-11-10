import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/voice/widgets/voice_example_commands.dart';

/// 예시 칩은 문장을 명령으로 보낼 뿐이다. 가전을 누르기 전 확인은 음성 화면의
/// '실행'·'취소'가 맡으므로, 칩은 한 번 눌러 바로 보낸다(확인이 겹치지 않게).
void main() {
  late List<String> selected;

  setUp(() => selected = []);

  Widget wrap() => MaterialApp(
    home: Scaffold(
      body: VoiceExampleCommands(scale: 1, onSelected: selected.add),
    ),
  );

  Finder chipFinder() => find.bySemanticsLabel('예시 명령, 30초 돌려줘');

  testWidgets('한 번 탭하면 그 문장을 보낸다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(chipFinder());
    await tester.pump();
    expect(selected, ['30초 돌려줘']);
  });

  testWidgets('낭독기의 두 번 탭(semantics tap)도 한 번에 보낸다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap());
    tester.semantics.tap(find.semantics.byLabel('예시 명령, 30초 돌려줘'));
    await tester.pump();
    expect(selected, ['30초 돌려줘']);
    handle.dispose();
  });

  testWidgets('칩 높이는 48dp 이상이다', (tester) async {
    await tester.pumpWidget(wrap());
    expect(tester.getSize(chipFinder()).height, greaterThanOrEqualTo(48));
  });
}
