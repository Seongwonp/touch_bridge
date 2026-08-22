import 'package:flutter/foundation.dart';

/// 현재 작동 중인 기기의 카운트다운 상태를 앱 어디서든 조회할 수 있는 단일 저장소.
///
/// 남은 시간은 원래 EmergencyStopScreen의 로컬 상태여서, 다른 화면(음성 명령 등)
/// 에서 "얼마나 남았어?"에 답할 방법이 없었다. 카운트다운 화면이 이 서비스에
/// 상태를 보고하고, [StatusIntent]가 여기서 읽어 답한다.
class RunStatusService {
  RunStatusService._();
  static final RunStatusService instance = RunStatusService._();

  String? _deviceName;
  int _secondsLeft = 0;
  bool _running = false;

  bool get isRunning => _running;
  int get secondsLeft => _secondsLeft;
  String? get deviceName => _deviceName;

  /// 카운트다운 시작 보고 (EmergencyStopScreen initState).
  void start({required String deviceName, required int seconds}) {
    _deviceName = deviceName;
    _secondsLeft = seconds;
    _running = true;
  }

  /// 매 초 갱신 보고.
  void tick(int secondsLeft) {
    _secondsLeft = secondsLeft;
  }

  /// 종료 보고 — 정상 완료·비상 정지·화면 이탈 모두 여기로 온다.
  ///
  /// 주의: 화면 이탈(뒤로가기)은 "기기가 멈췄다"는 뜻이 아니지만, 앱이 더 이상
  /// 남은 시간을 추적하지 못하므로 "작동 중"이라고 단언하지 않는 것이 정직하다.
  void stop() {
    _running = false;
    _secondsLeft = 0;
  }

  @visibleForTesting
  void resetForTest() {
    _deviceName = null;
    _secondsLeft = 0;
    _running = false;
  }
}
