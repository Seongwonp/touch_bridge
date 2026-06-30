import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/accessibility_settings.dart';

void main() {
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
