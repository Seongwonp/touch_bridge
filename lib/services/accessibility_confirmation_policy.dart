enum ConfirmationActionKind { navigation, physicalAction, destructiveAction }

/// 화면 이동은 한 번에 실행하고, 실제 기기 동작과 파괴적 작업만 확인한다.
///
/// 예전에는 화면읽기를 쓰지 않으면 화면 이동에도 "한 번 더 누르기"를 요구했다.
/// 화면마다 규칙이 달라 헷갈린다는 지적에 따라, 화면읽기 사용 여부와 무관하게
/// 앱 자체 두 번 누르기를 화면 이동에서 없앴다(재설계 제안 9절 결정 ③).
/// [screenReaderActive]는 호출부 호환을 위해 남긴다.
class AccessibilityConfirmationPolicy {
  const AccessibilityConfirmationPolicy._();

  static bool requiresAppConfirmation({
    required ConfirmationActionKind kind,
    required bool screenReaderActive,
  }) {
    return kind != ConfirmationActionKind.navigation;
  }
}
