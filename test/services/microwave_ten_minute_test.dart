import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/voice/voice_listening_screen.dart';
import 'package:touch_bridge/services/microwave_command_service.dart';

void main() {
  test('"10분 돌려줘"는 10분 버튼과 시작을 누르는 명령이다', () {
    for (final t in ['10분 돌려줘', '10분 돌려 줘', '십분 데워줘', '10분 시작']) {
      final r = MicrowaveCommandService.checkSimpleRules(t);
      expect(r, isNotNull, reason: t);
      expect(r!['commands'], ['BT-10', 'BT-05'], reason: t);
      expect(r['message'], '10분 조리를 시작합니다.');
    }
    expect(MicrowaveCommandService.calculateSeconds(['BT-10', 'BT-05']), 600);
  });

  test('부분 일치로 10분 규칙이 걸리지 않는다', () {
    expect(MicrowaveCommandService.checkSimpleRules('110분 돌려줘'), isNull);
    expect(MicrowaveCommandService.checkSimpleRules('10분 돌려주지마'), isNull);
  });

  test('누르는 중 안내는 버튼 이름을 말한다', () {
    expect(VoiceListeningScreenState.pressingLabelForSequence(['BT-10', 'BT-05']),
        '10분, 시작 버튼을 누르는 중입니다.');
    expect(VoiceListeningScreenState.pressingLabelForSequence(['BT-W01', 'BT-W02']),
        '버튼 2개를 누르는 중입니다.');
  });
}
