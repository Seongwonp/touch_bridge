import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:touch_bridge/services/voice_intent_router.dart';

/// 음성 발화 하나가 어떤 흐름으로 가는지의 **순서 계약** 검증.
///
/// 이 판정은 원래 `VoiceListeningScreen._sendTextToGemini` 안의 중첩 if였고
/// 커버리지가 0.2%였다. 순서가 틀려도 앱은 조용히 잘못 동작한다 — 예를 들어
/// 확인 질문 대기 중에 "멈춰"가 "아니오(취소)"로 먹히면, 사용자는 기기를
/// 멈추려 했는데 질문만 취소되고 기기는 계속 돈다.
void main() {
  const missing = SpeechRecognitionWords.missingConfidence;

  VoiceIntentDecision route(
    String text, {
    bool hasPendingCommand = false,
    String? pendingLowConfidenceText,
    double confidence = 1.0,
  }) => VoiceIntentRouter.route(
    text: text,
    hasPendingCommand: hasPendingCommand,
    pendingLowConfidenceText: pendingLowConfidenceText,
    confidence: confidence,
  );

  group('빈 문장', () {
    test('빈 문장은 emptyText로 간다', () {
      expect(route('').kind, VoiceIntentKind.emptyText);
    });
  });

  group('비상 정지는 언제나 최우선', () {
    test('평상시 "멈춰"는 비상 정지다', () {
      expect(route('멈춰').kind, VoiceIntentKind.emergencyStop);
    });

    test('명령 확인 대기 중의 "멈춰"는 취소가 아니라 비상 정지다', () {
      // "멈춰"는 VoiceTextMatcher의 부정 응답 토큰이기도 하다. 순서가 뒤집히면
      // 확인 질문만 취소되고 기기는 계속 돌아간다 — 안전 직결 회귀.
      final d = route('멈춰', hasPendingCommand: true);
      expect(d.kind, VoiceIntentKind.emergencyStop);
      expect(d.kind, isNot(VoiceIntentKind.pendingRejected));
      expect(d.clearPendingCommand, isTrue);
    });

    test('"그만"도 부정 응답보다 비상 정지가 우선한다', () {
      expect(
        route('그만', hasPendingCommand: true).kind,
        VoiceIntentKind.emergencyStop,
      );
    });

    test('신뢰도가 낮아도 비상 정지는 되묻지 않고 즉시 실행한다', () {
      // 소음 때문에 신뢰도가 낮다고 "정말 멈출까요?"를 되물으면 안 된다.
      expect(
        route('멈춰', confidence: 0.1).kind,
        VoiceIntentKind.emergencyStop,
      );
    });

    test('낮은 신뢰도 확인 대기 중에도 비상 정지가 우선한다', () {
      expect(
        route('정지', pendingLowConfidenceText: '30초 시작').kind,
        VoiceIntentKind.emergencyStop,
      );
    });
  });

  group('도움말·상태·재생은 AI를 거치지 않는다', () {
    test('"도움말"은 help로 가고 대기 명령을 비운다', () {
      final d = route('도움말', hasPendingCommand: true);
      expect(d.kind, VoiceIntentKind.help);
      expect(d.clearPendingCommand, isTrue);
    });

    test('상태 질의는 확인 대기 맥락을 지우지 않는다', () {
      // 상태를 물어본 뒤 이어서 예/아니오로 답할 수 있어야 한다.
      final d = route('얼마나 남았어', hasPendingCommand: true);
      expect(d.kind, VoiceIntentKind.status);
      expect(d.clearPendingCommand, isFalse);
      expect(d.clearPendingLowConfidence, isFalse);
    });

    test('안내 재생도 확인 대기 맥락을 지우지 않는다', () {
      // 놓친 것이 확인 질문 자체일 수 있으므로 맥락을 유지한다.
      final d = route('다시 말해줘', hasPendingCommand: true);
      expect(d.kind, VoiceIntentKind.replayLastSpeech);
      expect(d.clearPendingCommand, isFalse);
    });

    test('"다시 말해줘"(재생)와 "다시 해줘"(재실행)를 구분한다', () {
      expect(route('다시 말해줘').kind, VoiceIntentKind.replayLastSpeech);
      expect(route('다시 해줘').kind, VoiceIntentKind.repeatLastCommand);
    });

    test('재실행 요청은 바로 실행하지 않고 확인 흐름으로 보낸다', () {
      final d = route('아까 그거 다시');
      expect(d.kind, VoiceIntentKind.repeatLastCommand);
      // 호출부가 마지막 명령을 불러와 새 대기 명령으로 설정하므로 여기서
      // 기존 대기 명령을 비우지 않는다.
      expect(d.clearPendingCommand, isFalse);
    });
  });

  group('낮은 신뢰도 확인 응답', () {
    test('"네"로 확인하면 되물었던 원문을 다시 처리한다', () {
      final d = route('네', pendingLowConfidenceText: '30초 시작');
      expect(d.kind, VoiceIntentKind.lowConfidenceAccepted);
      expect(d.payload, '30초 시작');
      expect(d.clearPendingLowConfidence, isTrue);
    });

    test('"아니오"면 실행하지 않고 다시 듣는다', () {
      final d = route('아니오', pendingLowConfidenceText: '30초 시작');
      expect(d.kind, VoiceIntentKind.lowConfidenceRejected);
      expect(d.clearPendingLowConfidence, isTrue);
    });

    test('예/아니오가 아니면 새 명령으로 흘러가고 대기 문장은 소비된다', () {
      final d = route('1분 시작', pendingLowConfidenceText: '30초 시작');
      expect(d.kind, VoiceIntentKind.parseAsNewCommand);
      expect(d.clearPendingLowConfidence, isTrue);
    });
  });

  group('신뢰도 게이트 (부엌 소음 대응)', () {
    test('신뢰도가 임계값 미만이면 실행 전에 되묻는다', () {
      final d = route('30초 시작', confidence: 0.3);
      expect(d.kind, VoiceIntentKind.confirmLowConfidence);
      expect(d.payload, '30초 시작');
    });

    test('임계값과 같으면 게이트에 걸리지 않는다 (경계: < 비교)', () {
      expect(
        route('30초 시작', confidence: VoiceIntentRouter.lowConfidenceThreshold)
            .kind,
        VoiceIntentKind.parseAsNewCommand,
      );
    });

    test('missingConfidence(-1)는 "낮다"가 아니라 "알 수 없다"이므로 막지 않는다', () {
      // 플랫폼에 따라 항상 -1을 주는 경우가 있다. 없는 신호로 정상 동작을
      // 막으면 그 플랫폼에서는 모든 명령이 되묻기에 걸린다.
      expect(
        route('30초 시작', confidence: missing).kind,
        VoiceIntentKind.parseAsNewCommand,
      );
    });

    test('되묻는 동안 대기 중인 파싱 명령을 지우지 않는다', () {
      // 확인 질문에 답하려다 소음으로 오인식됐을 수 있으므로 맥락을 유지한다.
      final d = route('어쩌고', hasPendingCommand: true, confidence: 0.2);
      expect(d.kind, VoiceIntentKind.confirmLowConfidence);
      expect(d.clearPendingCommand, isFalse);
    });
  });

  group('파싱된 명령 확인 응답', () {
    test('"네"면 실행한다', () {
      final d = route('네', hasPendingCommand: true);
      expect(d.kind, VoiceIntentKind.pendingAccepted);
      expect(d.clearPendingCommand, isTrue);
    });

    test('"아니오"면 취소한다', () {
      final d = route('아니오', hasPendingCommand: true);
      expect(d.kind, VoiceIntentKind.pendingRejected);
      expect(d.clearPendingCommand, isTrue);
    });

    test('예/아니오가 아니면 대기 명령을 버리고 새 명령으로 처리한다', () {
      final d = route('1분 시작', hasPendingCommand: true);
      expect(d.kind, VoiceIntentKind.parseAsNewCommand);
      expect(d.clearPendingCommand, isTrue);
    });

    test('대기 명령이 없으면 "네"도 그냥 새 명령으로 간다', () {
      expect(route('네').kind, VoiceIntentKind.parseAsNewCommand);
    });
  });

  group('일반 명령', () {
    test('평범한 명령은 파싱 흐름으로 간다', () {
      final d = route('전자레인지 30초 시작');
      expect(d.kind, VoiceIntentKind.parseAsNewCommand);
      expect(d.clearPendingCommand, isFalse);
      expect(d.clearPendingLowConfidence, isFalse);
    });

    test('"일시정지"는 비상 정지로 가로채이지 않는다', () {
      // 세탁기 일시정지 버튼을 눌러 달라는 명령이지 갠트리 비상 정지가 아니다.
      expect(
        route('세탁기 일시정지').kind,
        VoiceIntentKind.parseAsNewCommand,
      );
    });
  });
}
