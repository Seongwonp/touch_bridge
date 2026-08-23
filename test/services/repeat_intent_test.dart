import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/repeat_intent.dart';
import 'package:touch_bridge/services/replay_intent.dart';

void main() {
  group('RepeatIntent.matches (마지막 명령 재실행 요청)', () {
    test('재실행 요청 표현을 인식한다', () {
      for (final t in [
        '아까 그거 다시',
        '방금 그거',
        '다시 해줘',
        '또 해줘',
        '한 번 더 해줘',
        '같은 걸로',
        '아까 한 거',
      ]) {
        expect(RepeatIntent.matches(t), isTrue, reason: t);
      }
    });

    test('일반 명령·안내 재생 요청은 재실행으로 오인하지 않는다', () {
      for (final t in [
        '30초 시작',
        '다시 30초 해줘', // 새 명령 (구체적 동작 포함)
        '다시 말해줘', // ReplayIntent 영역
        '뭐라고?',
      ]) {
        expect(RepeatIntent.matches(t), isFalse, reason: t);
      }
    });

    test('Replay와 Repeat 토큰은 서로 겹치지 않는다 (오라우팅 방지)', () {
      // "다시 말해줘"(안내 재생)가 재실행으로 가면 확인 없이 물리 명령 흐름에
      // 진입할 수 있다 — 두 인텐트의 상호 배타성을 회귀로 고정한다.
      for (final replayToken in ReplayIntent.tokens) {
        expect(RepeatIntent.matches(replayToken), isFalse,
            reason: 'Replay 토큰이 Repeat에 매칭됨: $replayToken');
      }
      for (final repeatToken in RepeatIntent.tokens) {
        expect(ReplayIntent.matches(repeatToken), isFalse,
            reason: 'Repeat 토큰이 Replay에 매칭됨: $repeatToken');
      }
    });
  });
}
