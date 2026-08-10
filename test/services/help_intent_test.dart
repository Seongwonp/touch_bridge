import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/emergency_intent.dart';
import 'package:touch_bridge/services/help_intent.dart';

void main() {
  group('HelpIntent.matches', () {
    test('도움말 요청 발화를 인식한다', () {
      for (final phrase in [
        '도움말',
        '뭐 할 수 있어',
        '뭐할수있어',
        '무엇을 할 수 있어',
        '뭐라고 말해야 돼',
        '사용법 알려줘',
        '명령어 알려줘',
        '도와줘',
        'help',
      ]) {
        expect(HelpIntent.matches(phrase), isTrue, reason: phrase);
      }
    });

    test('일반 명령·잡담은 인식하지 않는다', () {
      expect(HelpIntent.matches('30초 시작'), isFalse);
      expect(HelpIntent.matches('전자레인지 켜줘'), isFalse);
    });

    test('EmergencyIntent와 토큰이 겹치지 않는다', () {
      // 비상 인터셉터가 항상 먼저 체크되므로 겹쳐도 안전하지만, 두 인텐트가
      // 뚜렷이 구분돼야 어느 쪽으로 갈지 헷갈리지 않는다.
      for (final helpToken in HelpIntent.tokens) {
        expect(EmergencyIntent.matches(helpToken), isFalse, reason: helpToken);
      }
    });
  });

  group('HelpIntent.buildResponse', () {
    test('예시 명령과 비상 정지 사용법을 포함한다', () {
      final response = HelpIntent.buildResponse();
      expect(response, contains('멈춰'));
      expect(response, isNotEmpty);
    });

    test('exampleCount로 예시 개수를 조절할 수 있다', () {
      final short = HelpIntent.buildResponse(exampleCount: 1);
      final long = HelpIntent.buildResponse(exampleCount: 5);
      expect(long.length, greaterThan(short.length));
    });
  });
}
