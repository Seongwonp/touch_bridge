/// 음성 인식 결과 텍스트에서 긍정/부정 응답을 판별하는 순수 함수 모음.
/// `VoiceListeningScreen`의 상태와 무관해서 별도 서비스로 분리됨.
class VoiceTextMatcher {
  VoiceTextMatcher._();

  static const List<String> _affirmativeTokens = [
    '응',
    '네',
    '예',
    '맞아',
    '맞아요',
    '그래',
    '그래요',
    '좋아',
    '좋아요',
    'ok',
    'okay',
    '오케이',
  ];

  static const List<String> _negativeTokens = [
    '아니',
    '아니야',
    '아니요',
    '아뇨',
    '취소',
    '그만',
    '중지',
    '멈춰',
    '안돼',
    '안해',
    '하지마',
  ];

  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[.,!?~]+$'), '');
  }

  /// 긍정 판별 — **엄격 매칭**.
  ///
  /// 긍정 오탐은 곧 의도하지 않은 물리 버튼 누름으로 이어지므로, 정확 일치
  /// 또는 "토큰으로 시작하고 어미 1~2자만 붙은" 짧은 발화만 인정한다.
  /// 과거 contains 매칭은 "그런데 말이야"의 '네', "반응이 없어"의 '응' 같은
  /// 오탐이 가능했다.
  static bool isAffirmative(String text) {
    final t = normalize(text);
    if (t.isEmpty) return false;
    return _affirmativeTokens.any((token) {
      if (t == token) return true;
      // "네네", "맞아요", "좋아용" 등 짧은 변형만 허용. 긴 문장은 새 명령으로 취급.
      return t.startsWith(token) && (t.length - token.length) <= 2;
    });
  }

  /// 부정 판별 — **관대 매칭** (안전 방향 비대칭).
  ///
  /// 부정 오탐의 결과는 "취소"라 안전하므로, 2글자 이상 토큰은 포함 매칭을
  /// 유지한다("그거 말고 취소해줘" 등). 1글자 토큰은 없음.
  static bool isNegative(String text) {
    final t = normalize(text);
    if (t.isEmpty) return false;
    return _negativeTokens.any((token) => t == token || t.contains(token));
  }
}
