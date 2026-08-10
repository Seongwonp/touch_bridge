import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsService.replayLast', () {
    test('아무것도 말한 적 없으면 예외 없이 완료된다', () async {
      // 싱글톤이라 이전 테스트의 상태가 남아있을 수 있지만, replayLast는
      // lastSpokenText가 비어 있든 아니든 예외를 던지지 않아야 한다(테스트
      // 환경에는 실제 TTS 엔진이 없어 speak() 자체가 내부적으로 실패할 수 있음).
      await expectLater(TtsService().replayLast(), completes);
    });

    test('한 번 말한 뒤 replayLast를 호출해도 예외 없이 완료된다', () async {
      final tts = TtsService();
      await tts.speak('테스트 안내', source: 'test', force: true);
      await expectLater(tts.replayLast(), completes);
    });
  });
}
