import '../models/voice_example_commands.dart';

/// "무엇을 할 수 있어?" 류 발화를 로컬에서 즉시 처리하기 위한 유틸.
///
/// 시각장애인 사용자는 화면의 "예시 명령어" 칩을 볼 수 없어 어떤 말을 하면
/// 되는지 외워야 했다. AI 백엔드를 거치지 않고 즉시 안내해, 도움말 요청이
/// 네트워크 지연이나 AI 오분류에 영향받지 않게 한다.
class HelpIntent {
  HelpIntent._();

  static const List<String> tokens = <String>[
    '도움말',
    '뭐할수있어',
    '무엇을할수있어',
    '무슨말을해야',
    '뭐라고말해',
    '어떻게써',
    '사용법',
    '명령어',
    '도와줘',
    'help',
  ];

  /// [text]에 도움말 요청 토큰이 포함되면 true. 공백을 무시하고 비교해
  /// "뭐 할 수 있어" / "뭐할수있어" 같은 띄어쓰기 차이를 모두 인식한다.
  static bool matches(String text) {
    final normalized = text.toLowerCase().replaceAll(' ', '');
    return tokens.any(normalized.contains);
  }

  /// 화면 진입 안내에서 이미 조작법(2단계 탭)을 설명하므로, 여기서는 실제로
  /// 말해볼 수 있는 예시 명령에 집중한다. 화면에 보이는 예시 칩과 같은
  /// 목록을 사용해 시각 사용자와 동일한 정보를 준다.
  static String buildResponse({int exampleCount = 3}) {
    final examples = kVoiceExampleCommands.take(exampleCount).join(', ');
    return '이렇게 말해보세요. $examples. 말한 뒤 다시 한 번 확인하면 실행됩니다. '
        '멈추고 싶으면 언제든 "멈춰"라고 말하세요.';
  }
}
