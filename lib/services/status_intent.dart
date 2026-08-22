import 'ble_service.dart';
import 'active_device_service.dart';
import 'run_status_service.dart';

/// "지금 뭐 해?", "얼마나 남았어?" 같은 상태 질의 발화 판별과 응답 생성.
///
/// 화면을 볼 수 없는 사용자에게 '현재 상태를 언제든 물어볼 수 있다'는 것은
/// 핵심 안심 장치다. 네트워크·AI 없이 로컬에서 즉시 답한다
/// (HelpIntent/ReplayIntent와 같은 로컬 인터셉트 계층).
class StatusIntent {
  StatusIntent._();

  /// 공백 제거 후 비교하는 상태 질의 토큰.
  /// '상태' 단독은 "일시정지 상태로 해줘" 같은 명령과 충돌할 수 있어
  /// 질문형 표현만 좁게 매칭한다.
  static const List<String> _tokens = <String>[
    '얼마나남',
    '남은시간',
    '몇분남',
    '몇초남',
    '지금뭐해',
    '지금뭐하고',
    '뭐하고있',
    '진행상황',
    '상태알려',
    '상태가어때',
    '상태어때',
    '작동중이야',
    '돌아가고있',
  ];

  static bool matches(String text) {
    final t = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return _tokens.any(t.contains);
  }

  static String _formatRemaining(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0 && s > 0) return '$m분 $s초';
    if (m > 0) return '$m분';
    return '$s초';
  }

  /// 순수 응답 생성 — 테스트 가능하도록 상태를 인자로 받는다.
  static String buildResponseFrom({
    required bool running,
    required int secondsLeft,
    String? runningDeviceName,
    required bool bleConnected,
    String? activeDeviceName,
  }) {
    if (running && secondsLeft > 0) {
      final name = runningDeviceName ?? '기기';
      return '$name가 작동 중이에요. ${_formatRemaining(secondsLeft)} 남았습니다.';
    }

    final buffer = StringBuffer('지금 작동 중인 기기는 없어요. ');
    if (activeDeviceName != null && activeDeviceName.isNotEmpty) {
      buffer.write('선택된 기기는 $activeDeviceName이고, ');
    } else {
      buffer.write('선택된 기기가 없고, ');
    }
    buffer.write(bleConnected ? '허브는 연결되어 있어요.' : '허브는 연결되어 있지 않아요.');
    return buffer.toString();
  }

  /// 현재 앱 상태에서 바로 응답을 만든다 (음성 화면에서 호출).
  static String buildResponse() {
    return buildResponseFrom(
      running: RunStatusService.instance.isRunning,
      secondsLeft: RunStatusService.instance.secondsLeft,
      runningDeviceName: RunStatusService.instance.deviceName,
      bleConnected: BleService.instance.isConnected,
      activeDeviceName: ActiveDeviceService.instance.getActiveDeviceName(),
    );
  }
}
