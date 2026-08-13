import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/accessibility_settings.dart';

void main() {
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
