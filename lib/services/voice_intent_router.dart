import 'package:speech_to_text/speech_recognition_result.dart';

import 'emergency_intent.dart';
import 'help_intent.dart';
import 'repeat_intent.dart';
import 'replay_intent.dart';
import 'status_intent.dart';
import 'voice_text_matcher.dart';

/// 인식된 발화 하나를 어떤 흐름으로 보낼지 결정한다.
///
/// `VoiceListeningScreen._sendTextToGemini`의 앞부분에 중첩 if로 쌓여 있던
/// 판정을 그대로 옮긴 것이다. 옮긴 이유는 길이가 아니라 **순서가 곧 안전
/// 계약**이기 때문이다. 화면 안에서는 이 순서를 검증할 방법이 없었다.
///
/// 지켜야 하는 순서와 이유:
/// 1. 빈 문장
/// 2. **비상 정지가 언제나 최우선** — 확인 질문을 기다리는 중이든 신뢰도가
///    낮든, "멈춰"는 다른 어떤 판정보다 먼저 통과해야 한다.
/// 3. 도움말 — 화면의 예시 칩을 볼 수 없는 사용자의 발견성 보완.
/// 4. 상태 질의("얼마나 남았어?") — **확인 대기 맥락을 지우지 않는다.**
///    상태를 물어본 뒤 이어서 예/아니오로 답할 수 있어야 한다.
/// 5. 안내 재생("다시 말해줘") — 역시 맥락을 지우지 않는다. 놓친 것이 확인
///    질문 자체일 수 있으므로 맥락을 유지한 채 마지막 안내만 다시 들려준다.
/// 6. 재실행("아까 그거 다시") — 물리 동작이므로 바로 실행하지 않고 확인을 거친다.
/// 7. 낮은 신뢰도 확인에 대한 예/아니오 응답
/// 8. 새 발화의 낮은 신뢰도 게이트 (부엌 소음 대응)
/// 9. 파싱된 명령 확인에 대한 예/아니오 응답
/// 10. 그 밖에는 새 명령으로 파싱
///
/// 판정에 필요한 상태만 받는 순수 함수라, 화면 없이 순서를 검증할 수 있다.
class VoiceIntentRouter {
  VoiceIntentRouter._();

  /// 이 값 미만의 인식 신뢰도는 바로 실행하지 않고 들은 문장을 먼저 확인한다.
  static const double lowConfidenceThreshold = 0.5;

  static VoiceIntentDecision route({
    required String text,
    required bool hasPendingCommand,
    required String? pendingLowConfidenceText,
    required double confidence,
  }) {
    if (text.isEmpty) {
      return const VoiceIntentDecision(VoiceIntentKind.emptyText);
    }

    // 2. 비상 정지 — 어떤 대기 상태보다 먼저.
    if (EmergencyIntent.matches(text)) {
      return const VoiceIntentDecision(
        VoiceIntentKind.emergencyStop,
        clearPendingCommand: true,
      );
    }

    // 3. 도움말.
    if (HelpIntent.matches(text)) {
      return const VoiceIntentDecision(
        VoiceIntentKind.help,
        clearPendingCommand: true,
      );
    }

    // 4·5. 상태 질의와 안내 재생은 확인 대기 맥락을 보존한다.
    if (StatusIntent.matches(text)) {
      return const VoiceIntentDecision(VoiceIntentKind.status);
    }
    if (ReplayIntent.matches(text)) {
      return const VoiceIntentDecision(VoiceIntentKind.replayLastSpeech);
    }

    // 6. 재실행 요청 — 확인 질문으로 이어진다(여기서 대기 명령을 지우지 않는다;
    //    호출부가 마지막 명령을 불러와 새 대기 명령으로 설정한다).
    if (RepeatIntent.matches(text)) {
      return const VoiceIntentDecision(VoiceIntentKind.repeatLastCommand);
    }

    // 7. 낮은 신뢰도 확인 응답. 이 블록에 들어오면 대기 문장은 결과와 무관하게
    //    소비된다(예/아니오가 아니면 새 명령으로 계속 흘러간다).
    final consumingLowConfidence = pendingLowConfidenceText != null;
    if (consumingLowConfidence) {
      if (VoiceTextMatcher.isAffirmative(text)) {
        return VoiceIntentDecision(
          VoiceIntentKind.lowConfidenceAccepted,
          payload: pendingLowConfidenceText,
          clearPendingLowConfidence: true,
        );
      }
      if (VoiceTextMatcher.isNegative(text)) {
        return const VoiceIntentDecision(
          VoiceIntentKind.lowConfidenceRejected,
          clearPendingLowConfidence: true,
        );
      }
      // 예/아니오가 아니면 아래로 흘려보낸다.
    }

    // 8. 새 발화의 신뢰도 게이트.
    //    missingConfidence(-1)는 "신뢰도를 알 수 없다"는 신호이지 낮다는 뜻이
    //    아니다. 플랫폼에 따라 항상 -1을 주는 경우가 있어, 없는 신호로 정상
    //    동작을 막지 않는다.
    //
    //    여기서는 대기 중인 파싱 명령을 지우지 않는다 — 확인 질문에 답하려다
    //    소음으로 오인식된 것일 수 있으므로 맥락을 유지한다.
    if (confidence != SpeechRecognitionWords.missingConfidence &&
        confidence < lowConfidenceThreshold) {
      return VoiceIntentDecision(
        VoiceIntentKind.confirmLowConfidence,
        payload: text,
        clearPendingLowConfidence: consumingLowConfidence,
      );
    }

    // 9. 파싱된 명령 확인 응답.
    if (hasPendingCommand) {
      if (VoiceTextMatcher.isAffirmative(text)) {
        return VoiceIntentDecision(
          VoiceIntentKind.pendingAccepted,
          clearPendingCommand: true,
          clearPendingLowConfidence: consumingLowConfidence,
        );
      }
      if (VoiceTextMatcher.isNegative(text)) {
        return VoiceIntentDecision(
          VoiceIntentKind.pendingRejected,
          clearPendingCommand: true,
          clearPendingLowConfidence: consumingLowConfidence,
        );
      }
      // 예/아니오가 아니면 대기 명령을 버리고 새 명령으로 처리한다.
    }

    // 10. 새 명령으로 파싱.
    return VoiceIntentDecision(
      VoiceIntentKind.parseAsNewCommand,
      clearPendingCommand: hasPendingCommand,
      clearPendingLowConfidence: consumingLowConfidence,
    );
  }
}

/// [VoiceIntentRouter.route]가 고른 흐름.
enum VoiceIntentKind {
  /// 인식된 문장이 비어 있다.
  emptyText,

  /// 비상 정지 — 즉시 중단 명령으로 간다.
  emergencyStop,

  /// "무엇을 할 수 있어?" — 도움말을 읽어준다.
  help,

  /// "얼마나 남았어?" — 현재 실행 상태를 읽어준다.
  status,

  /// "다시 말해줘" — 마지막 안내를 다시 재생한다.
  replayLastSpeech,

  /// "아까 그거 다시" — 마지막 명령을 불러와 확인 질문을 한다.
  repeatLastCommand,

  /// 낮은 신뢰도로 되물은 문장을 사용자가 맞다고 확인했다.
  /// [VoiceIntentDecision.payload]가 다시 처리할 원문이다.
  /// 호출부는 재확인 루프를 막기 위해 신뢰도를 1.0으로 리셋해야 한다.
  lowConfidenceAccepted,

  /// 되물은 문장을 사용자가 아니라고 했다 — 다시 듣는다.
  lowConfidenceRejected,

  /// 새 발화의 신뢰도가 낮다 — 실행 전에 들은 문장을 되묻는다.
  /// [VoiceIntentDecision.payload]가 되물을 문장이다.
  confirmLowConfidence,

  /// 파싱된 명령 확인에 "예"로 답했다 — 실행한다.
  pendingAccepted,

  /// 파싱된 명령 확인에 "아니오"로 답했다 — 취소한다.
  pendingRejected,

  /// 새 명령으로 파싱한다(기기 해석 → 간단 규칙 → AI 백엔드).
  parseAsNewCommand,
}

/// 라우팅 결과와, 그 결과를 적용할 때 비워야 하는 대기 상태.
class VoiceIntentDecision {
  const VoiceIntentDecision(
    this.kind, {
    this.payload,
    this.clearPendingCommand = false,
    this.clearPendingLowConfidence = false,
  });

  final VoiceIntentKind kind;

  /// 흐름별 추가 문장.
  /// - [VoiceIntentKind.lowConfidenceAccepted]: 다시 처리할 원문
  /// - [VoiceIntentKind.confirmLowConfidence]: 되물을 문장
  final String? payload;

  /// 적용 후 대기 중인 파싱 명령을 비워야 하는가.
  final bool clearPendingCommand;

  /// 적용 후 대기 중인 낮은 신뢰도 문장을 비워야 하는가.
  final bool clearPendingLowConfidence;

  @override
  String toString() =>
      'VoiceIntentDecision($kind, payload: $payload, '
      'clearPendingCommand: $clearPendingCommand, '
      'clearPendingLowConfidence: $clearPendingLowConfidence)';
}
