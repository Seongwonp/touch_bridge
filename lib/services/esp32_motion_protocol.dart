import 'dart:convert';

import 'hardware_protocol.dart';

enum Esp32MotionAction {
  home('home'),
  moveOnly('move_only'),
  press('press'),
  stop('stop'),
  status('status');

  const Esp32MotionAction(this.wireName);
  final String wireName;
}

enum Esp32MotionState {
  received,
  homing,
  homed,
  moving,
  positioned,
  pressing,
  completed,
  stopped,
  errorNotHomed,
  errorPosition,
  errorStall,
  errorPress,
  errorLimit,
  errorTimeout,
  errorInvalidToken,
  errorProtocol;

  bool get isError => name.startsWith('error');

  bool get isTerminal => this == completed || this == stopped || isError;

  static Esp32MotionState? fromWire(String value) {
    final normalized = value.trim().toUpperCase();
    for (final state in values) {
      if (_wireStateName(state) == normalized) return state;
    }
    return null;
  }
}

String _wireStateName(Esp32MotionState state) {
  switch (state) {
    case Esp32MotionState.received:
      return 'RECEIVED';
    case Esp32MotionState.homing:
      return 'HOMING';
    case Esp32MotionState.homed:
      return 'HOMED';
    case Esp32MotionState.moving:
      return 'MOVING';
    case Esp32MotionState.positioned:
      return 'POSITIONED';
    case Esp32MotionState.pressing:
      return 'PRESSING';
    case Esp32MotionState.completed:
      return 'COMPLETED';
    case Esp32MotionState.stopped:
      return 'STOPPED';
    case Esp32MotionState.errorNotHomed:
      return 'ERROR_NOT_HOMED';
    case Esp32MotionState.errorPosition:
      return 'ERROR_POSITION';
    case Esp32MotionState.errorStall:
      return 'ERROR_STALL';
    case Esp32MotionState.errorPress:
      return 'ERROR_PRESS';
    case Esp32MotionState.errorLimit:
      return 'ERROR_LIMIT';
    case Esp32MotionState.errorTimeout:
      return 'ERROR_TIMEOUT';
    case Esp32MotionState.errorInvalidToken:
      return 'ERROR_INVALID_TOKEN';
    case Esp32MotionState.errorProtocol:
      return 'ERROR_PROTOCOL';
  }
}

class Esp32MotionCommand {
  const Esp32MotionCommand({
    required this.commandId,
    required this.action,
    required this.deviceId,
    this.xMm,
    this.yMm,
    this.toleranceMm,
    this.positionToken,
  });

  final String commandId;
  final Esp32MotionAction action;
  final String deviceId;
  final double? xMm;
  final double? yMm;
  final double? toleranceMm;
  final String? positionToken;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'version': HardwareProtocol.motionProtocolVersion,
      'commandId': commandId,
      'action': action.wireName,
      'deviceId': deviceId,
    };
    if (xMm != null && yMm != null) {
      json['target'] = {'xMm': xMm, 'yMm': yMm};
    }
    if (toleranceMm != null) json['toleranceMm'] = toleranceMm;
    if (action == Esp32MotionAction.press) {
      json['pressActuator'] = 'switchbot';
      json['positionToken'] = positionToken;
    }
    return json;
  }

  String encode() => jsonEncode(toJson());
}

class Esp32MotionStatus {
  const Esp32MotionStatus({
    required this.commandId,
    required this.state,
    this.xMm,
    this.yMm,
    this.errorMm,
    this.positionToken,
    this.homed,
    this.message,
  });

  final String commandId;
  final Esp32MotionState state;
  final double? xMm;
  final double? yMm;
  final double? errorMm;
  final String? positionToken;
  final bool? homed;
  final String? message;

  static Esp32MotionStatus? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != HardwareProtocol.motionProtocolVersion) {
        return null;
      }
      final commandId = decoded['commandId'];
      final stateRaw = decoded['state'];
      if (commandId is! String ||
          commandId.trim().isEmpty ||
          stateRaw is! String) {
        return null;
      }
      final state = Esp32MotionState.fromWire(stateRaw);
      if (state == null) return null;

      double? number(Object? value) {
        if (value is! num) return null;
        final result = value.toDouble();
        return result.isFinite ? result : null;
      }

      final position = decoded['position'];
      final positionMap = position is Map<String, dynamic> ? position : null;
      final errorMm = number(decoded['errorMm']);
      if (decoded.containsKey('errorMm') && (errorMm == null || errorMm < 0)) {
        return null;
      }
      final token = decoded['positionToken'];
      final message = decoded['message'];
      return Esp32MotionStatus(
        commandId: commandId,
        state: state,
        xMm: number(positionMap?['xMm']),
        yMm: number(positionMap?['yMm']),
        errorMm: errorMm,
        positionToken: token is String && token.isNotEmpty ? token : null,
        homed: decoded['homed'] is bool ? decoded['homed'] as bool : null,
        message: message is String ? message : null,
      );
    } catch (_) {
      return null;
    }
  }
}
