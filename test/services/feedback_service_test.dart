import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/feedback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedbackService earcon', () {
    // 오디오 플러그인이 없는 테스트 환경에서도 결과 피드백이 흐름을 막지 않아야 한다
    // (내부에서 시스템 사운드로 폴백하고 예외를 삼킨다).
    test('수신/성공/실패 earcon 호출이 예외 없이 완료된다', () async {
      final fb = FeedbackService.instance;
      await expectLater(fb.playReceived(), completes);
      await expectLater(fb.playSuccess(), completes);
      await expectLater(fb.playFailure(), completes);
      await expectLater(fb.playDing(), completes);
    });
  });
}
