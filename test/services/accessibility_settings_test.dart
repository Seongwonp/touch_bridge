import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/accessibility_settings.dart';

void main() {
  test('이중 탭 대기 시간은 WCAG 2.2.1 합의값 20초다 (드리프트 방지)', () {
    // 과거 화면마다 리터럴(4초/15초/20초)이 흩어져 "20초 통일" 대외 주장이
    // 코드로 반증 가능한 상태였다. 모든 arm 타이머는 이 상수를 쓰고,
    // 값 변경은 문서(README/CLAUDE.md) 갱신과 함께 의도적으로만 한다.
    expect(kDoubleTapArmTimeout, const Duration(seconds: 20));
  });

  test('보호자 모드는 기본값이 꺼짐이고 저장값을 불러온다', () async {
    SharedPreferences.setMockInitialValues({});

    await AccessibilitySettings.instance.load();

    expect(AccessibilitySettings.instance.guardianModeEnabled, isFalse,
        reason: '기본값이 true면 혼자 기기 등록 흐름의 전제가 깨진다');

    SharedPreferences.setMockInitialValues({'guardian_mode': true});

    await AccessibilitySettings.instance.load();

    expect(AccessibilitySettings.instance.guardianModeEnabled, isTrue);

    AccessibilitySettings.instance.setGuardianModeEnabled(false);
    expect(AccessibilitySettings.instance.guardianModeEnabled, isFalse);
  });

  test('개발자 모드는 기본값이 꺼짐이고 저장값을 불러온다', () async {
    SharedPreferences.setMockInitialValues({});

    await AccessibilitySettings.instance.load();

    expect(AccessibilitySettings.instance.developerModeEnabled, isFalse);

    SharedPreferences.setMockInitialValues({'developer_mode': true});

    await AccessibilitySettings.instance.load();

    expect(AccessibilitySettings.instance.developerModeEnabled, isTrue);

    AccessibilitySettings.instance.setDeveloperModeEnabled(false);
    expect(AccessibilitySettings.instance.developerModeEnabled, isFalse);
  });
}
