import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/accessibility_confirmation_policy.dart';

void main() {
  test('화면읽기에서는 단순 화면 이동의 앱 확인을 생략한다', () {
    expect(
      AccessibilityConfirmationPolicy.requiresAppConfirmation(
        kind: ConfirmationActionKind.navigation,
        screenReaderActive: true,
      ),
      isFalse,
    );
  });

  test('물리·파괴 동작 확인은 화면읽기에서도 유지한다', () {
    for (final kind in [
      ConfirmationActionKind.physicalAction,
      ConfirmationActionKind.destructiveAction,
    ]) {
      expect(
        AccessibilityConfirmationPolicy.requiresAppConfirmation(
          kind: kind,
          screenReaderActive: true,
        ),
        isTrue,
      );
    }
  });

  test('화면읽기가 꺼져 있으면 화면 이동 확인을 유지한다', () {
    expect(
      AccessibilityConfirmationPolicy.requiresAppConfirmation(
        kind: ConfirmationActionKind.navigation,
        screenReaderActive: false,
      ),
      isTrue,
    );
  });
}
