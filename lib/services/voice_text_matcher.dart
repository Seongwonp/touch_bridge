/// 음성 인식 결과 텍스트에서 긍정/부정 응답을 판별하는 순수 함수 모음.
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
    // "네 말고", "아냐", "잠깐"처럼 긍정어 뒤에 붙거나 짧게 끊는 거절. 놓치면 승인으로 잡힐 수 있다.
    '말고',
    '아냐',
    '잠깐',
  ];

  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[.,!?~]+$'), '');
  }

  /// 긍정 판별 — 엄격 매칭.
  ///
  /// 긍정 오탐은 곧 의도하지 않은 물리 버튼 누름으로 이어지므로, 정해진 꼴
  /// (그대로·반복·"요/용" 어미)만 인정한다.
  /// contains 매칭이면 "그런데 말이야"의 '네', "반응이 없어"의 '응'도 긍정으로
  /// 잡힌다.
  static bool isAffirmative(String text) {
    final t = normalize(text);
    if (t.isEmpty) return false;
    // 부정어가 섞이면 긍정이 아니다. "네 취소"는 띄어쓰기를 빼면 "네취소"라
    // "네 + 두 글자" 규칙을 통과해 실행 승인으로 잡혔다(외부 평가 지적).
    if (isNegative(t)) return false;
    // 허용하는 꼴만 정확히 나열한다: 토큰 그대로, 반복("네네", "응응응"), 그리고
    // 끝에 "요"·"용"만 붙은 꼴("그래요", "맞아용"). 예전처럼 "토큰 + 아무 두 글자"를
    // 받으면 "예열", "예약", "응급", "그래도"가 확인 대기 중에 실행 승인이 됐다(외부 평가).
    return _affirmativeTokens.any((token) {
      for (final body in [token, token * 2, token * 3]) {
        if (t == body || t == '$body요' || t == '$body용') return true;
      }
      return false;
    });
  }

  /// 부정 판별 — 관대 매칭 (안전 방향 비대칭).
  ///
  /// 부정 오탐의 결과는 "취소"라 안전하므로, 2글자 이상 토큰은 포함 매칭을
  /// 유지한다("그거 말고 취소해줘" 등). 1글자 토큰은 없음.
  static bool isNegative(String text) {
    final t = normalize(text);
    if (t.isEmpty) return false;
    return _negativeTokens.any((token) => t == token || t.contains(token));
  }
}
