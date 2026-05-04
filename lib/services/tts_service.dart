import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'accessibility_settings.dart';

class TtsService {
  factory TtsService() => _instance;
  TtsService._internal() {
    _initTts();
  }
  static final TtsService _instance = TtsService._internal();

  final FlutterTts _tts = FlutterTts();

  Future<void> _initTts() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    if (!AccessibilitySettings.instance.voiceGuidanceEnabled) {
      return;
    }
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TTS speak skipped: $e');
      }
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> setLanguage(String languageCode) async {
    await _tts.setLanguage(languageCode);
  }

  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }
}
