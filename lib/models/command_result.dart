/// 명령 실행 결과의 신뢰 단계.
///
/// BLE write 성공은 "기기가 실제로 확인했다"는 뜻이 아니다. 이 앱은 이 둘을
/// 구분해 사용자에게 정직하게 안내한다("전송했다" vs "확인했다").
enum CommandPhase {
  /// 사용자 입력을 인식해 처리를 시작함(아직 기기로 보내지 않음).
  received,

  /// 기기로 명령을 보냈지만 기기의 확인 응답은 받지 못함. 현재 앱에서
  /// 가장 흔한 경우다 — raw G-code 전송 경로는 GRBL 확인 응답을 기다리지 않는다.
  sent,

  /// 기기가 명령을 확인했음(ACK 수신). 비상정지처럼 확인 채널이 있는
  /// 경로에서만 도달한다.
  confirmed,

  /// 실행하지 못함(전송 실패, 매핑 없음, 연결 없음 등).
  failed,
}

/// 화면·서비스가 공통으로 주고받는 명령 실행 결과.
/// [CommandFeedbackService]가 이 값을 받아 TTS/진동/소리로 통일되게 전달한다.
class CommandResult {
  const CommandResult({
    required this.phase,
    required this.userMessage,
    this.developerMessage,
  });

  final CommandPhase phase;

  /// 시각장애인 사용자에게 읽어줄 문구. 기술용어(G-code/XYZ/BT-xx)를 포함하지 않는다.
  final String userMessage;

  /// 개발자 로그/콘솔용 상세 문구(선택). 사용자에게는 노출하지 않는다.
  final String? developerMessage;

  bool get isFailure => phase == CommandPhase.failed;
}
