import 'dart:async';

import 'app_logger.dart';
import 'ble_service.dart';
import 'esp32_motion_protocol.dart';

enum MotionFailure {
  none,
  notConnected,
  notHomed,
  invalidTarget,
  sendFailed,
  position,
  stall,
  press,
  limit,
  timeout,
  invalidPositionToken,
  protocol,
  disconnected,
  stopped,
}

class MotionOutcome {
  const MotionOutcome({
    required this.ok,
    required this.commandId,
    required this.message,
    this.failure = MotionFailure.none,
    this.positionErrorMm,
    this.positionToken,
  });

  final bool ok;
  final String commandId;
  final String message;
  final MotionFailure failure;
  final double? positionErrorMm;
  final String? positionToken;
}

abstract interface class MotionTransport {
  bool get isConnected;
  Stream<bool> get connectionStates;
  Stream<Esp32MotionStatus> get statuses;
  Future<bool> send(Esp32MotionCommand command);
  Future<String> sendPriorityStop(String deviceId);
}

abstract interface class MotionController {
  bool get isHomed;

  Future<MotionOutcome> home({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  });

  Future<MotionOutcome> moveTo({
    required String deviceId,
    required double xMm,
    required double yMm,
    required double toleranceMm,
    Duration timeout = const Duration(seconds: 15),
  });

  Future<MotionOutcome> emergencyStop({required String deviceId});
}

abstract interface class PressActuator {
  Future<MotionOutcome> press({
    required String deviceId,
    required String positionToken,
    Duration timeout = const Duration(seconds: 8),
  });
}

class BleMotionTransport implements MotionTransport {
  BleMotionTransport({BleService? ble}) : _ble = ble ?? BleService.instance;

  final BleService _ble;

  @override
  bool get isConnected => _ble.isConnected;

  @override
  Stream<bool> get connectionStates => _ble.isConnectedStream;

  @override
  Stream<Esp32MotionStatus> get statuses => _ble.responseStream
      .map(Esp32MotionStatus.tryParse)
      .where((status) => status != null)
      .cast<Esp32MotionStatus>();

  @override
  Future<bool> send(Esp32MotionCommand command) =>
      _ble.sendProtocolPayload(command.toJson());

  @override
  Future<String> sendPriorityStop(String deviceId) =>
      _ble.sendEmergencyStop(deviceId);
}

class Esp32MotionController implements MotionController {
  Esp32MotionController({
    required MotionTransport transport,
    String Function()? commandIdFactory,
  }) : _transport = transport,
       _commandIdFactory = commandIdFactory ?? _defaultCommandId;

  final MotionTransport _transport;
  final String Function() _commandIdFactory;
  bool _isHomed = false;
  Future<void> _operationTail = Future<void>.value();

  @override
  bool get isHomed => _isHomed;

  static int _sequence = 0;
  static String _defaultCommandId() {
    _sequence++;
    return 'cmd-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$_sequence';
  }

  Future<T> _serialized<T>(Future<T> Function() body) {
    final previous = _operationTail;
    final release = Completer<void>();
    _operationTail = release.future;
    return previous.then((_) => body()).whenComplete(release.complete);
  }

  @override
  Future<MotionOutcome> home({
    required String deviceId,
    Duration timeout = const Duration(seconds: 20),
  }) => _serialized(() async {
    _isHomed = false;
    final command = Esp32MotionCommand(
      commandId: _commandIdFactory(),
      action: Esp32MotionAction.home,
      deviceId: deviceId,
    );
    final trace = _MotionTrace.home();
    final result = await _execute(command, trace: trace, timeout: timeout);
    if (result.ok) _isHomed = true;
    return result;
  });

  @override
  Future<MotionOutcome> moveTo({
    required String deviceId,
    required double xMm,
    required double yMm,
    required double toleranceMm,
    Duration timeout = const Duration(seconds: 15),
  }) => _serialized(() async {
    final commandId = _commandIdFactory();
    if (!_transport.isConnected) {
      _isHomed = false;
      return _failure(commandId, MotionFailure.notConnected);
    }
    if (!_isHomed) return _failure(commandId, MotionFailure.notHomed);
    if (!xMm.isFinite ||
        !yMm.isFinite ||
        xMm < 0 ||
        yMm < 0 ||
        !toleranceMm.isFinite ||
        toleranceMm <= 0) {
      return _failure(commandId, MotionFailure.invalidTarget);
    }

    final command = Esp32MotionCommand(
      commandId: commandId,
      action: Esp32MotionAction.moveOnly,
      deviceId: deviceId,
      xMm: xMm,
      yMm: yMm,
      toleranceMm: toleranceMm,
    );
    final trace = _MotionTrace.move(toleranceMm);
    final result = await _execute(command, trace: trace, timeout: timeout);
    if (result.failure == MotionFailure.disconnected ||
        result.failure == MotionFailure.limit ||
        result.failure == MotionFailure.stall) {
      _isHomed = false;
    }
    return result;
  });

  @override
  Future<MotionOutcome> emergencyStop({required String deviceId}) async {
    final commandId = _commandIdFactory();
    _isHomed = false;
    final response = await _transport.sendPriorityStop(deviceId);
    final upper = response.toUpperCase();
    final ok =
        !upper.startsWith('ERROR:') &&
        (upper.contains('OK') ||
            upper.contains('STOPPED') ||
            upper.contains('COMPLETED'));
    return MotionOutcome(
      ok: ok,
      commandId: commandId,
      failure: ok ? MotionFailure.none : _failureFromAck(upper),
      message: ok ? '비상 정지가 확인되었습니다.' : '비상 정지를 확인하지 못했습니다.',
    );
  }

  Future<MotionOutcome> _execute(
    Esp32MotionCommand command, {
    required _MotionTrace trace,
    required Duration timeout,
  }) async {
    if (!_transport.isConnected) {
      _isHomed = false;
      return _failure(command.commandId, MotionFailure.notConnected);
    }

    final completer = Completer<MotionOutcome>();
    late final StreamSubscription<Esp32MotionStatus> statusSub;
    late final StreamSubscription<bool> connectionSub;
    statusSub = _transport.statuses.listen((status) {
      if (completer.isCompleted || status.commandId != command.commandId) {
        return;
      }
      final outcome = trace.accept(status, command.commandId);
      if (outcome != null) completer.complete(outcome);
    });
    connectionSub = _transport.connectionStates.listen((connected) {
      if (!connected && !completer.isCompleted) {
        _isHomed = false;
        completer.complete(
          _failure(command.commandId, MotionFailure.disconnected),
        );
      }
    });

    try {
      final sent = await _transport.send(command);
      if (!sent) return _failure(command.commandId, MotionFailure.sendFailed);
      return await completer.future.timeout(
        timeout,
        onTimeout: () => _failure(command.commandId, MotionFailure.timeout),
      );
    } finally {
      await statusSub.cancel();
      await connectionSub.cancel();
    }
  }
}

class Esp32SwitchBotActuator implements PressActuator {
  Esp32SwitchBotActuator({
    required MotionTransport transport,
    String Function()? commandIdFactory,
  }) : _transport = transport,
       _commandIdFactory =
           commandIdFactory ?? Esp32MotionController._defaultCommandId;

  final MotionTransport _transport;
  final String Function() _commandIdFactory;

  @override
  Future<MotionOutcome> press({
    required String deviceId,
    required String positionToken,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final commandId = _commandIdFactory();
    if (!_transport.isConnected) {
      return _failure(commandId, MotionFailure.notConnected);
    }
    if (positionToken.trim().isEmpty) {
      return _failure(commandId, MotionFailure.invalidPositionToken);
    }
    final command = Esp32MotionCommand(
      commandId: commandId,
      action: Esp32MotionAction.press,
      deviceId: deviceId,
      positionToken: positionToken,
    );
    final completer = Completer<MotionOutcome>();
    final trace = _MotionTrace.press();
    late final StreamSubscription<Esp32MotionStatus> statusSub;
    late final StreamSubscription<bool> connectionSub;
    statusSub = _transport.statuses.listen((status) {
      if (completer.isCompleted || status.commandId != commandId) return;
      final outcome = trace.accept(status, commandId);
      if (outcome != null) completer.complete(outcome);
    });
    connectionSub = _transport.connectionStates.listen((connected) {
      if (!connected && !completer.isCompleted) {
        completer.complete(_failure(commandId, MotionFailure.disconnected));
      }
    });
    try {
      if (!await _transport.send(command)) {
        return _failure(commandId, MotionFailure.sendFailed);
      }
      return await completer.future.timeout(
        timeout,
        onTimeout: () => _failure(commandId, MotionFailure.timeout),
      );
    } finally {
      await statusSub.cancel();
      await connectionSub.cancel();
    }
  }
}

class SafePressCoordinator {
  SafePressCoordinator({
    required MotionController motionController,
    required PressActuator pressActuator,
  }) : _motionController = motionController,
       _pressActuator = pressActuator;

  final MotionController _motionController;
  final PressActuator _pressActuator;
  Future<void> _operationTail = Future<void>.value();

  Future<MotionOutcome> moveAndPress({
    required String deviceId,
    required double xMm,
    required double yMm,
    double toleranceMm = 0.7,
  }) {
    final previous = _operationTail;
    final release = Completer<void>();
    _operationTail = release.future;
    return previous
        .then((_) async {
          if (!_motionController.isHomed) {
            return _failure('', MotionFailure.notHomed);
          }
          final positioned = await _motionController.moveTo(
            deviceId: deviceId,
            xMm: xMm,
            yMm: yMm,
            toleranceMm: toleranceMm,
          );
          if (!positioned.ok) return positioned;
          final error = positioned.positionErrorMm;
          final token = positioned.positionToken;
          if (error == null || error > toleranceMm) {
            return _failure(positioned.commandId, MotionFailure.position);
          }
          if (token == null || token.isEmpty) {
            return _failure(
              positioned.commandId,
              MotionFailure.invalidPositionToken,
            );
          }
          final pressed = await _pressActuator.press(
            deviceId: deviceId,
            positionToken: token,
          );
          if (!pressed.ok) return pressed;
          return MotionOutcome(
            ok: true,
            commandId: pressed.commandId,
            message: pressed.message,
            positionErrorMm: error,
            positionToken: token,
          );
        })
        .whenComplete(release.complete);
  }
}

class _MotionTrace {
  _MotionTrace._(this.kind, this.toleranceMm);

  factory _MotionTrace.home() => _MotionTrace._(_TraceKind.home, null);
  factory _MotionTrace.move(double toleranceMm) =>
      _MotionTrace._(_TraceKind.move, toleranceMm);
  factory _MotionTrace.press() => _MotionTrace._(_TraceKind.press, null);

  final _TraceKind kind;
  final double? toleranceMm;
  Esp32MotionState? _last;
  bool _sawHomed = false;
  bool _sawPositioned = false;
  bool _sawPressing = false;
  double? _positionErrorMm;
  String? _positionToken;

  MotionOutcome? accept(Esp32MotionStatus status, String commandId) {
    if (!_validTransition(_last, status.state)) {
      return _failure(commandId, MotionFailure.protocol);
    }
    _last = status.state;
    if (status.state == Esp32MotionState.homed || status.homed == true) {
      _sawHomed = true;
    }
    if (status.state == Esp32MotionState.positioned) {
      _sawPositioned = true;
      _positionErrorMm = status.errorMm;
      _positionToken = status.positionToken;
      if (_positionErrorMm == null ||
          _positionErrorMm! > (toleranceMm ?? double.infinity) ||
          _positionToken == null) {
        return _failure(
          commandId,
          _positionErrorMm == null ||
                  _positionErrorMm! > (toleranceMm ?? double.infinity)
              ? MotionFailure.position
              : MotionFailure.invalidPositionToken,
        );
      }
    }
    if (status.state == Esp32MotionState.pressing) _sawPressing = true;

    if (status.state.isError || status.state == Esp32MotionState.stopped) {
      return _failure(commandId, _failureFromState(status.state));
    }
    if (status.state != Esp32MotionState.completed) return null;

    final valid = switch (kind) {
      _TraceKind.home => _sawHomed,
      _TraceKind.move => _sawPositioned,
      _TraceKind.press => _sawPressing,
    };
    if (!valid) return _failure(commandId, MotionFailure.protocol);
    return MotionOutcome(
      ok: true,
      commandId: commandId,
      message: switch (kind) {
        _TraceKind.home => '원점 설정이 확인되었습니다.',
        _TraceKind.move => '위치 이동이 확인되었습니다.',
        _TraceKind.press => '버튼 누름이 확인되었습니다.',
      },
      positionErrorMm: _positionErrorMm,
      positionToken: _positionToken,
    );
  }

  bool _validTransition(Esp32MotionState? from, Esp32MotionState to) {
    if (to.isError || to == Esp32MotionState.stopped) return true;
    if (from == to) return true;
    if (from == null) return to == Esp32MotionState.received;
    return switch (from) {
      Esp32MotionState.received => switch (kind) {
        _TraceKind.home => to == Esp32MotionState.homing,
        _TraceKind.move => to == Esp32MotionState.moving,
        _TraceKind.press => to == Esp32MotionState.pressing,
      },
      Esp32MotionState.homing => to == Esp32MotionState.homed,
      Esp32MotionState.homed => to == Esp32MotionState.completed,
      Esp32MotionState.moving => to == Esp32MotionState.positioned,
      Esp32MotionState.positioned => to == Esp32MotionState.completed,
      Esp32MotionState.pressing => to == Esp32MotionState.completed,
      _ => false,
    };
  }
}

enum _TraceKind { home, move, press }

MotionFailure _failureFromState(Esp32MotionState state) {
  return switch (state) {
    Esp32MotionState.errorNotHomed => MotionFailure.notHomed,
    Esp32MotionState.errorPosition => MotionFailure.position,
    Esp32MotionState.errorStall => MotionFailure.stall,
    Esp32MotionState.errorPress => MotionFailure.press,
    Esp32MotionState.errorLimit => MotionFailure.limit,
    Esp32MotionState.errorTimeout => MotionFailure.timeout,
    Esp32MotionState.errorInvalidToken => MotionFailure.invalidPositionToken,
    Esp32MotionState.stopped => MotionFailure.stopped,
    _ => MotionFailure.protocol,
  };
}

MotionFailure _failureFromAck(String response) {
  if (response.contains('NOT_CONNECTED')) return MotionFailure.notConnected;
  if (response.contains('TIMEOUT')) return MotionFailure.timeout;
  if (response.contains('WRITE_FAILED')) return MotionFailure.sendFailed;
  return MotionFailure.protocol;
}

MotionOutcome _failure(String commandId, MotionFailure failure) {
  final message = switch (failure) {
    MotionFailure.notConnected ||
    MotionFailure.disconnected => '기기 연결이 끊겼습니다. 다시 연결하고 원점 설정을 해 주세요.',
    MotionFailure.notHomed => '원점 설정이 끝나지 않아 이동하지 않았습니다.',
    MotionFailure.invalidTarget => '안전하지 않은 위치 값이라 이동하지 않았습니다.',
    MotionFailure.position => '목표 위치 오차가 커서 버튼을 누르지 않았습니다.',
    MotionFailure.stall => '모터 걸림이 감지되어 동작을 중단했습니다.',
    MotionFailure.press => '누름 장치 오류로 버튼을 누르지 못했습니다.',
    MotionFailure.limit => '이동 중 안전 한계가 감지되어 중단했습니다.',
    MotionFailure.timeout => '기기 응답 시간이 초과되어 동작을 중단했습니다.',
    MotionFailure.invalidPositionToken => '위치 확인 정보가 없어 버튼을 누르지 않았습니다.',
    MotionFailure.stopped => '비상 정지로 동작이 중단되었습니다.',
    MotionFailure.sendFailed => '명령을 보내지 못했습니다. 연결을 확인해 주세요.',
    MotionFailure.protocol => '기기 상태 응답을 확인할 수 없어 동작을 중단했습니다.',
    MotionFailure.none => '',
  };
  AppLogger.warn('motion.command.failed', {
    'command_id': commandId,
    'failure': failure.name,
  });
  return MotionOutcome(
    ok: false,
    commandId: commandId,
    failure: failure,
    message: message,
  );
}
