import 'dart:math' show max;

import 'package:flutter/foundation.dart' show visibleForTesting;

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
    // 1~4초는 반올림 결과가 0이 되므로 최소 10초로 올린다.
    // rounded == 0이면 시작 버튼(BT-05)만 눌려 카운트다운 화면이 즉시 완료로 보인다.
    final rounded = max(10, ((targetSeconds + 5) ~/ 10) * 10);
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

  /// 부정·거절 표현이 있으면 앱 규칙은 실행 명령을 만들지 않고 백엔드(AI)로
  /// 넘긴다 — "30초 시작하지마"를 30초 시작으로 실행하던 문제.
  ///
  /// 공백을 지운 문자열에서 토큰 포함 여부를 보면 "30초 동안 해줘"의 "안해",
  /// "국에 밥 말아 데워줘"의 "말아"가 오탐된다(재리뷰 P2). 그래서 원문 어절
  /// 단위로 본다. 백엔드 `microwave_logic.has_negation`과 같은 규칙이다.
  static final _negationSuffixRe = RegExp(
    r'(하지마|하지말|하지않|하지마세요|않을래|않을게|안할래|안할게|싫어|싫은데|말래|안돼|안되|않아|말고)(요|여|야)?$',
  );
  static final _negationPrefixRe = RegExp(r'^(안|못)(해|할|되|돼)');
  static final _punctRe = RegExp(r'[.,!?~…]+');

  /// 어절은 문장부호를 뗀 뒤 본다("시작하지마."). "만두말고"처럼 조사가 붙은
  /// 경우는 어미 규칙(…말고)으로 잡는다.
  @visibleForTesting
  static bool hasNegation(String text) {
    final words = text
        .replaceAll(_punctRe, ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w == '안' || w == '못') return true; // "안 할래", "못 해"
      if (_negationPrefixRe.hasMatch(w)) return true; // "안해줘", "못하겠어"
      if (_negationSuffixRe.hasMatch(w)) return true; // "시작하지마", "안할래"
      if (w == '말고') return true; // "만두 말고 밥"
      // "누르지 말아" — 앞 어절이 '지'로 끝날 때만 부정. "밥 말아 데워줘"는 아님.
      if ((w.startsWith('말아') || w.startsWith('마세요') || w == '마') &&
          i > 0 &&
          words[i - 1].endsWith('지')) {
        return true;
      }
    }
    return false;
  }

  /// 'n번', 'n번 버튼', 'n번 눌러줘' — 문장 전체가 이 형태일 때만 즉시 누름.
  /// 이전의 앵커 없는 firstMatch는 "3번째 만두 데워줘"도 3번 버튼 즉시 누름으로
  /// 확정해 AI 통제층을 건너뛰었다.
  static final _pressOnlyRe =
      RegExp(r'^(\d{1,2})번(버튼)?(을|를)?(눌러줘|눌러|눌러주세요|누르기)?$');
  static final _start30Re = RegExp(r'^(30초|삼십초)(으로|로)?시작(해|해줘|해주세요)?$');
  static final _start60Re = RegExp(r'^(1분|일분)(으로|로)?시작(해|해줘|해주세요)?$');

  static Map<String, dynamic>? checkSimpleRules(String text) {
    final t = text.replaceAll(' ', '');

    // 1) 취소·정지는 다른 규칙보다 먼저 본다. "1분 시작 취소"는 취소다.
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

    // 2) 부정·거절 표현은 규칙으로 실행하지 않는다 (AI 경로로). 원문 어절 기준.
    if (hasNegation(text)) return null;

    // 3) 'n번' 즉시 누름 — 문장 전체 일치일 때만.
    final pressMatch = _pressOnlyRe.firstMatch(t);
    if (pressMatch != null) {
      final btnNum = pressMatch.group(1)!;
      final btnId = 'BT-${btnNum.padLeft(2, '0')}';
      return {
        'action': 'IMMEDIATE_PRESS',
        'commands': [btnId],
        'message': '$btnNum번 버튼을 누릅니다.',
      };
    }

    // 4) 빈출 시간 명령 — 전체 일치. ("11분 시작"이 "1분시작"에 걸리지 않게)
    if (_start30Re.hasMatch(t)) {
      return {
        'action': 'MICROWAVE_CONTROL',
        'commands': ['BT-02', 'BT-05'],
        'message': '30초 조리를 시작합니다.',
      };
    }
    if (_start60Re.hasMatch(t)) {
      return {
        'action': 'MICROWAVE_CONTROL',
        'commands': ['BT-03', 'BT-05'],
        'message': '1분 조리를 시작합니다.',
      };
    }
    return null;
  }
}
