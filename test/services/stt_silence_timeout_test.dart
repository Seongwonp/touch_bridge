import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/accessibility_settings.dart';

void main() {
  group('STT 침묵 타임아웃', () {
    test('기본값은 8초이다', () async {
      SharedPreferences.setMockInitialValues({});
      await AccessibilitySettings.instance.load();

      expect(
        AccessibilitySettings.instance.sttSilenceTimeoutSeconds,
        equals(8),
        reason: '기본값이 바뀌면 기존 사용자의 체감 응답 시간이 달라진다',
      );
    });

    test('값 변경 후 getter가 즉시 반영된다', () async {
      SharedPreferences.setMockInitialValues({});
      await AccessibilitySettings.instance.load();

      AccessibilitySettings.instance.setSttSilenceTimeoutSeconds(12);

      expect(AccessibilitySettings.instance.sttSilenceTimeoutSeconds, equals(12));
    });

    test('저장된 값을 load() 후 복원한다', () async {
      SharedPreferences.setMockInitialValues({'stt_silence_timeout': 10});
      await AccessibilitySettings.instance.load();

      expect(AccessibilitySettings.instance.sttSilenceTimeoutSeconds, equals(10));
    });

    test('저장값 없으면 기본값 8초로 복원한다', () async {
      SharedPreferences.setMockInitialValues({});
      await AccessibilitySettings.instance.load();

      expect(AccessibilitySettings.instance.sttSilenceTimeoutSeconds, equals(8));
    });
  });
}
