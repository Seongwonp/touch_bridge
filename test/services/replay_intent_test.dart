import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/emergency_intent.dart';
import 'package:touch_bridge/services/help_intent.dart';
import 'package:touch_bridge/services/replay_intent.dart';

void main() {
  group('ReplayIntent.matches', () {
    test('다시 듣기 요청 발화를 인식한다', () {
      for (final phrase in [
        '다시 말해줘',
        '다시 말해',
        '다시 들려줘',
        '뭐라고',
        '안 들려',
        '못 들었어',
        '한 번 더 말해줘',
      ]) {
        expect(ReplayIntent.matches(phrase), isTrue, reason: phrase);
      }
    });

    test('일반 명령·잡담은 인식하지 않는다', () {
      expect(ReplayIntent.matches('30초 시작'), isFalse);
      expect(ReplayIntent.matches('전자레인지 켜줘'), isFalse);
    });

    test('EmergencyIntent/HelpIntent와 토큰이 겹치지 않는다', () {
      // 세 인텐트가 뚜렷이 구분돼야 어느 쪽으로 갈지 헷갈리지 않는다.
      // (호출 순서상 Emergency→Help→Replay이므로 겹쳐도 안전하지만,
      // 토큰 자체가 겹치면 의도가 흐려진다.)
      for (final token in ReplayIntent.tokens) {
        expect(EmergencyIntent.matches(token), isFalse, reason: token);
        expect(HelpIntent.matches(token), isFalse, reason: token);
      }
    });
  });
}
