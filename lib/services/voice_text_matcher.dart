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
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  static bool isAffirmative(String text) {
    final t = normalize(text);
    return _affirmativeTokens.any((token) => t == token || t.contains(token));
  }

  static bool isNegative(String text) {
    final t = normalize(text);
    return _negativeTokens.any((token) => t == token || t.contains(token));
  }
}
