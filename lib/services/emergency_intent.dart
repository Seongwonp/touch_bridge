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
  ///
  /// 예외: "일시정지"는 세탁기 등의 **일시정지 버튼을 눌러 달라는 명령**이지
  /// 갠트리 비상 정지가 아니다. '정지' 토큰이 "일시정지"에 부분 매칭되어
  /// 세탁기 일시정지 요청이 항상 비상 정지로 가로채이던 충돌을 막기 위해,
  /// "일시정지" 표현을 제거한 뒤 토큰을 검사한다.
  /// ("일시정지 말고 다 멈춰"처럼 다른 중단 토큰이 함께 있으면 여전히 비상 정지.)
  static bool matches(String text) {
    final lower = text.toLowerCase().replaceAll(RegExp(r'일시\s*정지'), '');
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
  /// - `ERROR:NOT_CONNECTED`: 전송 자체가 불가.
  /// - `ERROR:TIMEOUT`: 전송은 됐으나 응답 미확인.
  /// - 그 외 `ERROR:*`: 전송 실패.
  /// - 단독 `ok`(정확 일치) 또는 `stop`으로 시작: controller가 정지를 확인한 것으로 처리.
  ///   "TEMP_OK", "SMOKE_OK" 등 센서 알림이 'ok'를 포함해도 오판하지 않도록
  ///   contains 대신 정확 일치(==)를 쓴다.
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
    // 단독 'ok' 정확 일치, 또는 'stop'으로 시작(stopped/stop_ok 등)만 정지 확인으로 인정.
    // contains('ok')는 "TEMP_OK", "SMOKE_OK" 등 무관한 센서 알림도 매칭하므로 사용하지 않는다.
    final isExplicitSuccess = lower == 'ok' || lower.startsWith('stop');
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
