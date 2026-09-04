import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/esp32_motion_protocol.dart';
import 'package:touch_bridge/services/motion_controller.dart';

void main() {
  group('Esp32MotionController 안전 상태 머신', () {
    test('홈 완료 전에는 이동 명령 자체를 보내지 않는다', () async {
      final transport = _FakeMotionTransport();
      final controller = Esp32MotionController(
        transport: transport,
        commandIdFactory: () => 'move-1',
      );

      final result = await controller.moveTo(
        deviceId: 'device-1',
        xMm: 10,
        yMm: 20,
        toleranceMm: 0.7,
      );

      expect(result.ok, isFalse);
      expect(result.failure, MotionFailure.notHomed);
      expect(transport.sent, isEmpty);
    });

    test('RECEIVED-HOMING-HOMED-COMPLETED 뒤에만 홈 완료가 된다', () async {
      final transport = _FakeMotionTransport()
        ..onSend = (command, emit) {
          emit(_status(command, Esp32MotionState.received));
          emit(_status(command, Esp32MotionState.homing));
          emit(_status(command, Esp32MotionState.homed, homed: true));
          emit(_status(command, Esp32MotionState.completed, homed: true));
        };
      final controller = Esp32MotionController(
        transport: transport,
        commandIdFactory: () => 'home-1',
      );

      final result = await controller.home(deviceId: 'device-1');

      expect(result.ok, isTrue);
      expect(controller.isHomed, isTrue);
    });

    test('상태 순서가 잘못되면 프로토콜 오류이며 홈 완료로 보지 않는다', () async {
      final transport = _FakeMotionTransport()
        ..onSend = (command, emit) {
          emit(_status(command, Esp32MotionState.received));
          emit(_status(command, Esp32MotionState.completed, homed: true));
        };
      final controller = Esp32MotionController(
        transport: transport,
        commandIdFactory: () => 'home-bad',
      );

      final result = await controller.home(deviceId: 'device-1');

      expect(result.failure, MotionFailure.protocol);
      expect(controller.isHomed, isFalse);
    });

    test('다른 commandId 응답은 무시하고 자기 명령 상태만 사용한다', () async {
      var id = 0;
      final transport = _FakeMotionTransport()
        ..onSend = (command, emit) {
          emit(
            const Esp32MotionStatus(
              commandId: 'unrelated',
              state: Esp32MotionState.errorStall,
            ),
          );
          emit(_status(command, Esp32MotionState.received));
          emit(_status(command, Esp32MotionState.homing));
          emit(_status(command, Esp32MotionState.homed, homed: true));
          emit(_status(command, Esp32MotionState.completed, homed: true));
        };
      final controller = Esp32MotionController(
        transport: transport,
        commandIdFactory: () => 'cmd-${++id}',
      );

      final result = await controller.home(deviceId: 'device-1');

      expect(result.ok, isTrue);
    });

    test('스톨이나 연결 끊김 뒤에는 홈 상태를 폐기한다', () async {
      var call = 0;
      final transport = _FakeMotionTransport()
        ..onSend = (command, emit) {
          call++;
          if (call == 1) {
            emit(_status(command, Esp32MotionState.received));
            emit(_status(command, Esp32MotionState.homing));
            emit(_status(command, Esp32MotionState.homed, homed: true));
            emit(_status(command, Esp32MotionState.completed, homed: true));
          } else {
            emit(_status(command, Esp32MotionState.received));
            emit(_status(command, Esp32MotionState.moving));
            emit(_status(command, Esp32MotionState.errorStall));
          }
        };
      final controller = Esp32MotionController(transport: transport);
      expect((await controller.home(deviceId: 'device-1')).ok, isTrue);

      final result = await controller.moveTo(
        deviceId: 'device-1',
        xMm: 1,
        yMm: 1,
        toleranceMm: 0.7,
      );

      expect(result.failure, MotionFailure.stall);
      expect(controller.isHomed, isFalse);
    });
  });

  group('SafePressCoordinator', () {
    test('허용 오차 내 POSITIONED와 토큰이 확인돼야 스위치봇을 누른다', () async {
      var call = 0;
      final transport = _FakeMotionTransport()
        ..onSend = (command, emit) {
          call++;
          emit(_status(command, Esp32MotionState.received));
          if (command.action == Esp32MotionAction.home) {
            emit(_status(command, Esp32MotionState.homing));
            emit(_status(command, Esp32MotionState.homed, homed: true));
            emit(_status(command, Esp32MotionState.completed, homed: true));
          } else if (command.action == Esp32MotionAction.moveOnly) {
            emit(_status(command, Esp32MotionState.moving));
            emit(
              _status(
                command,
                Esp32MotionState.positioned,
                errorMm: 0.3,
                positionToken: 'verified-position',
              ),
            );
            emit(_status(command, Esp32MotionState.completed));
          } else {
            emit(_status(command, Esp32MotionState.pressing));
            emit(_status(command, Esp32MotionState.completed));
          }
        };
      final controller = Esp32MotionController(transport: transport);
      final actuator = Esp32SwitchBotActuator(transport: transport);
      final coordinator = SafePressCoordinator(
        motionController: controller,
        pressActuator: actuator,
      );
      await controller.home(deviceId: 'device-1');

      final result = await coordinator.moveAndPress(
        deviceId: 'device-1',
        xMm: 42.5,
        yMm: 18.25,
      );

      expect(result.ok, isTrue);
      expect(result.positionErrorMm, 0.3);
      expect(call, 3, reason: 'home + move_only + press 세 명령이어야 한다');
      expect(transport.sent.last.action, Esp32MotionAction.press);
      expect(transport.sent.last.positionToken, 'verified-position');
    });

    test('위치 오차가 허용값보다 크면 press 명령을 보내지 않는다', () async {
      final transport = _FakeMotionTransport()
        ..onSend = (command, emit) {
          emit(_status(command, Esp32MotionState.received));
          if (command.action == Esp32MotionAction.home) {
            emit(_status(command, Esp32MotionState.homing));
            emit(_status(command, Esp32MotionState.homed, homed: true));
            emit(_status(command, Esp32MotionState.completed, homed: true));
          } else {
            emit(_status(command, Esp32MotionState.moving));
            emit(
              _status(
                command,
                Esp32MotionState.positioned,
                errorMm: 1.1,
                positionToken: 'token',
              ),
            );
          }
        };
      final controller = Esp32MotionController(transport: transport);
      final coordinator = SafePressCoordinator(
        motionController: controller,
        pressActuator: Esp32SwitchBotActuator(transport: transport),
      );
      await controller.home(deviceId: 'device-1');

      final result = await coordinator.moveAndPress(
        deviceId: 'device-1',
        xMm: 10,
        yMm: 10,
      );

      expect(result.failure, MotionFailure.position);
      expect(
        transport.sent.where((c) => c.action == Esp32MotionAction.press),
        isEmpty,
      );
    });

    test('위치 토큰이 없으면 press 명령을 보내지 않는다', () async {
      final transport = _FakeMotionTransport()
        ..onSend = (command, emit) {
          emit(_status(command, Esp32MotionState.received));
          if (command.action == Esp32MotionAction.home) {
            emit(_status(command, Esp32MotionState.homing));
            emit(_status(command, Esp32MotionState.homed, homed: true));
            emit(_status(command, Esp32MotionState.completed, homed: true));
          } else {
            emit(_status(command, Esp32MotionState.moving));
            emit(_status(command, Esp32MotionState.positioned, errorMm: 0.1));
          }
        };
      final controller = Esp32MotionController(transport: transport);
      final coordinator = SafePressCoordinator(
        motionController: controller,
        pressActuator: Esp32SwitchBotActuator(transport: transport),
      );
      await controller.home(deviceId: 'device-1');

      final result = await coordinator.moveAndPress(
        deviceId: 'device-1',
        xMm: 10,
        yMm: 10,
      );

      expect(result.failure, MotionFailure.invalidPositionToken);
      expect(transport.sent, hasLength(2));
    });

    test('응답 시간초과 시 실패하며 press를 실행하지 않는다', () async {
      final transport = _FakeMotionTransport();
      final controller = Esp32MotionController(
        transport: transport,
        commandIdFactory: () => 'home-timeout',
      );

      final result = await controller.home(
        deviceId: 'device-1',
        timeout: const Duration(milliseconds: 10),
      );

      expect(result.failure, MotionFailure.timeout);
      expect(controller.isHomed, isFalse);
    });
  });
}

typedef _OnSend =
    void Function(
      Esp32MotionCommand command,
      void Function(Esp32MotionStatus status) emit,
    );

class _FakeMotionTransport implements MotionTransport {
  final _statuses = StreamController<Esp32MotionStatus>.broadcast(sync: true);
  final _connections = StreamController<bool>.broadcast(sync: true);
  final sent = <Esp32MotionCommand>[];
  bool connected = true;
  _OnSend? onSend;

  @override
  bool get isConnected => connected;

  @override
  Stream<bool> get connectionStates => _connections.stream;

  @override
  Stream<Esp32MotionStatus> get statuses => _statuses.stream;

  @override
  Future<bool> send(Esp32MotionCommand command) async {
    sent.add(command);
    onSend?.call(command, _statuses.add);
    return true;
  }

  @override
  Future<String> sendPriorityStop(String deviceId) async => 'STOPPED';
}

Esp32MotionStatus _status(
  Esp32MotionCommand command,
  Esp32MotionState state, {
  double? errorMm,
  String? positionToken,
  bool? homed,
}) => Esp32MotionStatus(
  commandId: command.commandId,
  state: state,
  errorMm: errorMm,
  positionToken: positionToken,
  homed: homed,
);
