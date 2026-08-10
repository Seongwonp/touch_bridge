import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/microwave_command_service.dart';

void main() {
  group('MicrowaveCommandService.checkSimpleRules', () {
    test('30초 시작 명령을 규칙으로 처리한다', () {
      final result = MicrowaveCommandService.checkSimpleRules('30초 시작');
      expect(result, isNotNull);
      expect(result!['action'], 'MICROWAVE_CONTROL');
      expect(result['commands'], ['BT-02', 'BT-05']);
    });

    test('취소 명령을 규칙으로 처리한다', () {
      final result = MicrowaveCommandService.checkSimpleRules('지금 취소해줘');
      expect(result, isNotNull);
      expect(result!['commands'], ['BT-06']);
    });

    test('매칭되지 않으면 null 반환', () {
      final result = MicrowaveCommandService.checkSimpleRules('오늘 날씨 어때');
      expect(result, isNull);
    });
  });

  group('MicrowaveCommandService.calculateSeconds', () {
    test('버튼 시퀀스에서 총 시간을 계산한다', () {
      final seconds = MicrowaveCommandService.calculateSeconds(['BT-03', 'BT-03', 'BT-02', 'BT-05']);
      expect(seconds, 150);
    });

    test('시간 버튼 외 명령은 시간에 포함하지 않는다', () {
      final seconds = MicrowaveCommandService.calculateSeconds(['BT-06']);
      expect(seconds, 0);
    });
  });

  group('MicrowaveCommandService.btnToGrid', () {
    test('버튼을 3x3 좌표로 매핑한다', () {
      expect(MicrowaveCommandService.btnToGrid('BT-01'), (0, 0));
      expect(MicrowaveCommandService.btnToGrid('BT-05'), (1, 1));
      expect(MicrowaveCommandService.btnToGrid('BT-09'), (2, 2));
    });

    test('알 수 없는 버튼은 null 반환', () {
      expect(MicrowaveCommandService.btnToGrid('BT-99'), isNull);
    });
  });

  group('MicrowaveCommandService.buildStartSequence', () {
    test('숫자 패드로 입력한 시간을 프리셋 버튼 조합으로 변환한다', () {
      // 이 기기는 숫자 키패드가 물리적으로 없고 프리셋(10/30/60/300초) 버튼만
      // 있으므로, 앱에서 입력한 임의의 시간도 반드시 프리셋 조합으로 눌러야 한다.
      final r = MicrowaveCommandService.buildStartSequence(90);
      expect(r.actualSeconds, 90);
      expect(r.buttons.last, 'BT-05'); // 항상 시작으로 끝난다
      expect(
        MicrowaveCommandService.calculateSeconds(r.buttons),
        90,
      ); // 실제로 눌리는 버튼 합이 목표 시간과 일치
    });

    test('10초 단위가 아니면 가장 가까운 10초로 반올림한다', () {
      final r = MicrowaveCommandService.buildStartSequence(95);
      expect(r.actualSeconds, 100);
    });

    test('0초 이하는 시작 버튼만 반환한다', () {
      final r = MicrowaveCommandService.buildStartSequence(0);
      expect(r.buttons, ['BT-05']);
      expect(r.actualSeconds, 0);
    });
  });
}
