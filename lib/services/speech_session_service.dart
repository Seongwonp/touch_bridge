import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'accessibility_settings.dart';

/// 화면별 STT 콜백 묶음. [SpeechSessionService.attach]로 등록한다.
class SpeechClient {
  SpeechClient({required this.name, this.onStatus, this.onError});

  final String name;
  final void Function(String status)? onStatus;
  final void Function(Object error)? onError;
}

/// 앱 전체 단일 STT 세션 관리자.
///
/// 배경: `speech_to_text`의 [SpeechToText]는 패키지 차원의 싱글톤이라
/// `initialize()`의 onStatus/onError 콜백은 **최초 1회만** 등록된다.
/// 이전에는 VoiceListeningScreen과 EmergencyStopScreen이 각자 초기화해서
/// (a) 나중에 초기화한 화면의 콜백이 등록되지 않아 비상 화면의 "멈춰" 재청취
/// 루프가 조용히 죽거나, (b) 스택 아래 깔린 화면의 onStatus가 위 화면의 listen
/// 세션 이벤트를 받아 상태가 오염될 수 있었다.
///
/// 이 서비스는 초기화를 한 번만 수행하고, 이벤트를 **가장 나중에 attach한
/// 화면(스택 최상단)** 에만 전달한다. 화면이 dispose에서 detach하면 이전
/// 화면이 다시 이벤트를 받는다 — push/pop 내비게이션과 자연스럽게 맞는 구조.
class SpeechSessionService {
  SpeechSessionService._();
  static final SpeechSessionService instance = SpeechSessionService._();

  final SpeechToText _speech = SpeechToText();
  bool _initAttempted = false;
  bool _available = false;

  final List<SpeechClient> _clients = [];

  SpeechClient? get _current => _clients.isEmpty ? null : _clients.last;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _available;

  /// 패키지 초기화 — 몇 번을 불러도 실제 초기화(콜백 등록)는 한 번만 한다.
  Future<bool> initialize() async {
    if (_initAttempted) return _available;
    _initAttempted = true;

    // macOS 26 beta TCC 버그 가드 (기존 화면별 가드를 이곳으로 일원화).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      _available = false;
      return false;
    }

    try {
      _available = await _speech.initialize(
        onStatus: (status) => _current?.onStatus?.call(status),
        onError: (error) => _current?.onError?.call(error),
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// 화면 활성화 시 콜백을 등록한다. 같은 이름이 이미 있으면 최상단으로 올린다.
  void attach(SpeechClient client) {
    _clients.removeWhere((c) => c.name == client.name);
    _clients.add(client);
  }

  /// 화면 dispose 시 호출 — 스택에서 제거되어 이전 화면이 이벤트를 이어받는다.
  void detach(String name) {
    _clients.removeWhere((c) => c.name == name);
  }

  /// 안드로이드 음성 엔진의 기본 엔드포인팅은 말이 시작되기 전 약 3초만
  /// 기다렸다가 세션을 스스로 닫는다. 앱의 침묵 타이머(설정값, 기본 8초)가
  /// 돌기도 전에 엔진이 먼저 포기해 "음성 인식 실패"로 끝나던 원인이다.
  /// 게다가 "녹음을 시작합니다" 안내가 듣기 시작한 뒤에 나가므로, 안내가
  /// 끝나고 사용자에게 남는 여유는 2초가 채 안 됐다.
  ///
  /// pauseFor를 설정값보다 2초 길게 잡아, 안내 문구와 화면을 함께 갱신하는
  /// 앱 쪽 침묵 타이머가 먼저 동작하고 엔진은 백스톱 역할만 하도록 한다.
  static Duration get _defaultPauseFor => Duration(
    seconds: AccessibilitySettings.instance.sttSilenceTimeoutSeconds + 2,
  );

  /// 한 번의 발화에 이보다 오래 걸릴 일은 없다. 무한 대기만 막는 상한.
  static const Duration _defaultListenFor = Duration(seconds: 60);

  Future<void> listen({
    required void Function(SpeechRecognitionResult result) onResult,
    SpeechListenOptions? listenOptions,
  }) {
    final options = listenOptions ?? SpeechListenOptions(localeId: 'ko_KR');
    return _speech.listen(
      onResult: onResult,
      // 호출측이 직접 지정했으면 존중하고, 아니면 기본값을 채운다.
      listenOptions: options.copyWith(
        pauseFor: options.pauseFor ?? _defaultPauseFor,
        listenFor: options.listenFor ?? _defaultListenFor,
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  // ── 테스트 지원 ─────────────────────────────────────────────────────────
  @visibleForTesting
  void dispatchStatusForTest(String status) =>
      _current?.onStatus?.call(status);

  @visibleForTesting
  void dispatchErrorForTest(Object error) => _current?.onError?.call(error);

  @visibleForTesting
  List<String> get clientNamesForTest =>
      _clients.map((c) => c.name).toList(growable: false);

  @visibleForTesting
  void resetForTest() => _clients.clear();
}
