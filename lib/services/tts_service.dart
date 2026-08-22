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

  /// 테스트에서 스크린리더 활성 상태를 강제하기 위한 오버라이드.
  /// null이면 실제 플랫폼 값을 사용한다.
  @visibleForTesting
  bool? screenReaderOverrideForTest;

  /// 위젯 테스트 전용: TTS 엔진(플랫폼 채널) 호출을 완전히 생략한다.
  ///
  /// testWidgets의 FakeAsync 환경에서는 flutter_tts 채널 호출이 영원히
  /// 완료되지 않아, speak()를 await하는 위젯 로직(예: 전역 비상 버튼)이
  /// 멈춘다. 이 플래그가 켜지면 큐 계약(우선순위/억제/기록)은 그대로 두고
  /// 엔진 호출만 즉시 완료로 처리한다.
  @visibleForTesting
  bool disableEngineForTest = false;

  /// VoiceOver/TalkBack 등 스크린리더가 활성인지.
  bool get _screenReaderActive =>
      screenReaderOverrideForTest ??
      PlatformDispatcher.instance.accessibilityFeatures.accessibleNavigation;

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
  /// [priority]를 추가했다. interrupt=true는 큐에서 최소 result 우선순위(선점)로
  /// 처리되지만, **스크린리더 억제 판단에는 반영되지 않는다** — 스크린리더
  /// 활성 시에도 들려야 하는 발화는 priority를 result/emergency로 명시할 것.
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
      if (!disableEngineForTest) await _init;
      final message = _toConcise(text);
      if (message.isEmpty) return;

      // ── 스크린리더 억제 계약 ──────────────────────────────────────────
      // 억제 여부는 호출부가 명시한 [priority]로만 판단한다. interrupt는
      // "선점 재생" 플래그일 뿐이며 억제 여부와 무관하다(아래에서 큐 순서를
      // 위해 result로 승격되지만, 그 승격은 억제 판단에 반영되지 않는다).
      //
      // - navigation/info: 화면 진입 안내 등. 스크린리더가 포커스/liveRegion
      //   으로 대신 읽으므로 앱 TTS를 억제해 이중 낭독을 막는다.
      // - result/emergency: 명령 결과·실패·비상 안내. 스크린리더가 자동으로
      //   읽어주지 않으므로 절대 억제하지 않는다.
      //
      // 따라서 "스크린리더에서도 반드시 들려야 하는" 발화는 호출부에서
      // priority: TtsPriority.result (또는 emergency)를 **명시**해야 한다.
      // interrupt: true만으로는 스크린리더 활성 시 무음이 된다.
      if (_screenReaderActive && priority.index < TtsPriority.result.index) {
        _addLog('(SUPPRESSED: 스크린리더 활성 - ${priority.name})', source);
        return;
      }

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
        if (!disableEngineForTest) {
          try {
            await _tts.stop();
          } catch (_) {}
        }
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
        // result·emergency만 replay 대상으로 기억한다.
        // navigation·info는 "명령을 확인하고 있습니다" 같은 중간 진행 안내라
        // "다시 말해줘" 대상이 아니다.
        if (u.priority.index >= TtsPriority.result.index) {
          _lastSpokenText = u.text;
        }
        if (disableEngineForTest) {
          // 엔진 없이 즉시 완료 — 큐 순서/기록 계약만 유지.
          continue;
        }
        _speakCompleter = Completer<void>();
        // fire-and-forget이므로 실패가 unhandled Future error로 새지 않게
        // catchError로 반드시 받아준다(테스트/일부 플랫폼에서 TTS 플랫폼
        // 채널이 없을 때 특히 중요 — 그 경우도 큐가 멈추지 않고 넘어가야 한다).
        unawaited(
          _tts.speak(u.text).catchError((_) {
            _completeCurrent();
            return null;
          }),
        );
        // 완료/취소/오류 이벤트 또는 안전 타임아웃까지 대기.
        try {
          await _speakCompleter!.future.timeout(const Duration(seconds: 20));
        } catch (_) {
          // 타임아웃: unawaited로 실행 중인 발화가 계속 재생되어 다음 큐와 겹치는
          // 것을 막기 위해 직접 중단한다.
          try {
            await _tts.stop();
          } catch (_) {}
        }
        _speakCompleter = null;
      }
    } finally {
      _processing = false;
    }
  }

  /// 대기열이 비고 현재 발화가 끝날 때까지 기다린다(최대 [timeout]).
  ///
  /// 용도: 확인 질문("맞으면 예라고 말씀해 주세요")을 말한 **뒤에** 마이크를
  /// 다시 열어야 TTS 소리가 STT에 섞여 들어가거나, 사용자가 질문을 듣는 중에
  /// 침묵 타이머가 돌기 시작하는 문제를 막을 수 있다.
  /// speak()는 재생 완료를 기다리지 않으므로 호출부가 이 메서드로 타이밍을 잡는다.
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while ((_processing || _queue.isNotEmpty) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  /// TTS 정지 및 대기열 비우기(명시적 중단).
  Future<void> stop() async {
    _queue.clear();
    if (!disableEngineForTest) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
    _completeCurrent();
    _lastSpokenText = '';
    _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// 특정 [source]의 대기 중인 발화만 취소한다.
  /// 현재 재생 중인 발화는 멈추지 않고, 다른 source의 대기 항목도 유지된다.
  /// 화면 dispose 시 전역 stop() 대신 이 메서드를 써야 한다 —
  /// stop()은 전체 큐를 지워 다음 화면의 안내까지 날린다.
  void cancelSource(String source) {
    _queue.removeWhere((u) => u.source == source);
  }

  /// 마지막으로 재생을 시작한 안내 문구. "다시 말해줘" 재생(replayLast)에 쓴다.
  String get lastSpokenText => _lastSpokenText;

  /// 마지막 안내를 다시 재생한다. 부엌 소음 등으로 못 들었을 때 쓴다.
  /// force:true로 "동일 멘트 반복" 억제를 우회하고, interrupt로 즉시 재생한다.
  Future<void> replayLast() async {
    if (_lastSpokenText.isEmpty) {
      await speak('다시 들려줄 안내가 없습니다.', interrupt: true);
      return;
    }
    await speak(_lastSpokenText, force: true, interrupt: true);
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
