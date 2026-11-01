import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'ble_service.dart';

/// CT 센서로 추정한 가전 전원 상태.
enum PowerState { on, off, unknown }

@immutable
class PowerStatus {
  const PowerStatus(this.state, this.watts);

  static const unknown = PowerStatus(PowerState.unknown, null);

  final PowerState state;

  /// 5초 평균 전력 추정값. 모르는 상태에서는 null이며 0으로 대신하지 않는다.
  final double? watts;
}

/// 기기가 1초마다 보내는 `{"event":"power",...}` 줄의 최신 상태를 보관한다.
///
/// 참고 정보일 뿐이다. 안전 판단이나 동작 완료 판단에 쓰지 않는다.
class PowerStatusService {
  PowerStatusService({
    Stream<String>? lines,
    this.staleAfter = const Duration(seconds: 5),
  }) {
    _sub = (lines ?? BleService.instance.responseStream).listen(_onLine);
  }

  static final PowerStatusService instance = PowerStatusService();

  /// 이 시간 동안 유효한 전력 줄이 없으면 [PowerState.unknown]으로 돌아간다.
  final Duration staleAfter;

  final ValueNotifier<PowerStatus> _status = ValueNotifier(PowerStatus.unknown);
  late final StreamSubscription<String> _sub;
  Timer? _staleTimer;

  ValueListenable<PowerStatus> get status => _status;
  PowerState get state => _status.value.state;

  void _onLine(String line) {
    final parsed = parseLine(line);
    if (parsed == null) return; // 잘못된 줄은 신선도를 갱신하지 않는다.
    _status.value = parsed;
    _staleTimer?.cancel();
    _staleTimer = Timer(staleAfter, () => _status.value = PowerStatus.unknown);
  }

  /// 전력 이벤트 한 줄을 읽는다. 다른 줄이거나 형식이 틀리면 null이다.
  @visibleForTesting
  static PowerStatus? parseLine(String line) {
    if (!BleService.isPowerEventLine(line)) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic> || decoded['event'] != 'power') {
      return null;
    }
    final w = decoded['w'];
    final state = switch (decoded['state']) {
      'on' => PowerState.on,
      'off' => PowerState.off,
      'unknown' => PowerState.unknown,
      _ => null,
    };
    if (state == null) return null;
    if (state == PowerState.unknown) return PowerStatus.unknown;
    if (w is! num || !w.isFinite || w < 0) return null;
    return PowerStatus(state, w.toDouble());
  }

  @visibleForTesting
  Future<void> dispose() async {
    _staleTimer?.cancel();
    await _sub.cancel();
    _status.dispose();
  }
}
