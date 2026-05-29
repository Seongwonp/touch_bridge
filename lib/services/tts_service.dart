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
  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastSpokenText = '';
  bool _isSpeaking = false;

  /// TTS 초기화 Future — speak() 첫 호출 전 완료 보장
  late final Future<void> _init;

  Future<void> _initTts() async {
    try {
      final settings = AccessibilitySettings.instance;
      await _tts.setSpeechRate((settings.ttsSpeed / 2.0).clamp(0.1, 1.0));
      await _tts.setVolume(settings.ttsVolume.clamp(0.0, 1.0));
      await _tts.setPitch(1.0);

      if (kIsWeb) {
        // Chrome loads voices asynchronously; delay then trigger load
        await Future.delayed(const Duration(milliseconds: 500));
        await _tts.getVoices;
        await _tts.setLanguage('ko-KR');
      } else {
        await _tts.setLanguage('ko-KR');
      }
      // We don't use awaitSpeakCompletion(true) here because we want to handle interruption manually 
      // and not block the execution flow of the app.
      await _tts.awaitSpeakCompletion(false);
      _tts.setStartHandler(() => _isSpeaking = true);
      _tts.setCompletionHandler(() => _isSpeaking = false);
      _tts.setCancelHandler(() => _isSpeaking = false);
      _tts.setErrorHandler((_) => _isSpeaking = false);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init error: $e');
    }
  }

  String _normalize(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _toConcise(String text) {
    final t = _normalize(text);
    if (t.length <= 46) return t;
    final idx = t.indexOf(RegExp(r'[.!?]'));
    if (idx > 0) return t.substring(0, idx + 1);
    return '${t.substring(0, 42)}...';
  }

  Future<void> speak(
    String text, {
    bool force = false,
    bool interrupt = false,
  }) async {
    if (!AccessibilitySettings.instance.voiceGuidanceEnabled) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) return;
    
    try {
      await _init;
      final now = DateTime.now();
      var message = _normalize(text);
      if (message.isEmpty) return;

      if (!force) {
        final elapsed = now.difference(_lastSpokenAt).inMilliseconds;
        // 동일 멘트 반복 억제 (8초 이내)
        if (message == _lastSpokenText && elapsed < 8000) return;
        // 너무 빠른 연속 안내 억제 (500ms 이내)
        if (elapsed < 500 && !interrupt) return;
        // 이미 말하고 있는데 중단 요청이 없으면 드롭
        if (_isSpeaking && !interrupt) return;
        // 긴 문장은 축약
        message = _toConcise(message);
      }

      if (interrupt) {
        await _tts.stop();
        _isSpeaking = false;
      }
      
      _lastSpokenAt = now;
      _lastSpokenText = message;
      // Use fire-and-forget for speak unless we specifically need to wait
      _tts.speak(message);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak error: $e');
      _isSpeaking = false;
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
