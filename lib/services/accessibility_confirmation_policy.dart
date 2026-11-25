enum ConfirmationActionKind { navigation, physicalAction, destructiveAction }

/// 화면 이동은 한 번에 실행하고, 실제 기기 동작과 파괴적 작업만 확인한다.
///
/// 화면읽기 사용 여부에 따라 규칙이 달라지면 헷갈리므로, 화면 이동에는 앱 자체 두 번
/// 누르기를 요구하지 않는다. [screenReaderActive]는 호출부 호환을 위해 남긴다.
class AccessibilityConfirmationPolicy {
  const AccessibilityConfirmationPolicy._();

  static bool requiresAppConfirmation({
    required ConfirmationActionKind kind,
    required bool screenReaderActive,
  }) {
    return kind != ConfirmationActionKind.navigation;
  }
}
