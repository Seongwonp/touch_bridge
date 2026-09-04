enum ConfirmationActionKind { navigation, physicalAction, destructiveAction }

/// 화면읽기 사용자는 운영체제의 "선택 후 두 번 탭"을 이미 거친다.
/// 따라서 단순 화면 이동에는 앱 자체 확인 탭을 겹치지 않되, 실제 기기 동작과
/// 파괴적 작업의 확인은 접근성 설정과 무관하게 유지한다.
class AccessibilityConfirmationPolicy {
  const AccessibilityConfirmationPolicy._();

  static bool requiresAppConfirmation({
    required ConfirmationActionKind kind,
    required bool screenReaderActive,
  }) {
    if (kind == ConfirmationActionKind.navigation && screenReaderActive) {
      return false;
    }
    return true;
  }
}
