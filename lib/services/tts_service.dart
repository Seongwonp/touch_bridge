import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  double _speed = 1.0;
  static const String _speedKey = 'tts_speed';

  double get speed => _speed;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _speed = prefs.getDouble(_speedKey) ?? 1.0;
    
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(_speed);
    await _tts.setPitch(1.0);
  }

  Future<void> setSpeed(double newSpeed) async {
    _speed = newSpeed;
    await _tts.setSpeechRate(_speed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_speedKey, _speed);
  }

  Future<void> speak(String message) async {
    await _tts.stop();
    await _tts.speak(message);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
