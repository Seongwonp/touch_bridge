enum MappingButtonRisk { standard, critical }

class MappingSafetyPolicy {
  MappingSafetyPolicy._();

  static const _criticalButtonIds = {'BT-05', 'BT-06'};
  static const _criticalKeywords = <String>[
    '시작',
    '취소',
    '정지',
    '출력',
    '전원',
    '확인',
    '결제',
    '구매',
    '문열림',
    '문 열림',
    'start',
    'stop',
    'cancel',
    'print',
    'power',
    'confirm',
    'pay',
  ];

  static MappingButtonRisk classify({
    required String buttonId,
    required String label,
  }) {
    final normalized = label.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final critical =
        _criticalButtonIds.contains(buttonId) ||
        _criticalKeywords.any(normalized.contains);
    return critical ? MappingButtonRisk.critical : MappingButtonRisk.standard;
  }

  static bool requiresExtraConfirmation({
    required String buttonId,
    required String label,
  }) =>
      classify(buttonId: buttonId, label: label) == MappingButtonRisk.critical;
}
