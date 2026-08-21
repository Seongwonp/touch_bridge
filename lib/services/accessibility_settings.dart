import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 이중 탭 확인(armed) 자동 해제 시간 — WCAG 2.2.1에 맞춰 앱 전체 20초 통일.
///
/// 화면마다 리터럴로 두면 드리프트가 생긴다(과거 15초/20초 혼재 사고 —
/// "20초 통일"이라는 대외 주장이 코드로 반증 가능한 상태였음).
/// 새 arm 타이머는 반드시 이 상수를 사용할 것.
const Duration kDoubleTapArmTimeout = Duration(seconds: 20);

class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings._();
  static final AccessibilitySettings instance = AccessibilitySettings._();

  static const _kVoiceGuidance = 'voice_guidance';
  static const _kLargeText = 'large_text';
  static const _kHighContrast = 'high_contrast';
  static const _kGuardianMode = 'guardian_mode';
  static const _kDeveloperMode = 'developer_mode';
  static const _kTtsSpeed = 'tts_speed';
  static const _kTtsVolume = 'tts_volume';
  static const _kContactName = 'contact_name';
  static const _kContactPhone = 'contact_phone';
  static const _kSttSilenceTimeout = 'stt_silence_timeout';

  bool _voiceGuidanceEnabled = true;
  bool _largeTextEnabled = false;
  bool _highContrastEnabled = false;
  bool _guardianModeEnabled = false;
  bool _developerModeEnabled = false;
  double _ttsSpeed = 1.0;
  double _ttsVolume = 1.0;
  int _sttSilenceTimeoutSeconds = 8;
  String _contactName = '';
  String _contactPhone = '';

  bool get voiceGuidanceEnabled => _voiceGuidanceEnabled;
  bool get largeTextEnabled => _largeTextEnabled;
  bool get highContrastEnabled => _highContrastEnabled;
  bool get guardianModeEnabled => _guardianModeEnabled;
  bool get developerModeEnabled => _developerModeEnabled;
  double get ttsSpeed => _ttsSpeed;
  double get ttsVolume => _ttsVolume;
  int get sttSilenceTimeoutSeconds => _sttSilenceTimeoutSeconds;
  String get contactName => _contactName;
  String get contactPhone => _contactPhone;

  /// VoiceOver(iOS) / TalkBack(Android) 활성 여부.
  /// 위젯 레이어에서 BuildContext 없이 사용하는 비반응형 버전.
  /// 반응형(컨텍스트 재빌드 트리거)이 필요하면 MediaQuery.of(context).accessibleNavigation 사용.
  static bool get isScreenReaderActive =>
      PlatformDispatcher.instance.accessibilityFeatures.accessibleNavigation;

  /// 앱 시작 시 한 번 호출 — 저장된 모든 설정 불러오기
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _voiceGuidanceEnabled = prefs.getBool(_kVoiceGuidance) ?? true;
      _largeTextEnabled = prefs.getBool(_kLargeText) ?? false;
      _highContrastEnabled = prefs.getBool(_kHighContrast) ?? false;
      _guardianModeEnabled = prefs.getBool(_kGuardianMode) ?? false;
      _developerModeEnabled = prefs.getBool(_kDeveloperMode) ?? false;
      _ttsSpeed = prefs.getDouble(_kTtsSpeed) ?? 1.0;
      _ttsVolume = prefs.getDouble(_kTtsVolume) ?? 1.0;
      _sttSilenceTimeoutSeconds = prefs.getInt(_kSttSilenceTimeout) ?? 8;
      _contactName = prefs.getString(_kContactName) ?? '';
      _contactPhone = prefs.getString(_kContactPhone) ?? '';
    } catch (e) {
      if (kDebugMode) debugPrint('Settings load error: $e');
    }
  }

  void setVoiceGuidanceEnabled(bool value) {
    if (_voiceGuidanceEnabled == value) return;
    _voiceGuidanceEnabled = value;
    _saveBool(_kVoiceGuidance, value);
    notifyListeners();
  }

  void setLargeTextEnabled(bool value) {
    if (_largeTextEnabled == value) return;
    _largeTextEnabled = value;
    _saveBool(_kLargeText, value);
    notifyListeners();
  }

  void setHighContrastEnabled(bool value) {
    if (_highContrastEnabled == value) return;
    _highContrastEnabled = value;
    _saveBool(_kHighContrast, value);
    notifyListeners();
  }

  void setGuardianModeEnabled(bool value) {
    if (_guardianModeEnabled == value) return;
    _guardianModeEnabled = value;
    _saveBool(_kGuardianMode, value);
    notifyListeners();
  }

  void setDeveloperModeEnabled(bool value) {
    if (_developerModeEnabled == value) return;
    _developerModeEnabled = value;
    _saveBool(_kDeveloperMode, value);
    notifyListeners();
  }

  void setTtsSpeed(double value) {
    _ttsSpeed = value;
    _saveDouble(_kTtsSpeed, value);
  }

  void setTtsVolume(double value) {
    _ttsVolume = value;
    _saveDouble(_kTtsVolume, value);
  }

  void setSttSilenceTimeoutSeconds(int value) {
    _sttSilenceTimeoutSeconds = value;
    _saveInt(_kSttSilenceTimeout, value);
  }

  void setContact(String name, String phone) {
    _contactName = name.trim();
    _contactPhone = phone.trim();
    _saveContact();
    notifyListeners();
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _saveContact() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kContactName, _contactName);
    await prefs.setString(_kContactPhone, _contactPhone);
  }
}
