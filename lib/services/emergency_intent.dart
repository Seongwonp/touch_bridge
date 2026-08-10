/// 비상 정지 관련 공용 유틸.
///
/// - [EmergencyIntent]: 모든 음성 화면에서 동일하게 쓰는 "즉시 중단" 발화 판별.
/// - [EmergencyStopOutcome]: 정지 명령 전송 결과를 사용자에게 정직하게 안내하기 위한 분류.
///   BLE write 성공이 곧 기기 정지 확인은 아니므로, 확인(acknowledged)과
///   전송(sent)을 분리해 문구를 다르게 준다.
library;

class EmergencyIntent {
  EmergencyIntent._();

  /// 어떤 흐름에서도 최우선 처리해야 하는 중단 발화 토큰.
  static const List<String> tokens = <String>[
    '멈춰',
    '멈춤',
    '정지',
    '그만',
    '중단',
    'stop',
  ];

  /// [text]에 중단 토큰이 포함되면 true.
  static bool matches(String text) {
    final lower = text.toLowerCase();
    return tokens.any(lower.contains);
  }
}

class EmergencyStopOutcome {
  const EmergencyStopOutcome({
    required this.acknowledged,
    required this.sent,
    required this.message,
  });

  /// 기기가 실제로 멈췄다는 확인(controller ACK)을 받았는가.
  final bool acknowledged;

  /// 중단 명령이 최소한 전송은 되었는가.
  final bool sent;

  /// 사용자에게 읽어줄 정직한 안내 문구.
  final String message;

  /// [BleService.sendEmergencyStop]가 반환하는 ACK 문자열을 결과로 변환한다.
  ///
  /// 안전장치: BLE notify 리스너는 정지 명령과 무관한 알림(센서값 등)도 같은
  /// completer로 흘려보낼 수 있으므로, "ERROR로 시작하지 않으면 성공"처럼
  /// 느슨하게 판정하면 무관한 알림을 "안전하게 멈췄음"으로 오판할 수 있다.
  /// 앱 전역에서 성공 판정에 쓰는 기존 컨벤션(`ble_service.dart`의
  /// `res.toLowerCase().contains('ok')`)과 동일하게, 명시적 성공 신호를
  /// 포함할 때만 확인(acknowledged) 처리한다.
  /// - `ERROR:NOT_CONNECTED`: 전송 자체가 불가.
  /// - `ERROR:TIMEOUT`: 전송은 됐으나 응답 미확인.
  /// - 그 외 `ERROR:*`: 전송 실패.
  /// - `ok`/`stop`/`touch_ok` 포함: controller가 정지를 확인한 것으로 처리.
  /// - 그 외(무관한 알림 등): 전송은 됐지만 확인되지 않음(성공으로 오판하지 않음).
  factory EmergencyStopOutcome.fromAck(String ack) {
    if (ack.startsWith('ERROR')) {
      switch (ack) {
        case 'ERROR:NOT_CONNECTED':
          return const EmergencyStopOutcome(
            acknowledged: false,
            sent: false,
            message: '연결된 기기가 없습니다. 기기 전원을 확인해 주세요.',
          );
        case 'ERROR:TIMEOUT':
          return const EmergencyStopOutcome(
            acknowledged: false,
            sent: true,
            message: '중단 명령을 보냈지만 응답을 확인하지 못했습니다. 기기 상태를 확인해 주세요.',
          );
        default:
          return const EmergencyStopOutcome(
            acknowledged: false,
            sent: false,
            message: '중단하지 못했습니다. 다시 시도해 주세요.',
          );
      }
    }

    final lower = ack.toLowerCase();
    final isExplicitSuccess = lower.contains('ok') || lower.contains('stop');
    if (isExplicitSuccess) {
      return const EmergencyStopOutcome(
        acknowledged: true,
        sent: true,
        message: '기기를 멈췄습니다. 안전합니다.',
      );
    }

    // 정지와 무관한 알림(센서값 등)일 수 있으므로 "확인됨"으로 단정하지 않는다.
    return const EmergencyStopOutcome(
      acknowledged: false,
      sent: true,
      message: '중단 명령을 보냈지만 응답을 확인하지 못했습니다. 기기 상태를 확인해 주세요.',
    );
  }
}
