/// 보호자→사용자 인수 체크리스트 항목 하나.
class HandoffCheckItem {
  const HandoffCheckItem({
    required this.label,
    required this.passed,
    this.detail,
  });

  /// 사용자(보호자)에게 보여줄 짧은 항목 이름.
  final String label;

  /// 이 항목이 통과했는가.
  final bool passed;

  /// 실패했을 때 보호자가 뭘 해야 하는지. 통과 시 null.
  final String? detail;
}

/// [GuardianHandoffService.run]의 결과 — 기기 설정을 마친 보호자가
/// "사용자가 정말 혼자 쓸 수 있는지" 판단할 수 있는 요약.
class HandoffReport {
  const HandoffReport({required this.items});

  final List<HandoffCheckItem> items;

  bool get allPassed => items.every((i) => i.passed);
  int get passCount => items.where((i) => i.passed).length;

  /// 음성으로 읽어줄 요약 문구. 실패 항목이 있으면 그 이유를 우선 말한다.
  String get spokenSummary {
    if (allPassed) {
      return '점검을 모두 통과했습니다. 사용자가 혼자 쓸 준비가 됐습니다.';
    }
    final failed = items.where((i) => !i.passed).toList();
    final first = failed.first;
    final more = failed.length > 1
        ? ' 이 외 ${failed.length - 1}건 더 확인이 필요합니다.'
        : '';
    return '$passCount개 중 ${items.length - passCount}개 항목에 확인이 필요합니다. '
        '${first.label}: ${first.detail ?? "확인이 필요합니다."}$more';
  }
}
