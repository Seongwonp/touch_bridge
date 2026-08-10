class MicrowaveCommandService {
  const MicrowaveCommandService._();

  static const buttonSeconds = <String, int>{
    'BT-01': 10,
    'BT-02': 30,
    'BT-03': 60,
    'BT-04': 300,
  };

  static const buttonLabel = <String, String>{
    'BT-01': '10초',
    'BT-02': '30초',
    'BT-03': '1분',
    'BT-04': '5분',
    'BT-05': '시작',
    'BT-06': '취소/정지',
    'BT-07': '해동',
    'BT-08': '우유',
    'BT-09': '자동조리',
  };

  static int calculateSeconds(List<dynamic> commands) {
    var total = 0;
    for (final btn in commands) {
      total += buttonSeconds[btn as String] ?? 0;
    }
    return total;
  }

  /// 목표 시간(초)을 실제 프리셋 버튼(5분/1분/30초/10초) 조합 + 시작(BT-05)
  /// 시퀀스로 변환한다. 이 기기는 숫자 키패드가 아니라 프리셋 버튼만 물리적으로
  /// 존재하므로, 숫자 패드에서 입력한 시간도 반드시 이 조합으로 눌러야 한다.
  /// 프리셋 최소 단위(10초)로 반올림하며, 반올림 여부를 [roundedFrom]으로 알린다.
  static ({List<String> buttons, int actualSeconds}) buildStartSequence(
    int targetSeconds,
  ) {
    if (targetSeconds <= 0) {
      return (buttons: const ['BT-05'], actualSeconds: 0);
    }
    final rounded = ((targetSeconds + 5) ~/ 10) * 10;
    var remaining = rounded;
    final buttons = <String>[];
    const presets = [
      (300, 'BT-04'),
      (60, 'BT-03'),
      (30, 'BT-02'),
      (10, 'BT-01'),
    ];
    for (final (seconds, id) in presets) {
      while (remaining >= seconds) {
        buttons.add(id);
        remaining -= seconds;
      }
    }
    buttons.add('BT-05');
    return (buttons: buttons, actualSeconds: rounded);
  }

  static String buildCommandsLabel(List<dynamic> commands) {
    final labels = commands.map((b) => buttonLabel[b as String] ?? b).toList();
    return labels.join(' → ');
  }

  static (int row, int col)? btnToGrid(String btn) {
    return switch (btn) {
      'BT-01' => (0, 0),
      'BT-02' => (0, 1),
      'BT-03' => (0, 2),
      'BT-04' => (1, 0),
      'BT-05' => (1, 1),
      'BT-06' => (1, 2),
      'BT-07' => (2, 0),
      'BT-08' => (2, 1),
      'BT-09' => (2, 2),
      _ => null,
    };
  }

  // 물리 좌표 전송을 위한 헬퍼 추가
  static (double x, double y)? btnToPhysical(String btn) {
    return switch (btn) {
      'BT-01' => (2.0, 20.0),
      'BT-02' => (8.0, 20.0),
      'BT-03' => (17.0, 20.0),
      'BT-04' => (2.0, 14.0),
      'BT-05' => (8.0, 14.0),
      'BT-06' => (17.0, 14.0),
      'BT-07' => (2.0, 3.0),
      'BT-08' => (8.0, 3.0),
      'BT-09' => (17.0, 3.0),
      _ => null,
    };
  }

  static Map<String, dynamic>? checkSimpleRules(String text) {
    final t = text.replaceAll(' ', '');
    // 새로운 규칙 추가: 'n번 눌러줘' 또는 'n번 버튼' 또는 그냥 'n번'
    final pressMatch = RegExp(r'(\d+)번(눌러줘|눌러|버튼|)?').firstMatch(t);
    if (pressMatch != null) {
      final btnNum = pressMatch.group(1);
      if (btnNum != null) {
        final btnId = 'BT-${btnNum.padLeft(2, '0')}';
        return {
          'action': 'IMMEDIATE_PRESS',
          'commands': [btnId],
          'message': '$btnNum번 버튼을 누릅니다.',
        };
      }
    }

    if (t.contains('30초시작') || t.contains('삼십초시작')) {
      return {
        'action': 'MICROWAVE_CONTROL',
        'commands': ['BT-02', 'BT-05'],
        'message': '30초 조리를 시작합니다.',
      };
    }
    if (t.contains('1분시작') || t.contains('일분시작')) {
      return {
        'action': 'MICROWAVE_CONTROL',
        'commands': ['BT-03', 'BT-05'],
        'message': '1분 조리를 시작합니다.',
      };
    }
    if (t.contains('취소') ||
        t.contains('정지') ||
        t.contains('그만') ||
        t.contains('중단') ||
        t.contains('stop')) {
      return {
        'action': 'MICROWAVE_CONTROL',
        'commands': ['BT-06'],
        'message': '조리를 중단합니다.',
      };
    }
    return null;
  }
}
