/// 에어컨 음성 명령 규칙 서비스.
///
/// BT-A01~BT-A09 는 논리 버튼 ID이며, 실제 좌표 매핑은 기기별 그리드에서 처리한다.
class AcCommandService {
  const AcCommandService._();

  static const buttonLabel = <String, String>{
    'BT-A01': '전원',
    'BT-A02': '냉방',
    'BT-A03': '난방',
    'BT-A04': '제습',
    'BT-A05': '송풍',
    'BT-A06': '온도 올리기',
    'BT-A07': '온도 내리기',
    'BT-A08': '풍량 강',
    'BT-A09': '취소/정지',
  };

  /// 단순 규칙으로 즉시 처리 가능한 에어컨 명령을 파싱한다.
  static Map<String, dynamic>? checkSimpleRules(String text) {
    final t = text.replaceAll(' ', '');

    // 모드 키워드가 포함된 경우 먼저 처리 (전원 규칙보다 우선)
    if (t.contains('냉방') || t.contains('시원') || t.contains('에어컨켜')) {
      return {
        'action': 'AC_CONTROL',
        'commands': ['BT-A02'],
        'message': '냉방 모드로 설정합니다.',
      };
    }
    if (t.contains('난방') || t.contains('따뜻') || t.contains('히터')) {
      return {
        'action': 'AC_CONTROL',
        'commands': ['BT-A03'],
        'message': '난방 모드로 설정합니다.',
      };
    }
    if (t.contains('제습') || t.contains('습기')) {
      return {
        'action': 'AC_CONTROL',
        'commands': ['BT-A04'],
        'message': '제습 모드로 설정합니다.',
      };
    }
    if (t.contains('송풍') || t.contains('바람만')) {
      return {
        'action': 'AC_CONTROL',
        'commands': ['BT-A05'],
        'message': '송풍 모드로 설정합니다.',
      };
    }
    // "n도" 또는 "온도 올려줘" 패턴
    final upMatch = RegExp(r'온도.*(올려|높여|높게|up)').hasMatch(t);
    if (upMatch) {
      return {
        'action': 'AC_CONTROL',
        'commands': ['BT-A06'],
        'message': '온도를 올립니다.',
      };
    }
    final downMatch = RegExp(r'온도.*(내려|낮춰|낮게|down)').hasMatch(t);
    if (downMatch) {
      return {
        'action': 'AC_CONTROL',
        'commands': ['BT-A07'],
        'message': '온도를 내립니다.',
      };
    }
    if (t.contains('풍량강') || t.contains('강풍') || t.contains('세게')) {
      return {
        'action': 'AC_CONTROL',
        'commands': ['BT-A08'],
        'message': '풍량을 강으로 설정합니다.',
      };
    }
    // 전원 ON/OFF — 모드 키워드가 없는 켜줘/꺼줘는 전원 버튼으로 처리
    if (t.contains('전원') || t.contains('켜줘') || t.contains('꺼줘')) {
      return {
        'action': 'AC_CONTROL',
        'commands': ['BT-A01'],
        'message': '전원 버튼을 누릅니다.',
      };
    }
    // 작업 취소 (작동 중 중단) — '꺼' 단독은 전원 규칙에서 처리하므로 여기선 제외
    if (t.contains('취소') ||
        t.contains('정지') ||
        t.contains('그만') ||
        t.contains('stop')) {
      return {
        'action': 'AC_CONTROL',
        'commands': ['BT-A09'],
        'message': '에어컨 작동을 취소합니다.',
      };
    }
    return null;
  }

  static String buildCommandsLabel(List<dynamic> commands) {
    return commands.map((b) => buttonLabel[b as String] ?? b).join(' → ');
  }
}
