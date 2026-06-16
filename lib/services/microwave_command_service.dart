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

  static Map<String, dynamic>? checkSimpleRules(String text) {
    final t = text.replaceAll(' ', '');
    // 새로운 규칙 추가: 'n번 눌러줘' 또는 'n번 버튼'
    final pressMatch = RegExp(r'(\d+)번(눌러줘|눌러|버튼)').firstMatch(t);
    if (pressMatch != null) {
      final btnNum = pressMatch.group(1);
      if (btnNum != null) {
        final btnId = 'BT-${btnNum.padLeft(2, '0')}';
        return {
          'action': 'IMMEDIATE_PRESS',
          'commands': [btnId],
          'message': '$btnNum번 버튼을 누릅니다.'
        };
      }
    }
    
    if (t.contains('30초시작') || t.contains('삼십초시작')) {
      return {'action': 'MICROWAVE_CONTROL', 'commands': ['BT-02', 'BT-05'], 'message': '30초 조리를 시작합니다.'};
    }
    if (t.contains('1분시작') || t.contains('일분시작')) {
      return {'action': 'MICROWAVE_CONTROL', 'commands': ['BT-03', 'BT-05'], 'message': '1분 조리를 시작합니다.'};
    }
    if (t.contains('취소') || t.contains('정지') || t.contains('그만') || t.contains('중단') || t.contains('stop')) {
      return {'action': 'MICROWAVE_CONTROL', 'commands': ['BT-06'], 'message': '조리를 중단합니다.'};
    }
    return null;
  }
}
