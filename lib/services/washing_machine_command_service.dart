/// 세탁기 음성 명령 규칙 서비스.
///
/// BT-W01~BT-W09 는 논리 버튼 ID이며, 실제 좌표 매핑은 기기별 그리드에서 처리한다.
class WashingMachineCommandService {
  const WashingMachineCommandService._();

  static const buttonLabel = <String, String>{
    'BT-W01': '전원',
    'BT-W02': '시작/일시정지',
    'BT-W03': '표준 세탁',
    'BT-W04': '삶음/강력',
    'BT-W05': '섬세/울',
    'BT-W06': '헹굼 추가',
    'BT-W07': '탈수',
    'BT-W08': '예약',
    'BT-W09': '취소/정지',
  };

  /// 단순 규칙으로 즉시 처리 가능한 세탁기 명령을 파싱한다.
  /// Gemini 호출 없이 자주 쓰는 패턴을 빠르게 처리.
  static Map<String, dynamic>? checkSimpleRules(String text) {
    final t = text.replaceAll(' ', '');

    if (t.contains('전원')) {
      return {
        'action': 'WASHER_CONTROL',
        'commands': ['BT-W01'],
        'message': '전원 버튼을 누릅니다.',
      };
    }
    // 탈수/헹굼은 시작보다 먼저 체크 — '탈수 시작' 에서 시작이 먼저 매칭되는 것을 방지
    if (t.contains('헹굼')) {
      return {
        'action': 'WASHER_CONTROL',
        'commands': ['BT-W06'],
        'message': '헹굼 추가를 선택합니다.',
      };
    }
    if (t.contains('탈수')) {
      return {
        'action': 'WASHER_CONTROL',
        'commands': ['BT-W07'],
        'message': '탈수를 시작합니다.',
      };
    }
    if (t.contains('시작') || t.contains('작동')) {
      return {
        'action': 'WASHER_CONTROL',
        'commands': ['BT-W02'],
        'message': '세탁을 시작합니다.',
      };
    }
    if (t.contains('일시정지') || t.contains('멈춰') || t.contains('잠깐')) {
      return {
        'action': 'WASHER_CONTROL',
        'commands': ['BT-W02'],
        'message': '일시 정지합니다.',
      };
    }
    if (t.contains('표준') || t.contains('일반세탁') || t.contains('보통')) {
      return {
        'action': 'WASHER_CONTROL',
        'commands': ['BT-W03'],
        'message': '표준 세탁 코스를 선택합니다.',
      };
    }
    if (t.contains('삶음') || t.contains('강력') || t.contains('고온')) {
      return {
        'action': 'WASHER_CONTROL',
        'commands': ['BT-W04'],
        'message': '삶음/강력 코스를 선택합니다.',
      };
    }
    if (t.contains('섬세') || t.contains('울') || t.contains('손세탁')) {
      return {
        'action': 'WASHER_CONTROL',
        'commands': ['BT-W05'],
        'message': '섬세/울 코스를 선택합니다.',
      };
    }
    if (t.contains('취소') ||
        t.contains('정지') ||
        t.contains('그만') ||
        t.contains('중단') ||
        t.contains('stop')) {
      return {
        'action': 'WASHER_CONTROL',
        'commands': ['BT-W09'],
        'message': '세탁을 취소합니다.',
      };
    }
    return null;
  }

  static String buildCommandsLabel(List<dynamic> commands) {
    return commands.map((b) => buttonLabel[b as String] ?? b).join(' → ');
  }
}
