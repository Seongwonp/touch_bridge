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
}
