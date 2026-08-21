import '../models/command_result.dart';
import 'feedback_service.dart';
import 'tts_service.dart';

/// 명령 실행 결과(수신/전송/확인/실패)를 TTS·진동·소리로 일관되게 전달하는
/// 단일 창구.
///
/// 이전에는 화면마다 FeedbackService+TtsService 조합을 제각각 만들어 써서,
/// "BLE 전송 성공"을 "기기 확인 완료"인 것처럼 성공음으로 안내하는 문제가
/// 반복해서 생겼다(비상정지 ACK 스푸핑과 같은 종류의 문제). 이 서비스가
/// [CommandPhase]별 소리·진동·안내 우선순위를 한 곳에서 결정한다.
class CommandFeedbackService {
  CommandFeedbackService._();
  static final CommandFeedbackService instance = CommandFeedbackService._();

  final TtsService _tts = TtsService();

  /// [result]에 맞는 소리·진동·음성 안내를 재생한다.
  Future<void> announce(CommandResult result, {String source = 'command'}) {
    switch (result.phase) {
      case CommandPhase.received:
        FeedbackService.instance.playReceived();
        return _tts.speak(
          result.userMessage,
          source: source,
          priority: TtsPriority.result,
        );
      // 아래 세 phase 모두 명령의 "결과"이므로 result 우선순위를 명시한다.
      // interrupt만으로는 스크린리더 활성 시 억제되어 무음이 된다
      // (TtsService 억제 계약 참조).
      case CommandPhase.sent:
        // 전송은 됐지만 기기 확인은 아니므로 confirmed와 다른 소리를 쓴다.
        FeedbackService.instance.signalSent();
        return _tts.speak(
          result.userMessage,
          source: source,
          interrupt: true,
          priority: TtsPriority.result,
        );
      case CommandPhase.confirmed:
        FeedbackService.instance.signalSuccess();
        return _tts.speak(
          result.userMessage,
          source: source,
          interrupt: true,
          priority: TtsPriority.result,
        );
      case CommandPhase.failed:
        FeedbackService.instance.signalFailure();
        return _tts.speak(
          result.userMessage,
          source: source,
          interrupt: true,
          priority: TtsPriority.result,
        );
    }
  }
}
