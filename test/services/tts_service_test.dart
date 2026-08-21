import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('스크린리더 억제 계약', () {
    // 계약: 억제는 호출부가 명시한 priority로만 판단한다.
    // - navigation/info → 스크린리더 활성 시 억제 (interrupt:true여도 동일)
    // - result/emergency → 절대 억제되지 않음
    // 이 계약이 깨지면 TalkBack 사용자가 비상정지 결과·arm 안내를 듣지 못하는
    // 회귀(2026-08 발견 버그)가 재발한다.
    final tts = TtsService();

    tearDown(() {
      tts.screenReaderOverrideForTest = null;
    });

    /// 마지막 로그 항목이 [needle]을 포함하는지 확인한다.
    /// (스피커가 없는 테스트 환경에서도 speak()는 재생 시도 전에
    /// 로그를 남기므로, 로그로 "억제 vs 재생 시도"를 구분할 수 있다.)
    Future<bool> lastLogContains(String needle) async {
      final log = tts.getRecentLog();
      return log.isNotEmpty && log.last.contains(needle);
    }

    test('스크린리더 활성: 기본(navigation) 발화는 억제된다', () async {
      tts.screenReaderOverrideForTest = true;
      await tts.speak('억제 검증용 내비게이션 안내', source: 'test');
      expect(await lastLogContains('SUPPRESSED'), isTrue);
    });

    test('스크린리더 활성: interrupt:true여도 기본 priority면 억제된다', () async {
      tts.screenReaderOverrideForTest = true;
      await tts.speak('억제 검증용 인터럽트 안내', source: 'test', interrupt: true);
      expect(await lastLogContains('SUPPRESSED'), isTrue);
    });

    test('스크린리더 활성: result 명시 발화는 억제되지 않는다', () async {
      tts.screenReaderOverrideForTest = true;
      await tts.speak(
        '결과 안내는 반드시 들려야 합니다',
        source: 'test',
        priority: TtsPriority.result,
      );
      expect(await lastLogContains('결과 안내는 반드시 들려야 합니다'), isTrue);
    });

    test('스크린리더 활성: emergency 발화는 억제되지 않는다', () async {
      tts.screenReaderOverrideForTest = true;
      await tts.speak(
        '비상 안내는 반드시 들려야 합니다',
        source: 'test',
        priority: TtsPriority.emergency,
        interrupt: true,
      );
      expect(await lastLogContains('비상 안내는 반드시 들려야 합니다'), isTrue);
    });

    test('스크린리더 비활성: navigation 발화도 정상 재생 경로로 간다', () async {
      tts.screenReaderOverrideForTest = false;
      await tts.speak('일반 상황 내비게이션 안내', source: 'test');
      expect(await lastLogContains('일반 상황 내비게이션 안내'), isTrue);
    });
  });

  group('TtsService.waitUntilIdle', () {
    // 확인 질문 후 자동 재청취 타이밍의 기반 API. 큐가 처리되는 동안 대기하고,
    // 유휴 상태에서는 즉시 완료되어야 한다(테스트 환경에는 TTS 엔진이 없어
    // 발화 자체는 catchError 경로로 곧바로 끝난다).
    test('유휴 상태에서는 즉시 완료된다', () async {
      final tts = TtsService();
      final sw = Stopwatch()..start();
      await tts.waitUntilIdle(timeout: const Duration(seconds: 3));
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('발화를 넣은 뒤 호출하면 큐 소진 후 완료된다', () async {
      final tts = TtsService();
      await tts.speak('대기 검증용 안내', source: 'test', force: true);
      await expectLater(
        tts.waitUntilIdle(timeout: const Duration(seconds: 5)),
        completes,
      );
    });

    test('타임아웃을 넘겨도 예외 없이 반환한다', () async {
      final tts = TtsService();
      await expectLater(
        tts.waitUntilIdle(timeout: Duration.zero),
        completes,
      );
    });
  });

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
