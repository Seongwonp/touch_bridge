import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/voice_text_matcher.dart';

void main() {
  group('VoiceTextMatcher.isAffirmative (엄격 매칭)', () {
    // 긍정 오탐은 곧 의도하지 않은 물리 버튼 누름으로 이어지므로 엄격해야 한다.
    test('정확한 긍정 답변을 인식한다', () {
      for (final t in ['네', '예', '응', '맞아', '맞아요', '그래', '좋아요', '오케이', 'ok']) {
        expect(VoiceTextMatcher.isAffirmative(t), isTrue, reason: t);
      }
    });

    test('짧은 변형(어미 1~2자)을 허용한다', () {
      expect(VoiceTextMatcher.isAffirmative('네네'), isTrue);
      expect(VoiceTextMatcher.isAffirmative('맞아용'), isTrue);
      expect(VoiceTextMatcher.isAffirmative('그래요.'), isTrue); // 문장부호 정규화
    });

    test('과거 contains 오탐 사례를 긍정으로 판별하지 않는다', () {
      // "그런데 말이야"의 '네', "반응이 없어"의 '응' 같은 부분 문자열 오탐 —
      // 확인 질문에 대한 오탐은 곧 물리 버튼 누름이었다.
      expect(VoiceTextMatcher.isAffirmative('그런데 말이야'), isFalse);
      expect(VoiceTextMatcher.isAffirmative('반응이 없어'), isFalse);
      expect(VoiceTextMatcher.isAffirmative('좋아하는 노래 틀어줘'), isFalse);
      expect(VoiceTextMatcher.isAffirmative('전자레인지 예열해줘'), isFalse);
    });

    test('빈 문자열은 긍정이 아니다', () {
      expect(VoiceTextMatcher.isAffirmative(''), isFalse);
      expect(VoiceTextMatcher.isAffirmative('   '), isFalse);
    });
  });

  group('VoiceTextMatcher.isNegative (관대 매칭 — 안전 방향)', () {
    test('정확한 부정 답변을 인식한다', () {
      for (final t in ['아니', '아니요', '아뇨', '취소', '그만', '멈춰', '하지마']) {
        expect(VoiceTextMatcher.isNegative(t), isTrue, reason: t);
      }
    });

    test('문장 속 부정 표현도 인식한다 (오탐이어도 결과는 취소라 안전)', () {
      expect(VoiceTextMatcher.isNegative('그거 말고 취소해줘'), isTrue);
      expect(VoiceTextMatcher.isNegative('아니 그게 아니라'), isTrue);
    });

    test('부정 표현이 없으면 false', () {
      expect(VoiceTextMatcher.isNegative('30초 시작해줘'), isFalse);
    });
  });
}
