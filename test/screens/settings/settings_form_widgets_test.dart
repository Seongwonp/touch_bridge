import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/settings/widgets/settings_form_widgets.dart';

/// 설정 컨트롤이 낭독기에서 이름과 현재 값을 함께 읽히는지 본다.
/// 이름 없이 "50%"나 "켜짐, 스위치"만 들리면 무엇을 바꾸는지 알 수 없다.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('슬라이더는 이름과 화면에 보이는 값 문구를 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        SliderRow(
          label: '말하기 속도',
          value: 0.5,
          min: 0,
          max: 1,
          display: '보통',
          onChanged: (_) {},
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(Slider));
    final data = node.getSemanticsData();
    expect(data.label, contains('말하기 속도'));
    expect(data.value, '보통');
    expect(node, isSemantics(isSlider: true));
    // 위의 글자 줄은 빼서 같은 이름을 두 번 읽지 않는다.
    expect(find.semantics.byLabel('말하기 속도'), findsOne);

    handle.dispose();
  });

  testWidgets('스위치는 제목과 켜짐 상태를 한 노드로 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        SwitchRow(
          title: '음성 안내',
          subtitle: '화면 내용을 소리로 알려 줍니다',
          value: true,
          onChanged: (_) {},
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(Switch));
    expect(node.getSemanticsData().label, contains('음성 안내'));
    expect(node, isSemantics(hasToggledState: true, isToggled: true));

    handle.dispose();
  });
}
