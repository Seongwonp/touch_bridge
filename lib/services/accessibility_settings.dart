import 'package:flutter/foundation.dart';

class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings._();
  static final AccessibilitySettings instance = AccessibilitySettings._();

  bool _voiceGuidanceEnabled = true;
  bool _largeTextEnabled = false;
  bool _highContrastEnabled = false;

  bool get voiceGuidanceEnabled => _voiceGuidanceEnabled;
  bool get largeTextEnabled => _largeTextEnabled;
  bool get highContrastEnabled => _highContrastEnabled;

  void setVoiceGuidanceEnabled(bool value) {
    if (_voiceGuidanceEnabled == value) return;
    _voiceGuidanceEnabled = value;
    notifyListeners();
  }

  void setLargeTextEnabled(bool value) {
    if (_largeTextEnabled == value) return;
    _largeTextEnabled = value;
    notifyListeners();
  }

  void setHighContrastEnabled(bool value) {
    if (_highContrastEnabled == value) return;
    _highContrastEnabled = value;
    notifyListeners();
  }
}
