/// "다시 말해줘/뭐라고/안 들려" 류 발화를 로컬에서 즉시 처리하기 위한 유틸.
///
/// 부엌 소음(후드·전자레인지 팬 등)에 안내가 묻히는 경우를 위한 대응이다.
/// EmergencyIntent/HelpIntent와 달리 확인 대기 상태([_pendingCommandData] 등)를
/// 지우지 않는다 — 소음으로 놓친 게 "확인 질문 자체"일 수 있으므로, 같은
/// 질문을 다시 들려주고 대화 맥락은 그대로 유지해야 한다.
class ReplayIntent {
  ReplayIntent._();

  static const List<String> tokens = <String>[
    '다시말해줘',
    '다시말해',
    '다시들려줘',
    '뭐라고',
    '안들려',
    '못들었어',
    '한번더말해줘',
    '한번더말해',
  ];

  /// [text]에 다시 듣기 요청 토큰이 포함되면 true.
  static bool matches(String text) {
    final normalized = text.toLowerCase().replaceAll(' ', '');
    return tokens.any(normalized.contains);
  }
}
