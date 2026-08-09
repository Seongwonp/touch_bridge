import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'accessibility_settings.dart';

/// 발화 우선순위. 높을수록 먼저/즉시 처리된다.
/// - info: 예시·부가 설명
/// - navigation: 화면 이름·조작 안내(최신 하나만 유지)
/// - result: 명령 성공/실패·상태 결과
/// - emergency: 비상정지·안전 경고(현재 발화 중단하고 즉시)
enum TtsPriority { info, navigation, result, emergency }

class _Utterance {
  _Utterance(this.text, this.priority, this.source);
  final String text;
  final TtsPriority priority;
  final String source;
}

/// 앱 전체 단일 TTS 중재자(Speech Arbiter).
///
/// 이전 구현은 "이미 말하는 중"이면 안내를 드롭하거나 interrupt로 잘라 겹침·끊김·
/// 유실이 발생했다. 이제 **직렬 큐**로 순서대로 재생하고, 높은 우선순위(interrupt/
/// emergency)만 현재 발화를 선점한다.
class TtsService {
  factory TtsService() => _instance;
  TtsService._internal() {
    _init = _initTts();
  }
  static final TtsService _instance = TtsService._internal();

  final FlutterTts _tts = FlutterTts();

  /// TTS 초기화 Future — speak() 첫 호출 전 완료 보장
  late final Future<void> _init;

  final List<_Utterance> _queue = [];
  bool _processing = false;
  Completer<void>? _speakCompleter;
  static const int _maxQueue = 8;

  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastSpokenText = '';

  /// TTS 로깅 - [무엇, 언제, 왜]를 기록 (최근 20개 유지)
  final List<({String text, DateTime timestamp, String source})> _speakLog = [];

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
      }
      await _tts.setLanguage('ko-KR');
      // 직렬 큐: 완료/취소/오류 이벤트로 다음 발화를 진행한다.
      await _tts.awaitSpeakCompletion(false);
      _tts.setCompletionHandler(_completeCurrent);
      _tts.setCancelHandler(_completeCurrent);
      _tts.setErrorHandler((_) => _completeCurrent());
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init error: $e');
    }
  }

  void _completeCurrent() {
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
  }

  String _normalize(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _toConcise(String text) {
    final t = _normalize(text);
    // 의도된 안내(옵션 나열 등)를 잘라 정보가 사라지지 않도록 넉넉히 허용하고,
    // 폭주하는 긴 문자열만 마지막 문장 경계에서 자른다.
    if (t.length <= 140) return t;
    final cut = t.substring(0, 140);
    final lastBreak = cut.lastIndexOf(RegExp(r'[.!?]'));
    if (lastBreak > 40) return cut.substring(0, lastBreak + 1);
    return '$cut...';
  }

  void _addLog(String text, String source) {
    _speakLog.add((text: text, timestamp: DateTime.now(), source: source));
    if (_speakLog.length > 20) {
      _speakLog.removeAt(0);
    }
    if (kDebugMode) {
      final timestamp = DateTime.now()
          .toIso8601String()
          .split('T')[1]
          .substring(0, 12);
      debugPrint('[TTS_LOG] [$timestamp] $source: $text');
    }
  }

  /// 최근 TTS 로그 반환 (디버깅용)
  List<String> getRecentLog() {
    return _speakLog
        .map(
          (e) =>
              '${e.timestamp.toIso8601String().substring(11, 19)} | ${e.source} | ${e.text}',
        )
        .toList();
  }

  /// 발화 요청. 기존 호출부 호환을 위해 [force]/[interrupt]/[source]를 유지하고,
  /// [priority]를 추가했다. interrupt=true는 최소 result 우선순위(선점)로 처리된다.
  Future<void> speak(
    String text, {
    bool force = false,
    bool interrupt = false,
    String source = 'app',
    TtsPriority priority = TtsPriority.navigation,
  }) async {
    if (!AccessibilitySettings.instance.voiceGuidanceEnabled) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) return;

    try {
      await _init;
      final message = _toConcise(text);
      if (message.isEmpty) return;

      // interrupt=true는 최소 result 우선순위로 승격(선점).
      var pr = priority;
      if (interrupt && pr.index < TtsPriority.result.index) {
        pr = TtsPriority.result;
      }

      // 동일 멘트 반복 억제 (8초 이내). emergency/force는 예외.
      final now = DateTime.now();
      if (!force &&
          pr != TtsPriority.emergency &&
          message == _lastSpokenText &&
          now.difference(_lastSpokenAt).inMilliseconds < 8000) {
        _addLog('(DROPPED: 동일 멘트 반복)', source);
        return;
      }
      // 큐에 같은 문구가 이미 대기 중이면 중복 제거
      if (_queue.any((q) => q.text == message)) return;

      final utterance = _Utterance(message, pr, source);
      final preempt = interrupt || pr == TtsPriority.emergency;

      if (preempt) {
        // 낮은 우선순위 대기건 제거 후 맨 앞에 넣고, 현재 발화를 중단해 즉시 진행.
        _queue.removeWhere((q) => q.priority.index < pr.index);
        _queue.insert(0, utterance);
        try {
          await _tts.stop();
        } catch (_) {}
        _completeCurrent();
      } else {
        // navigation은 최신 화면 안내 하나만 유지.
        if (pr == TtsPriority.navigation) {
          _queue.removeWhere((q) => q.priority == TtsPriority.navigation);
        }
        _insertByPriority(utterance);
        while (_queue.length > _maxQueue) {
          _queue.removeLast();
        }
      }

      _addLog(message, source);
      unawaited(_processQueue());
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak error: $e');
    }
  }

  void _insertByPriority(_Utterance u) {
    var i = 0;
    while (i < _queue.length && _queue[i].priority.index >= u.priority.index) {
      i++;
    }
    _queue.insert(i, u);
  }

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty) {
        final u = _queue.removeAt(0);
        _lastSpokenAt = DateTime.now();
        _lastSpokenText = u.text;
        _speakCompleter = Completer<void>();
        try {
          _tts.speak(u.text);
        } catch (_) {
          _completeCurrent();
        }
        // 완료/취소/오류 이벤트 또는 안전 타임아웃까지 대기.
        try {
          await _speakCompleter!.future.timeout(const Duration(seconds: 20));
        } catch (_) {}
        _speakCompleter = null;
      }
    } finally {
      _processing = false;
    }
  }

  /// TTS 정지 및 대기열 비우기(명시적 중단).
  Future<void> stop() async {
    _queue.clear();
    try {
      await _tts.stop();
    } catch (_) {}
    _completeCurrent();
    _lastSpokenText = '';
    _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
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
