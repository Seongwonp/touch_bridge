import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/esp32_motion_protocol.dart';

void main() {
  group('ESP32 모션 프로토콜 v2', () {
    test('move_only 명령에 버전, commandId, 목표 좌표와 허용 오차가 포함된다', () {
      const command = Esp32MotionCommand(
        commandId: 'move-1',
        action: Esp32MotionAction.moveOnly,
        deviceId: 'device-1',
        xMm: 42.5,
        yMm: 18.25,
        toleranceMm: 0.7,
      );

      expect(command.toJson(), {
        'version': 2,
        'commandId': 'move-1',
        'action': 'move_only',
        'deviceId': 'device-1',
        'target': {'xMm': 42.5, 'yMm': 18.25},
        'toleranceMm': 0.7,
      });
    });

    test('press 명령은 스위치봇과 위치 확인 토큰을 요구하는 형식이다', () {
      const command = Esp32MotionCommand(
        commandId: 'press-1',
        action: Esp32MotionAction.press,
        deviceId: 'device-1',
        positionToken: 'position-token',
      );

      expect(command.toJson()['pressActuator'], 'switchbot');
      expect(command.toJson()['positionToken'], 'position-token');
    });

    test('정상 POSITIONED 응답을 파싱한다', () {
      final status = Esp32MotionStatus.tryParse('''
        {"version":2,"commandId":"move-1","state":"POSITIONED",
         "position":{"xMm":42.4,"yMm":18.2},"errorMm":0.12,
         "positionToken":"token-1","homed":true}
      ''');

      expect(status, isNotNull);
      expect(status!.state, Esp32MotionState.positioned);
      expect(status.errorMm, 0.12);
      expect(status.positionToken, 'token-1');
    });

    test('버전, 상태, commandId 또는 오차가 잘못되면 거부한다', () {
      expect(
        Esp32MotionStatus.tryParse(
          '{"version":1,"commandId":"x","state":"COMPLETED"}',
        ),
        isNull,
      );
      expect(
        Esp32MotionStatus.tryParse(
          '{"version":2,"commandId":"","state":"COMPLETED"}',
        ),
        isNull,
      );
      expect(
        Esp32MotionStatus.tryParse(
          '{"version":2,"commandId":"x","state":"UNKNOWN"}',
        ),
        isNull,
      );
      expect(
        Esp32MotionStatus.tryParse(
          '{"version":2,"commandId":"x","state":"POSITIONED","errorMm":-1}',
        ),
        isNull,
      );
    });
  });
}
