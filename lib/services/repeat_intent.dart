/// "아까 그거 다시", "또 해줘" 류 — 마지막 명령 재실행 요청 판별.
///
/// [ReplayIntent]("다시 말해줘" = 마지막 **안내를 다시 듣기**)와 구분된다:
/// 이쪽은 마지막 **명령을 다시 실행**하는 요청이라 물리 동작으로 이어지므로,
/// 반드시 확인 질문을 거쳐 실행해야 한다(호출부 책임).
/// 토큰은 ReplayIntent와 겹치지 않게 검증되어 있다('다시말해줘'는 '다시해줘'를
/// 포함하지 않음) — 판별 순서는 Replay 먼저, Repeat 나중.
class RepeatIntent {
  RepeatIntent._();

  static const List<String> tokens = <String>[
    '아까그거',
    '아까거',
    '아까한거',
    '방금그거',
    '방금거',
    '방금한거',
    '다시해줘',
    '다시해주',
    '또해줘',
    '또해주',
    '한번더해줘',
    '한번더해주',
    '같은거다시',
    '같은걸로',
    '전에했던거',
  ];

  /// [text]에 재실행 요청 토큰이 포함되면 true.
  static bool matches(String text) {
    final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return tokens.any(normalized.contains);
  }
}
