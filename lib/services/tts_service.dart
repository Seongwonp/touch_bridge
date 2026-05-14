import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'accessibility_settings.dart';

class TtsService {
  factory TtsService() => _instance;
  TtsService._internal() {
    _init = _initTts();
  }
  static final TtsService _instance = TtsService._internal();

  final FlutterTts _tts = FlutterTts();

  /// TTS 초기화 Future — speak() 첫 호출 전 완료 보장
  late final Future<void> _init;

  Future<void> _initTts() async {
    try {
      final settings = AccessibilitySettings.instance;
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate((settings.ttsSpeed / 2.0).clamp(0.1, 1.0));
      await _tts.setVolume(settings.ttsVolume.clamp(0.0, 1.0));
      await _tts.setPitch(1.0);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init error: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!AccessibilitySettings.instance.voiceGuidanceEnabled) return;
    // macOS 26 beta: AVSpeechSynthesisVoice triggers TCC abort (OS bug)
    if (defaultTargetPlatform == TargetPlatform.macOS) return;
    try {
      await _init;
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak error: $e');
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

  /// displaySpeed: UI 배속 (0.5x ~ 2.0x) → TTS rate (0.25 ~ 1.0)
  Future<void> setSpeechRate(double displaySpeed) async {
    final rate = (displaySpeed / 2.0).clamp(0.1, 1.0);
    await _tts.setSpeechRate(rate);
  }

  /// volume: 0.0 ~ 1.0
  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume.clamp(0.0, 1.0));
  }
}
