import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/speech_session_service.dart';
import '../../services/tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../safety/emergency_stop_screen.dart';
import '../safety/stop_done_screen.dart';
import '../../services/app_logger.dart';
import '../../services/ai_backend_service.dart';
import '../../services/active_device_service.dart';
import '../../services/ble_service.dart';
import '../../services/emergency_intent.dart';
import '../../services/emergency_stop_service.dart';
import '../../services/help_intent.dart';
import '../../services/microwave_command_service.dart';
import '../../services/washing_machine_command_service.dart';
import '../../services/ac_command_service.dart';
import '../../services/appliance_command_router.dart';
import '../../services/last_command_service.dart';
import '../../services/status_intent.dart';
import '../../services/device_mapping_service.dart';
import '../../services/feedback_service.dart';
import '../../services/voice_device_resolver.dart';
import '../../services/voice_intent_router.dart';
import '../../services/mapping_execution_service.dart';
import '../../services/single_tap_stop_controller.dart';
import 'widgets/press_progress_view.dart';
import '../../services/home_device_store.dart';
import '../../services/demo_seed.dart';
import '../../services/accessibility_settings.dart';
import '../../services/accessibility_confirmation_policy.dart';
import '../../theme/app_colors.dart';
import 'widgets/voice_wave_visualizer.dart';
import 'widgets/voice_action_buttons.dart';
import 'widgets/voice_example_commands.dart';
import '../../widgets/ble_status_banner.dart';
import '../guardian/guardian_hub_screen.dart';
import '../settings/settings_screen.dart';

class VoiceListeningScreen extends StatefulWidget {
  const VoiceListeningScreen({
    super.key,
    this.deviceId,
    this.deviceName,
    this.autoStart = false,
    this.initialText,
  });

  final String? deviceId;
  final String? deviceName;
  final bool autoStart;

  /// 열자마자 이 문장을 말한 것처럼 처리한다(예: 정지 뒤 "가전 취소 버튼 누르기" → "취소").
  /// 가전 버튼을 누르는 명령이면 평소처럼 '실행'·'취소' 확인을 거친다.
  final String? initialText;

  @override
  State<VoiceListeningScreen> createState() => VoiceListeningScreenState();
}

/// 공개 State: 위젯 테스트가 실행 중 화면(단일 탭 정지)까지 도달할 수 있도록
/// [handleCommandForTest] 등 테스트 전용 진입점을 둔다.
class VoiceListeningScreenState extends State<VoiceListeningScreen> {
  /// 매핑이 없을 때 데모 목데이터 좌표로 누를지. 데모 빌드에서만 켠다.
  @visibleForTesting
  static bool allowMockMappingFallback = DemoSeed.enabled;

  final TtsService _tts = TtsService();
  final math.Random _random = math.Random();
  // 공용 STT 세션: STT 패키지가 싱글톤이라 콜백이 최초 1회만 등록된다.
  // 화면마다 따로 초기화하면 다른 화면(비상 정지)과 이벤트가 섞이므로,
  // 이벤트는 스택 최상단 화면에만 전달한다.
  final SpeechSessionService _speechSession = SpeechSessionService.instance;

  bool _isRecording = false;
  bool _isProcessing = false;
  String _statusMessage = '말하기 버튼을 눌러 명령하세요.';
  String _recognizedText = '아직 인식된 명령이 없어요.';
  bool _speechEnabled = false;

  String _lastWords = '';

  // 부엌 소음 대응: STT 인식 신뢰도가 낮으면 바로 실행하지 않고 인식한
  // 문장을 먼저 확인한다. 임계값과 missingConfidence(-1) 처리 규칙은
  // VoiceIntentRouter가 갖는다.
  double _lastConfidence = SpeechRecognitionWords.missingConfidence;
  String? _pendingLowConfidenceText;

  /// 잘못 들었을 수 있어 되묻는 질문("…라고 들었어요. 맞나요?"). 화면에 질문과
  /// '맞아요'·'아니에요' 버튼을 띄운다. 예전에는 이 확인만 버튼이 없어 말로만 답할
  /// 수 있었다(외부 평가).
  String? _lowConfidenceQuestion;

  /// 가전 실행 확인 질문. [_pendingCommandData]와 함께 있을 때 화면에
  /// '실행'·'취소' 버튼을 보인다(음성 '네'·'아니요'도 그대로 받는다).
  String? _confirmQuestion;

  Timer? _waveTimer;
  List<double> _waveHeights = const [
    0.20,
    0.50,
    0.80,
    1.00,
    0.60,
    0.30,
    1.00,
    0.50,
    0.70,
    0.80,
    0.20,
  ];

  Timer? _recordingTimeoutTimer;
  Timer? _silenceTimer;
  Timer? _actionResetTimer;
  Map<String, dynamic>? _pendingCommandData;
  bool _micArmed = false;
  bool _isStartingRecording = false;
  int _analysisRequestId = 0;
  /// 실행 확인("네"/"아니요")을 기다리는 중인지. 질문을 듣고 생각할 시간이 필요하므로
  /// 듣는 시간을 길게 둔다. 예전에는 녹음 상한이 10초뿐이라 침묵 설정을 늘려도
  /// 먼저 끊겼다(외부 평가).
  bool get _awaitingConfirm =>
      _pendingCommandData != null || _pendingLowConfidenceText != null;

  /// 무입력이어도 확인 답을 기다리는 최소 시간(WCAG 2.2.1의 20초를 따름).
  static const int _confirmWaitSeconds = 20;

  Duration get _maxRecordingDuration => _awaitingConfirm
      ? const Duration(seconds: _confirmWaitSeconds + 10)
      : const Duration(seconds: 20);

  String? _resolvedDeviceId;
  String? _resolvedDeviceName;

  // 연속 실패 횟수 — 2회 이상 시 "도움말" 힌트를 추가한다.
  int _consecutiveFailures = 0;
  /// 기기 확인 되묻기 연속 횟수. 한도를 넘으면 자동 재청취를 멈춘다.
  int _followUpAttempts = 0;
  static const int _kMaxFollowUpAttempts = 2;

  /// 버튼을 실제로 누르는 중인지. true면 진행 화면을 띄운다.
  bool _isExecuting = false;
  String _executingLabel = '';

  /// 누르기가 끝난 뒤 잠시 띄우는 완료 화면 문구. 비어 있으면 표시하지 않는다.
  String _pressDoneLabel = '';

  /// 직전 시퀀스가 비상 정지로 끊겼는가. 정지 뒤 늦게 돌아온 실행 결과가
  /// 정지 안내(liveRegion·TTS·효과음)를 덮지 않게 하는 데 쓴다.
  bool _lastSequenceStopped = false;

  /// 전송 시퀀스가 아직 도는 중인가 (정지 미확인 화면 유지 판단용).
  bool _sequenceRunning = false;

  /// 이번 실행(`_beginPress` 이후)에 정지 요청이 있었는가.
  ///
  /// 정지 버튼은 실행 토큰(epoch)이 잡히기 전부터 보인다(안내 음성, 기기 연결,
  /// 매핑 로드가 먼저 돈다). 그 사이에 정지하면 epoch는 올라가지만, 아직 시작
  /// 전인 시퀀스는 올라간 값을 새 기준으로 잡아 버튼을 전부 누르게 된다.
  /// 그래서 epoch와 별개로 화면이 직접 기록한다.
  ///
  /// epoch는 BLE 링크 끊김에도 바뀐다. 이 값으로 "사용자 정지"와 "연결 끊김"을
  /// 구분해, 끊김을 정지로 오인하고 아무 안내 없이 끝내지 않게 한다.
  bool _stopRequestedThisRun = false;
  StreamSubscription<String>? _stopRequestSub;

  /// 시퀀스는 끝났지만 정지가 확인되지 않은 상태 — 진행 뷰를 재시도 UI로 유지한다.
  bool get _awaitingStopResolution =>
      _lastSequenceStopped &&
      !_sequenceRunning &&
      (_stopController.inFlight || _stopController.canRetry);

  @visibleForTesting
  bool get isExecutingForTest => _isExecuting;

  @visibleForTesting
  String get statusMessageForTest => _statusMessage;

  @visibleForTesting
  bool get lastSequenceStoppedForTest => _lastSequenceStopped;

  /// 테스트에서 해석된 명령을 직접 넣어 실행 화면까지 진행시킨다.
  @visibleForTesting
  Future<void> handleCommandForTest(
    Map<String, dynamic> data, {
    bool confirmed = false,
  }) =>
      _handleCommand(data, recognizedText: 'test', forceExecution: confirmed);

  /// 테스트용: 사용자가 이미 '실행'으로 확인한 명령을 넣는다.
  @visibleForTesting
  Future<void> runConfirmedForTest(Map<String, dynamic> data) =>
      handleCommandForTest(data, confirmed: true);

  /// 테스트용: 음성 인식 결과(문장·신뢰도)를 받은 것처럼 처리한다.
  @visibleForTesting
  Future<void> processSpeechForTest(String text, {required double confidence}) {
    _lastConfidence = confidence;
    _recognizedText = text;
    return _sendTextToGemini(text);
  }

  /// 테스트용: 잘못 들었을 수 있어 되묻는 질문.
  @visibleForTesting
  String? get lowConfidenceQuestionForTest =>
      _pendingLowConfidenceText == null ? null : _lowConfidenceQuestion;

  /// 테스트용: 화면에 떠 있는 실행 확인 질문.
  @visibleForTesting
  String? get confirmQuestionForTest =>
      _pendingCommandData == null ? null : _confirmQuestion;
  Timer? _pressDoneTimer;
  static const _kExamplesSeenKey = 'voice_examples_announced';

  /// 실행 중 화면의 단일 탭 비상 정지. 확인 단계 없이 우선 정지 경로를 부른다.
  /// 실행 구간에는 마이크가 닫혀 있어 음성 "멈춰"로는 정지할 수 없다.
  late final SingleTapStopController _stopController = SingleTapStopController(
    stop: () => EmergencyStopService.instance.stopActiveDevice(),
  );

  @override
  void initState() {
    super.initState();
    // 전역 비상 버튼 등 이 화면 밖에서 보낸 정지도 이번 실행을 무효화한다.
    // (broadcast·sync 스트림이라 정지 명령이 나가는 즉시 동기적으로 들어온다.)
    _stopRequestSub = BleService.instance.stopRequests.listen((_) {
      if (_isExecuting) _stopRequestedThisRun = true;
    });
    if (!AiBackendService.instance.isConfigured) {
      // 서버가 없어도 마이크는 연다. "30초 돌려줘" 같은 앱 안 규칙은 서버 없이 처리되고,
      // 서버가 필요한 명령만 실패를 알린다. 예전에는 마이크 자체를 막아 간단한 명령도
      // 못 했다(외부 평가). 키 이름은 사용자에게 말하지 않고 로그로 남긴다.
      AppLogger.warn('voice.backend_not_configured', {'key': 'AI_BACKEND_URL'});
      _statusMessage = '음성 해석 서버가 설정되지 않아 "30초 돌려줘" 같은 간단한 명령만 쓸 수 있습니다.';
    }
    _initSpeech().then((_) async {
        if (!mounted) return;
        final initial = widget.initialText;
        if (initial != null && initial.isNotEmpty) {
          setState(() {
            _recognizedText = initial;
            _isProcessing = true;
          });
          _sendTextToGemini(initial);
          return;
        }
        if (widget.autoStart && _speechEnabled) {
          // 낭독기는 화면에 들어오면 화면 이름과 포커스 항목을 읽는다. 그 사이 마이크를
          // 열면 안드로이드가 다른 소리를 줄여 낭독이 뚝뚝 끊기고("쉉 명루ㅕㅇ"), 마이크는
          // 낭독 소리만 듣다 "말씀이 들리지 않았습니다"로 끝났다(실기). 낭독이 끝날
          // 여유를 두고 연다. 마이크가 열리면 띵 소리가 난다.
          if (AccessibilitySettings.isScreenReaderActive) {
            await Future<void>.delayed(const Duration(milliseconds: 3000));
            if (!mounted || _isRecording || _isProcessing) return;
          }
          _toggleRecording();
        }
      });
  }

  @override
  void dispose() {
    _speechSession.micWindowActive = false;
    _waveTimer?.cancel();
    _recordingTimeoutTimer?.cancel();
    _silenceTimer?.cancel();
    _actionResetTimer?.cancel();
    _pressDoneTimer?.cancel();
    _stopController.dispose();
    _stopRequestSub?.cancel();
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지운다.
    // 공용 STT 세션 스택에서도 빠져 이전 화면이 이벤트를 이어받게 한다.
    _speechSession.detach('VoiceListeningScreen');
    _speechSession.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      if (mounted) {
        setState(() => _statusMessage = 'macOS 앱에서는 음성 인식이 지원되지 않습니다.');
      }
      return;
    }
    _speechSession.attach(
      SpeechClient(
        name: 'VoiceListeningScreen',
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'listening') {
            // 듣기 창이 이미 끝났는데 늦게 열린 엔진이면 바로 닫는다(끝 안내 뒤 마이크가
            // 몇 초 더 열려 있던 문제 — 실기).
            if ((_listenWindowStart == null && !_isRecording) || _isProcessing) {
              _speechSession.stop();
              return;
            }
            setState(() {
              _isRecording = true;
              _statusMessage = '듣고 있습니다.';
            });
            return;
          }
          if ((status == 'done' || status == 'notListening') && _isRecording) {
            _onSttNaturalEnd();
          }
        },
        onError: (_) {
          // 조용히 다시 여는 중이거나 이미 끝난 듣기에서 늦게 온 오류는 무시한다. 예전에는
          // 다시 여는 사이에 "음성 인식에 실패했습니다"를 알렸다(실기).
          if (_quietRestart || !_isRecording) return;
          // "말 없음"·"인식 결과 없음"으로 일찍 끝난 것이면 듣기 창 안에서 조용히 다시 연다.
          if (mounted && _lastWords.isEmpty && _canQuietRelisten) {
            AppLogger.info('voice.stt_quiet_relisten_after_error');
            _quietRelisten();
            return;
          }
          _listenWindowStart = null;
          _speechSession.micWindowActive = false;
          if (mounted) {
            _speak('음성 인식에 실패했습니다. 마이크 버튼을 다시 눌러주세요.');
            setState(() {
              _statusMessage = '음성 인식에 실패했습니다. 마이크 버튼을 다시 눌러주세요.';
              _isProcessing = false;
              _isRecording = false;
            });
            _stopWaveAnimation();
            _recordingTimeoutTimer?.cancel();
          }
        },
      ),
    );
    _speechEnabled = await _speechSession.initialize();
    if (_speechEnabled) {
      await _speak('음성 명령입니다. 마이크 버튼을 눌러 명령하세요.', priority: TtsPriority.navigation);
      // autoStart가 아닐 때만 예시를 낭독한다 — 자동 녹음 시작 흐름과 충돌을 막기 위함.
      if (!widget.autoStart && mounted) {
        final prefs = await SharedPreferences.getInstance();
        final seen = prefs.getBool(_kExamplesSeenKey) ?? false;
        if (!seen) {
          await prefs.setBool(_kExamplesSeenKey, true);
          final examples = kVoiceExampleCommands.take(4).join(', ');
          await _speak('예시 명령으로는 $examples 등이 있습니다.', priority: TtsPriority.navigation);
        }
      }
    } else {
      _speak('음성 인식 기능을 사용할 수 없습니다.');
      setState(() {
        _statusMessage = '음성 인식 기능을 사용할 수 없습니다.';
      });
    }
  }

  /// 이 화면의 발화는 대부분 명령 결과·실패·확인 질문이다. 기본값을 result로
  /// 두어 스크린리더 활성 시에도 들리게 하고, 화면 진입 안내처럼 스크린리더가
  /// 대신 읽는 것만 호출부에서 navigation을 명시한다.
  Future<void> _speak(
    String message, {
    String source = 'voicelisteningScreen',
    bool interrupt = false,
    TtsPriority priority = TtsPriority.result,
  }) async {
    await _tts.speak(
      message,
      source: source,
      interrupt: interrupt,
      priority: priority,
    );
  }

  /// 말을 시작한 뒤 마지막 말이 들린 다음 이만큼 조용하면 끝낸다. 예전에는 말이 끝나도
  /// 침묵 설정(기본 8초)만큼 기다려, 말한 뒤 한참 있다가 처리됐다(실기 사용자 의견).
  /// 말을 시작하기 전의 기다림은 듣기 창(명령 20초·확인 30초)이 맡는다.
  static const _endOfSpeechSilence = Duration(milliseconds: 1500);

  void _resetSilenceTimer({Duration? after}) {
    _silenceTimer?.cancel();
    final setting = AccessibilitySettings.instance.sttSilenceTimeoutSeconds;
    _silenceTimer = Timer(
      after ??
          (_lastWords.isNotEmpty
              ? _endOfSpeechSilence
              : Duration(
                  seconds: _awaitingConfirm
                      ? math.max(setting, _confirmWaitSeconds)
                      : setting,
                )),
      () {
      if (!mounted || !_isRecording || _isProcessing) return;

      // 앱·낭독기 안내가 녹음된 것이면 말이 없던 것으로 본다.
      if (_lastWords.isNotEmpty) _lastWords = stripEchoPhrases(_lastWords);
      if (_lastWords.isNotEmpty && _isEcho(_lastWords)) {
        AppLogger.info('voice.stt_echo_ignored', {'lastWords': _lastWords});
        _lastWords = '';
      }

      // 인식된 말이 있으면 녹음을 끝내고 분석으로 넘긴다.
      if (_lastWords.isNotEmpty) {
        AppLogger.info('voice.silence_timer.trigger_stop', {
          'lastWords': _lastWords,
        });
        _toggleRecording();
        return;
      }

      // 듣기 창이 열려 있는 동안은 끝내지 않는다. 끝은 창 타이머가 한 번만 알린다.
      // (실기: 말을 막 시작했는데 "말씀이 들리지 않았습니다"가 먼저 나왔다.)
      if (_listenWindowStart != null) {
        _resetSilenceTimer();
        return;
      }
      _listenWindowStart = null;
      _speechSession.micWindowActive = false;
      AppLogger.info('voice.silence_timer.no_input');
      _speechSession.stop();
      _recordingTimeoutTimer?.cancel();
      _stopWaveAnimation();
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _statusMessage = '말씀이 들리지 않았습니다. 다시 말하려면 말하기 시작을 누르세요.';
      });
      _speak('말씀이 들리지 않았습니다. 다시 말하려면 말하기 시작을 누르세요.');
    });
  }

  /// 한 번의 "듣기"가 시작된 시각. 안드로이드 음성 엔진은 말이 시작되기 전 몇 초만
  /// 기다리고 "말 없음"으로 끝내 버려(설정한 대기 시간을 무시), 생각하는 사이 마이크가
  /// 닫혔다(실기). 이 시각부터 [_maxRecordingDuration] 안이면 조용히 다시 연다.
  DateTime? _listenWindowStart;
  bool _quietRestart = false;

  bool get _canQuietRelisten {
    final start = _listenWindowStart;
    if (start == null || !mounted || _isExecuting || _isProcessing) return false;
    // 다시 여는 데 드는 시간을 감안해 끝나기 2초 전까지만.
    return DateTime.now().difference(start) <
        _maxRecordingDuration - const Duration(seconds: 2);
  }

  /// 듣기 창이 끝났다. 들은 말이 있으면 처리하고, 없으면 한 번만 알린다.
  void _onListenWindowEnd() {
    if (!mounted || _isProcessing || _isExecuting) return;
    _listenWindowStart = null; // 이후에는 조용히 다시 열지 않는다.
    _speechSession.micWindowActive = false;
    if (!_isRecording && !_quietRestart) return;
    _quietRestart = false;
    if (_lastWords.isNotEmpty && !_isEcho(_lastWords)) {
      if (_isRecording) _toggleRecording();
      return;
    }
    _speechSession.stop();
    _silenceTimer?.cancel();
    _stopWaveAnimation();
    const msg = '말씀이 들리지 않았습니다. 다시 말하려면 말하기 시작을 누르세요.';
    setState(() {
      _isRecording = false;
      _isProcessing = false;
      _statusMessage = msg;
    });
    _speak(msg);
  }

  /// 말 없이 끝난 듣기를 띵 소리 없이 다시 연다(같은 듣기 창 안에서).
  void _quietRelisten() {
    if (_isProcessing || _listenWindowStart == null) return;
    _silenceTimer?.cancel();
    setState(() => _isRecording = false);
    _quietRestart = true;
    Future<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      // 기다리는 사이 듣기 창이 끝났으면(끝 안내를 이미 했으면) 다시 열지 않는다.
      if (!mounted ||
          _listenWindowStart == null ||
          _isRecording ||
          _isProcessing ||
          _isExecuting) {
        _quietRestart = false;
        return;
      }
      await _toggleRecording();
      _quietRestart = false;
    });
  }

  /// 앱이나 낭독기가 방금 읽은 문구를 마이크가 다시 받은 것인지. 그런 소리를 명령으로
  /// 보내지 않는다(실기: 낭독기의 '말씀해 주세요'가 녹음돼 서버로 갔다).
  bool _isEcho(String words) => echoMatches(words, [
        '말씀해 주세요',
        '듣고 있습니다',
        '말하기 시작',
        '말하기',
        '듣는 중 누르면 멈춤',
        '녹음 취소',
        '분석 취소',
        '분석 중',
        // 이 화면의 고정 문구(낭독기가 화면을 읽을 때 나오는 말).
        '말하기 버튼을 눌러 명령하세요',
        '음성 명령입니다. 마이크 버튼을 눌러 명령하세요',
        '예시 명령어',
        '명령을 확인하고 있습니다',
        ..._tts.recentSpokenTexts(),
        // 화면의 영어 'Touch Bridge'를 엔진이 한글로 받아 적는 경우.
        '터치 브릿지 연결 안 됨',
        '터치 브리지 연결 안 됨',
        '재연결 중',
        _statusMessage,
        ?_confirmQuestion,
        ?_lowConfidenceQuestion,
      ]);

  /// 사용자 말 앞뒤에 섞여 녹음된 앱·낭독기 고정 문구를 지운다(예: "듣고 있습니다 30초
  /// 돌려줘" → "30초 돌려줘"). 문구만 남는 경우는 [echoMatches]가 걸러낸다.
  @visibleForTesting
  static String stripEchoPhrases(String words) {
    var out = words;
    for (final phrase in const [
      '듣고 있습니다',
      '듣고 있어요',
      '말씀해 주세요',
      '말하기 시작',
      '녹음 취소',
      '듣는 중',
      '누르면 멈춤',
    ]) {
      // 띄어쓰기가 달라도 지운다.
      final pattern = phrase.split('').where((c) => c != ' ').map(RegExp.escape).join(r'\s*');
      out = out.replaceAll(RegExp(pattern), ' ');
    }
    return out.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// [words]가 [prompts] 중 하나를 다시 받은 소리인지(띄어쓰기·문장부호 무시).
  /// 4글자 이상이면 안내 문장의 일부만 들려도 같은 것으로 본다.
  @visibleForTesting
  static bool echoMatches(String words, List<String> prompts) {
    String n(String t) => t.replaceAll(RegExp(r'[\s.,!?~"]'), '');
    // 따옴표 안은 사용자가 한 말을 되읽은 부분이다("…라고 들었어요"). 사용자가 같은
    // 말을 다시 하면 메아리로 오인하지 않게 빼고 비교한다.
    String unquote(String t) => t.replaceAll(RegExp(r'"[^"]*"'), '');
    final w = n(words);
    if (w.isEmpty) return false;
    return prompts.map((p) => n(unquote(p))).any(
          (p) => p.isNotEmpty && (w == p || (w.length >= 4 && p.contains(w))),
        );
  }

  void _onSttNaturalEnd() {
    if (!_isRecording || _isProcessing) return;
    if (_lastWords.isNotEmpty) _lastWords = stripEchoPhrases(_lastWords);
    if (_lastWords.isNotEmpty && _isEcho(_lastWords)) {
      AppLogger.info('voice.stt_echo_ignored', {'lastWords': _lastWords});
      _lastWords = '';
    }
    if (_lastWords.isEmpty && _canQuietRelisten) {
      AppLogger.info('voice.stt_quiet_relisten');
      _quietRelisten();
      return;
    }
    _listenWindowStart = null;
    _speechSession.micWindowActive = false;

    AppLogger.info('voice.stt_natural_end', {'lastWords': _lastWords});
    _silenceTimer?.cancel();
    _recordingTimeoutTimer?.cancel();
    _stopWaveAnimation();

    setState(() {
      _isRecording = false;
      _isProcessing = _lastWords.isNotEmpty;
      _statusMessage = _lastWords.isNotEmpty
          ? '명령을 확인하고 있습니다.'
          : '말씀이 들리지 않았습니다.';
    });

    if (_lastWords.isNotEmpty) {
      FeedbackService.instance.playDing();
      _speak('명령을 확인하고 있습니다.');
      _sendTextToGemini(_lastWords);
    } else if (!_isProcessing) {
      _speak('말씀이 들리지 않았습니다. 다시 말하려면 말하기 시작을 누르세요.');
    }
  }

  void _startWaveAnimation() {
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && _isRecording) {
        setState(() {
          _waveHeights = List<double>.generate(
            _waveHeights.length,
            (index) => 0.2 + _random.nextDouble() * 0.8,
          );
        });
      }
    });
  }

  void _stopWaveAnimation() {
    _waveTimer?.cancel();
    setState(() {
      _waveHeights = const [
        0.20,
        0.50,
        0.80,
        1.00,
        0.60,
        0.30,
        1.00,
        0.50,
        0.70,
        0.80,
        0.20,
      ];
    });
  }

  Future<void> _toggleRecording() async {
    if (_isStartingRecording) return;
    if (!_speechEnabled) {
      _speak('음성 인식 기능을 사용할 수 없습니다.');
      return;
    }

    if (_isRecording) {
      _listenWindowStart = null;
      _speechSession.micWindowActive = false;
      _speechSession.stop();
      _recordingTimeoutTimer?.cancel();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _statusMessage = '명령을 확인하고 있습니다.';
      });
      _stopWaveAnimation();
      _speak('녹음이 종료되었습니다.', priority: TtsPriority.navigation);
      if (_lastWords.isNotEmpty) _lastWords = stripEchoPhrases(_lastWords);
      if (_lastWords.isNotEmpty && _isEcho(_lastWords)) {
        AppLogger.info('voice.stt_echo_ignored', {'lastWords': _lastWords});
        _lastWords = '';
      }
      if (_lastWords.isNotEmpty) {
        _sendTextToGemini(_lastWords);
      } else {
        _speak('인식된 음성이 없습니다.');
        setState(() {
          _statusMessage = '말씀이 들리지 않았습니다.';
          _isProcessing = false;
        });
      }
    } else {
      // 조용히 다시 열려던 참에 듣기 창이 끝났으면 열지 않는다.
      if (_quietRestart && (_listenWindowStart == null || _isProcessing)) return;
      _isStartingRecording = true;
      if (!_quietRestart) {
        _listenWindowStart = DateTime.now();
        _speechSession.micWindowActive = true;
      }
      _lastWords = '';
      // 이전 녹음의 신뢰도가 다음 녹음 게이트에 재사용되는 것을 막는다.
      _lastConfidence = SpeechRecognitionWords.missingConfidence;
      try {
        if (_speechSession.isListening) {
          await _speechSession.stop();
        }
        if (mounted) {
          setState(() {
            _isRecording = true;
            _statusMessage = '듣고 있습니다.';
          });
        }
        await _speechSession.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _lastWords = result.recognizedWords;
                _recognizedText = _lastWords;
              });
              // 최종 결과일 때만 신뢰도를 갱신한다(부분 인식 중간값은 신뢰할
              // 수 없다). 플랫폼이 신뢰도를 안 주면(missingConfidence) 그대로
              // 둬 게이트가 걸리지 않게 한다.
              if (result.finalResult) {
                _lastConfidence = result.confidence;
              }
              if (_lastWords.isNotEmpty) {
                // 엔진이 문장이 끝났다고 알리면(최종 결과) 거의 바로 끝낸다.
                _resetSilenceTimer(
                  after: result.finalResult
                      ? const Duration(milliseconds: 400)
                      : null,
                );
              }
            }
          },
          listenOptions: SpeechListenOptions(
            localeId: 'ko_KR',
            listenMode: ListenMode.dictation,
            partialResults: true,
            // 확인 답을 기다릴 때는 엔진도 앱 침묵 타이머보다 먼저 닫히지 않게 한다.
            pauseFor: _awaitingConfirm
                ? const Duration(seconds: _confirmWaitSeconds + 2)
                : null,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (_speechSession.isListening || _isRecording) {
          _startWaveAnimation();
          if (!_quietRestart) {
            // 조용히 다시 열 때는 띵 소리를 반복하지 않는다(처음 열 때 한 번만).
            FeedbackService.instance.playDing();
            FeedbackService.instance.vibrateSuccess();
          }
          // "녹음을 시작합니다"는 말하지 않는다. 마이크가 이미 열린 뒤라 낭독기를
          // 쓰지 않는 사용자는 앱 자신의 안내가 녹음됐다(외부 평가). 띵 소리와
          // 진동, 낭독기의 "듣고 있습니다"(liveRegion)로 알린다.

          // 멘트가 끝날 때까지 기다린 후(약 1.5초) 침묵 감지 시작
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && _isRecording) _resetSilenceTimer();
          });

          // 듣기 창 전체에 한 번만 건다(조용히 다시 열 때는 새로 걸지 않는다).
          if (!_quietRestart) {
            _recordingTimeoutTimer?.cancel(); // 앞 듣기 창의 타이머가 늦게 울리지 않게.
            _recordingTimeoutTimer = Timer(_maxRecordingDuration, _onListenWindowEnd);
          }
        }
      } catch (_) {
        setState(() {
          _isRecording = false;
          _statusMessage = '오류가 발생했습니다.';
        });
      } finally {
        _isStartingRecording = false;
      }
    }
  }

  /// 실행 확인 중에는 질문을 '실행'·'취소' 바로 위에 계속 보여 준다. 예전에는 마이크가
  /// 켜지면 질문이 "듣고 있습니다"로 덮여, 무엇을 실행하는지 다시 읽을 수 없었다(외부
  /// 평가). 질문은 이미 음성과 상태 문구로 알렸으므로 liveRegion이 아니다(두 번 읽히지 않게).
  Widget _buildConfirmQuestionCard(double rs, [String? text]) {
    final question = text ?? _confirmQuestion ?? '';
    return Semantics(
      label: '실행 확인 질문. $question',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16 * rs),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16 * rs),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Text(
          question,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20 * rs,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }


  static const confirmRunKey = Key('voice_confirm_run');
  static const confirmCancelKey = Key('voice_confirm_cancel');

  /// 화면의 '실행' 버튼. 음성 '네'와 같은 경로로 확인된 명령을 실행한다.
  Future<void> _confirmPendingCommand() async {
    final data = _pendingCommandData;
    if (data == null || _isExecuting) return;
    _stopListeningForConfirm();
    setState(() {
      _pendingCommandData = null;
      _confirmQuestion = null;
    });
    await _handleCommand(
      data,
      recognizedText: _recognizedText,
      forceExecution: true,
    );
  }

  /// 화면의 '취소' 버튼. 음성 '아니요'와 같다.
  Future<void> _cancelPendingCommand() async {
    if (_pendingCommandData == null) return;
    _stopListeningForConfirm();
    setState(() {
      _pendingCommandData = null;
      _confirmQuestion = null;
      _statusMessage = '알겠습니다. 취소할게요.';
    });
    await _speak('알겠습니다. 취소할게요.');
  }

  /// 되묻기의 '맞아요'. 음성 "네"와 같다: 들은 문장을 믿을 만한 것으로 보고 다시 처리한다.
  Future<void> _acceptLowConfidence() async {
    final text = _pendingLowConfidenceText;
    if (text == null) return;
    _stopListeningForConfirm();
    setState(() {
      _pendingLowConfidenceText = null;
      _lowConfidenceQuestion = null;
      _isProcessing = true;
    });
    _lastConfidence = 1.0;
    await _sendTextToGemini(text);
  }

  /// 되묻기의 '아니에요'. 음성 "아니요"와 같다: 다시 말하도록 마이크를 연다.
  Future<void> _rejectLowConfidence() async {
    if (_pendingLowConfidenceText == null) return;
    _stopListeningForConfirm();
    const msg = '알겠습니다. 다시 말씀해 주세요.';
    setState(() {
      _pendingLowConfidenceText = null;
      _lowConfidenceQuestion = null;
      _statusMessage = msg;
    });
    if (!AccessibilitySettings.isScreenReaderActive) await _speak(msg);
    _restartListeningAfterPrompt();
  }

  static const lowConfidenceYesKey = Key('voice_low_confidence_yes');
  static const lowConfidenceNoKey = Key('voice_low_confidence_no');

  Widget _buildLowConfidenceButtons(double rs) {
    Widget big(Key key, String label, VoidCallback onPressed, {bool primary = false}) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: (primary ? 120 : 88) * rs),
        child: primary
            ? FilledButton(
                key: key,
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24 * rs),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 30 * rs, fontWeight: FontWeight.w900),
                ),
              )
            : OutlinedButton(
                key: key,
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.textSecondary, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24 * rs),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 26 * rs, fontWeight: FontWeight.w900),
                ),
              ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 16 * rs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          big(lowConfidenceYesKey, '맞아요', _acceptLowConfidence, primary: true),
          SizedBox(height: 14 * rs),
          big(lowConfidenceNoKey, '아니에요', _rejectLowConfidence),
        ],
      ),
    );
  }

  /// 확인 질문 뒤에 다시 열어 둔 마이크를 닫는다(버튼으로 답했으므로).
  void _stopListeningForConfirm() {
    _cancelPendingRelisten();
    _listenWindowStart = null;
    _speechSession.micWindowActive = false;
    _speechSession.stop();
    _silenceTimer?.cancel();
    _recordingTimeoutTimer?.cancel();
    _stopWaveAnimation();
    if (_isRecording) setState(() => _isRecording = false);
  }

  /// 기본 답은 음성 "네"·"아니요"다(질문 뒤 마이크가 다시 열린다). 버튼은 손으로
  /// 답하고 싶을 때를 위한 것이라, 화면을 더듬어도 바로 닿도록 '실행'을 가로 전체에
  /// 아주 크게, '취소'를 그 아래에 둔다. 낭독 순서도 실행 → 취소다.
  Widget _buildConfirmButtons(double rs) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16 * rs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: 140 * rs),
            child: FilledButton(
              key: confirmRunKey,
              onPressed: _confirmPendingCommand,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24 * rs),
                ),
              ),
              child: Text(
                '실행',
                style: TextStyle(fontSize: 34 * rs, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          SizedBox(height: 14 * rs),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: 88 * rs),
            child: OutlinedButton(
              key: confirmCancelKey,
              onPressed: _cancelPendingCommand,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.textSecondary, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24 * rs),
                ),
              ),
              child: Text(
                '취소',
                style: TextStyle(fontSize: 26 * rs, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleMicTap() {
    if (_isProcessing) return;

    // 마이크를 켜고 끄는 것은 물리 동작이 아니므로 낭독기 사용자에게는 확인 탭을 겹치지 않는다.
    final screenReaderActive =
        MediaQuery.maybeOf(context)?.accessibleNavigation ??
        AccessibilitySettings.isScreenReaderActive;
    if (!_micArmed &&
        AccessibilityConfirmationPolicy.requiresAppConfirmation(
          kind: ConfirmationActionKind.navigation,
          screenReaderActive: screenReaderActive,
        )) {
      setState(() => _micArmed = true);
      HapticFeedback.mediumImpact();
      _actionResetTimer?.cancel();
      _actionResetTimer = Timer(kDoubleTapArmTimeout, () {
        if (mounted) setState(() => _micArmed = false);
      });
      _speak(_isRecording ? '녹음 중지' : '녹음 시작', priority: TtsPriority.navigation);
      return;
    }

    _actionResetTimer?.cancel();
    setState(() => _micArmed = false);
    _toggleRecording();
  }

  Future<List<RegisteredVoiceDevice>> _loadRegisteredDevices() async {
    final devices = await HomeDeviceStore.loadDevices();
    return devices
        .map(RegisteredVoiceDevice.fromJson)
        .where((device) => device.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _activateVoiceDevice(RegisteredVoiceDevice device) async {
    final preservedBleId =
        device.bleId ?? ActiveDeviceService.instance.getActiveBleId();
    final preservedBleName =
        device.bleName ?? await ActiveDeviceService.instance.getActiveBleName();

    _resolvedDeviceId = device.id;
    _resolvedDeviceName = device.name;

    // 이미 이 가전이 활성이면 다시 고르지 않는다. 다시 고르면 연결을 기다리느라(장치가
    // 꺼져 있으면 약 5초) 확인 질문이 늦게 나왔다(실기). 연결은 보낼 때 따로 한다.
    final active = ActiveDeviceService.instance;
    if (active.getActiveDeviceId() == device.id &&
        active.getActiveBleId() == preservedBleId) {
      return;
    }

    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: device.id,
      deviceName: device.name,
      bleId: preservedBleId,
      bleName: preservedBleName,
    );
  }

  /// "2번 버튼을 누릅니다." → "2번 버튼을 누르는 중입니다."
  static String _toPressingMessage(String base) =>
      base.contains('누릅니다') ? base.replaceAll('누릅니다', '누르는 중입니다') : base;

  /// "2번 버튼을 누릅니다." → "2번 버튼을 누르도록 기기에 전달했습니다."
  ///
  /// BLE write 성공은 기기가 눌렀다는 확인이 아니다(이 경로에는 ACK가 없다).
  /// 완료 확인은 비상 정지(ACK 기반)에서만 말한다.
  static String _toDoneMessage(String base) => base.contains('누릅니다')
      ? base.replaceAll('누릅니다', '누르도록 기기에 전달했습니다')
      : '기기에 동작을 전달했습니다.';

  /// "1분 조리를 시작합니다." → "1분 조리를 시작하도록 기기에 전달했습니다."
  static String _toSentMessage(String base) {
    if (base.contains('시작합니다')) {
      return base.replaceAll('시작합니다', '시작하도록 기기에 전달했습니다');
    }
    if (base.contains('시작할게요')) {
      return base.replaceAll('시작할게요', '시작하도록 기기에 전달했습니다');
    }
    return '기기에 동작을 전달했습니다.';
  }

  /// 하드웨어가 실제로 움직이는 구간(로그 기준 버튼당 약 1.9초)을 화면과 음성으로
  /// 함께 알린다. 안내가 없으면 화면을 못 보는 사용자는 진행 여부를 알 수 없다.
  Future<void> _beginPress(String label) async {
    _pressDoneTimer?.cancel();
    if (!mounted) return;
    _stopController.reset(); // 이전 실행의 정지 결과를 새 실행 화면에 남기지 않는다.
    _stopRequestedThisRun = false;
    _cancelPendingRelisten(); // 실행 중에는 예약된 다시 듣기가 마이크를 열지 않는다.
    setState(() {
      _isExecuting = true;
      _executingLabel = label;
      _pressDoneLabel = '';
      _statusMessage = label;
    });
    // 아직 연결 전이면 "누르는 중"을 먼저 말하지 않는다. 연결에 실패하면 누르지도 않았는데
    // "누르는 중입니다" 뒤에 "연결하지 못했습니다"가 나와 혼란스러웠다(실기). 연결된 뒤에 말한다.
    if (!BleService.instance.isConnected) {
      _deferredPressLabel = label;
      return;
    }
    await _announcePressing(label);
  }

  String? _deferredPressLabel;

  Future<void> _announcePressing(String label) async {
    _deferredPressLabel = null;
    await _speak(label, interrupt: true, priority: TtsPriority.result);
    // 누르는 동안에는 마이크가 닫혀 "멈춰"를 듣지 못한다. 멈추는 방법을 처음 한 번 알린다.
    if (!_stopHintSpoken) {
      _stopHintSpoken = true;
      await _speak(
        '누르는 동안 멈추려면 화면의 정지나 오른쪽 위 비상 정지를 누르세요.',
        priority: TtsPriority.result,
      );
    }
  }

  bool _stopHintSpoken = false;

  /// 누르기 결과를 완료 화면으로 보여준 뒤 잠시 후 원래 화면으로 돌아온다.
  /// 결과 보고이므로 스크린리더 활성 시에도 들리도록 result 우선순위를 명시한다.
  Future<void> _finishPress(String doneLabel) async {
    if (!mounted) return;
    setState(() {
      _isExecuting = false;
      _pressDoneLabel = doneLabel;
      _statusMessage = doneLabel;
    });
    await _speak(doneLabel, interrupt: true, priority: TtsPriority.result);
    _pressDoneTimer?.cancel();
    _pressDoneTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _pressDoneLabel = '');
    });
  }

  /// 진행 화면만 걷어낸다. 전송 실패 시(실패 안내는 _sendBleSequence가 한다)와,
  /// 완료 화면 대신 타이머 화면으로 곧바로 넘어갈 때 쓴다.
  void _clearPress() {
    if (mounted) setState(() => _isExecuting = false);
  }

  /// 시퀀스가 전송되지 않은 뒤 공통 처리. 비상 정지로 끊긴 경우에는 실패 효과음을
  /// 내지 않는다 — 정지 결과 안내(효과음·TTS·liveRegion)가 이미 나갔고, 늦게 돌아온
  /// 실행 결과가 그것을 덮으면 안 된다. 타이머 화면 이동은 전송 성공 분기에만 있다.
  void _afterSequenceNotSent() {
    if (_lastSequenceStopped) {
      // 정지가 확인됐으면 정지 경로가 완료 화면으로 옮긴다. 미확인·실패·요청 중이면
      // 진행 뷰를 "정지 확인 필요" 상태로 유지해 재시도 버튼이 사라지지 않게 한다.
      if (_awaitingStopResolution) {
        if (mounted) setState(() => _executingLabel = '정지 확인이 필요합니다');
      } else {
        _clearPress();
      }
      return;
    }
    _clearPress();
    FeedbackService.instance.playFailure();
  }

  /// 버튼을 연달아 누르는 구간의 안내 문구.
  /// 전송에 버튼당 약 1.9초가 걸려(로그 기준) 4개면 8초에 가까운데, 그동안
  /// 아무 안내가 없으면 화면을 못 보는 사용자는 멈춘 것과 구분할 수 없다.
  static String _pressingLabelForSequence(List<dynamic> commands) =>
      commands.length > 1
      ? '버튼 ${commands.length}개를 누르는 중입니다.'
      : '버튼을 누르는 중입니다.';

  /// 안내·질문 발화가 끝난 뒤 자동으로 청취를 재개한다.
  ///
  /// 질문만 하고 마이크가 꺼져 있으면 전맹 사용자는 마이크 버튼을 다시 찾아
  /// 두 번 눌러야 한다. 확인·되묻기 경로는 발화 뒤 반드시 이 메서드를 부른다.
  /// TTS 큐가 빈 뒤에 마이크를 열어, 질문 소리가 STT에 섞이거나 질문을 듣는
  /// 중에 침묵 타이머가 돌지 않게 한다.
  /// 낭독기가 [text]를 다 읽을 만한 시간. 낭독기를 쓰지 않으면 짧게 둔다.
  static Duration _screenReaderAllowance(String text) {
    if (!AccessibilitySettings.isScreenReaderActive) {
      return const Duration(milliseconds: 300);
    }
    final ms = (text.length * 110).clamp(1500, 7000);
    return Duration(milliseconds: ms);
  }

  /// 예약해 둔 "다시 듣기"의 세대. 실행·취소·버튼 답·정지가 오면 올려서, 기다리던
  /// 예약이 뒤늦게 마이크를 열지 못하게 한다. 예전에는 '실행'을 누른 뒤에도 예약이
  /// 살아 있어 실행 중이나 취소 뒤에 다시 듣기 시작했다(외부 평가).
  int _relistenGen = 0;

  void _cancelPendingRelisten() => _relistenGen++;

  void _restartListeningAfterPrompt() {
    if (!_speechEnabled || !mounted) return;
    final gen = ++_relistenGen;
    Future<void>(() async {
      await _tts.waitUntilIdle();
      // 낭독기가 상태 문구(liveRegion)를 읽는 동안에는 열지 않는다. 앱 음성이 끝난 것만
      // 기다리면 낭독 도중 마이크가 열려 낭독이 끊기고 낭독 소리가 녹음된다(실기).
      await Future<void>.delayed(_screenReaderAllowance(_statusMessage));
      if (!mounted || gen != _relistenGen) return;
      if (_isRecording || _isProcessing || _isExecuting) return;
      _toggleRecording();
    });
  }

  Future<void> _sendTextToGemini(String text) async {
    final requestId = ++_analysisRequestId;
    AppLogger.info('voice.send_to_gemini.start', {
      'requestId': requestId,
      'text': text,
    });

    // 어떤 흐름으로 보낼지는 VoiceIntentRouter가 단독으로 결정한다.
    // 판정 "순서" 자체가 안전 계약이라(비상 정지 최우선, 상태·재생은 확인
    // 맥락 보존 등) 화면 밖에서 검증할 수 있어야 한다.
    // → test/services/voice_intent_router_test.dart
    final decision = VoiceIntentRouter.route(
      text: text,
      hasPendingCommand: _pendingCommandData != null,
      pendingLowConfidenceText: _pendingLowConfidenceText,
      confidence: _lastConfidence,
    );

    // 대기 상태 정리는 분기 실행 전에 한 번에 반영한다. pendingAccepted는
    // 비우기 전의 명령이 필요하므로 미리 잡아 둔다.
    final pendingCommand = _pendingCommandData;
    if (decision.clearPendingCommand) _pendingCommandData = null;
    if (decision.clearPendingLowConfidence) {
      _pendingLowConfidenceText = null;
      _lowConfidenceQuestion = null;
    }

    switch (decision.kind) {
      case VoiceIntentKind.emptyText:
        AppLogger.warn('voice.send_to_gemini.empty_text');
        setState(() {
          _statusMessage = '명령이 없습니다.';
          _isProcessing = false;
        });
        return;

      case VoiceIntentKind.emergencyStop:
        AppLogger.info('voice.emergency_intercept', {'requestId': requestId});
        setState(() {
          _statusMessage = '중단';
          _isProcessing = false;
        });
        await _handleEmergencyStop();
        return;

      case VoiceIntentKind.help:
        AppLogger.info('voice.help_intercept', {'requestId': requestId});
        setState(() {
          // liveRegion에도 TTS와 같은 도움말 전문을 싣는다.
          _statusMessage = HelpIntent.buildResponse();
          _isProcessing = false;
        });
        await _speak(HelpIntent.buildResponse(), interrupt: true);
        return;

      case VoiceIntentKind.status:
        AppLogger.info('voice.status_intercept', {'requestId': requestId});
        final response = StatusIntent.buildResponse();
        setState(() {
          _statusMessage = response;
          _isProcessing = false;
        });
        await _speak(response, interrupt: true, priority: TtsPriority.result);
        // 확인 질문에 답하던 중이었다면 다시 들을 수 있게 마이크를 연다.
        if (_pendingCommandData != null || _pendingLowConfidenceText != null) {
          _restartListeningAfterPrompt();
        }
        return;

      case VoiceIntentKind.replayLastSpeech:
        AppLogger.info('voice.replay_intercept', {'requestId': requestId});
        setState(() => _isProcessing = false);
        // 답을 기다리는 중이면 지금 질문을 다시 들려주고 계속 듣는다. 낭독기를 써도
        // 들리게 result로 낸다(예전엔 navigation이라 낭독기 사용 중 무음이었다).
        final question = _lowConfidenceQuestion ?? _confirmQuestion;
        if (_awaitingConfirm && question != null) {
          await _speak(question, interrupt: true, priority: TtsPriority.result);
          _restartListeningAfterPrompt();
          return;
        }
        await _tts.replayLast();
        return;

      case VoiceIntentKind.repeatLastCommand:
        AppLogger.info('voice.repeat_intercept', {'requestId': requestId});
        final last = await LastCommandService.instance.load();
        if (last == null) {
          const msg = '다시 실행할 최근 명령이 없어요. 새 명령을 말씀해 주세요.';
          setState(() {
            _statusMessage = msg;
            _isProcessing = false;
          });
          await _speak(msg, interrupt: true, priority: TtsPriority.result);
          return;
        }

        // 마지막 명령의 기기가 아직 등록되어 있는지 확인하고 활성화한다.
        final devices = await HomeDeviceStore.loadDevices();
        final match = devices.where((d) => d['id'] == last.deviceId).toList();
        if (match.isEmpty) {
          final msg = '마지막 명령의 기기 ${last.deviceName}가 더 이상 등록되어 있지 않아요.';
          setState(() {
            _statusMessage = msg;
            _isProcessing = false;
          });
          await _speak(msg, interrupt: true, priority: TtsPriority.result);
          return;
        }
        final device = match.first;
        await ActiveDeviceService.instance.setActiveDevice(
          deviceId: last.deviceId,
          deviceName: last.deviceName,
          bleId: device['bleId'] as String?,
          bleName: device['bleName'] as String?,
          deviceType: device['deviceType'] as String?,
        );

        // 물리 동작이므로 바로 실행하지 않고 기존 예/아니오 확인 흐름을 탄다.
        _pendingCommandData = Map<String, dynamic>.from(last.data);
        final question =
            '마지막 명령은 ${last.deviceName}, ${last.description} 이에요. '
            '다시 실행할까요? "네" 또는 "아니요"로 답해 주세요.';
        setState(() {
          // 다른 실행 확인과 같이 질문을 계속 보여 주고 '실행'·'취소' 버튼을 띄운다.
          // 예전에는 이 확인만 버튼이 없어 말로만 답할 수 있었다(외부 평가).
          _confirmQuestion = question;
          _statusMessage = question;
          _isProcessing = false;
        });
        await _speak(question, interrupt: true, priority: TtsPriority.result);
        _restartListeningAfterPrompt();
        return;

      case VoiceIntentKind.lowConfidenceAccepted:
        AppLogger.info('voice.low_confidence.confirmed', {
          'requestId': requestId,
        });
        // 사용자가 직접 확인했으므로 재확인 루프에 빠지지 않게 신뢰도를
        // 신뢰 가능한 값으로 리셋한 뒤 원문을 다시 처리한다.
        _lastConfidence = 1.0;
        await _sendTextToGemini(decision.payload!);
        return;

      case VoiceIntentKind.lowConfidenceRejected:
        AppLogger.info('voice.low_confidence.rejected', {
          'requestId': requestId,
        });
        setState(() {
          // liveRegion에는 축약어가 아니라 다음 행동이 담긴 전체 문장을 싣는다.
          _statusMessage = '알겠습니다. 다시 말씀해 주세요.';
          _isProcessing = false;
        });
        await _speak('알겠습니다. 다시 말씀해 주세요.');
        // "다시 말씀해 주세요"라고 요청했으니 마이크를 자동으로 다시 연다.
        _restartListeningAfterPrompt();
        return;

      case VoiceIntentKind.confirmLowConfidence:
        AppLogger.info('voice.low_confidence_confirm', {
          'requestId': requestId,
          'confidence': _lastConfidence,
        });
        _pendingLowConfidenceText = decision.payload;
        final confirmQuestion =
            '"$text"라고 들었어요. 맞으면 "네", 아니면 "아니요"라고 말씀해 주세요.';
        setState(() {
          // 확인 질문 전문을 liveRegion에 실어 스크린리더 사용자도 질문 내용을
          // 들을 수 있게 한다('다시 확인 중'만으로는 무엇을 확인하는지 알 수 없다).
          _statusMessage = confirmQuestion;
          _lowConfidenceQuestion = confirmQuestion;
          _isProcessing = false;
        });
        // 낭독기를 쓰면 상태 문구를 낭독기가 읽으므로 앱 음성은 내지 않는다(겹침 방지).
        if (!AccessibilitySettings.isScreenReaderActive) {
          await _speak(confirmQuestion, interrupt: true);
        }
        // 질문했으니 답을 들을 수 있게 마이크를 자동으로 다시 연다.
        _restartListeningAfterPrompt();
        return;

      case VoiceIntentKind.pendingAccepted:
        AppLogger.info('voice.response.affirmative', {'requestId': requestId});
        await _handleCommand(
          pendingCommand!,
          recognizedText: text,
          forceExecution: true,
        );
        return;

      case VoiceIntentKind.pendingRejected:
        AppLogger.info('voice.response.negative', {'requestId': requestId});
        setState(() {
          _statusMessage = '알겠습니다. 취소할게요.';
          _isProcessing = false;
          _confirmQuestion = null;
        });
        await _speak('알겠습니다. 취소할게요.');
        return;

      case VoiceIntentKind.parseAsNewCommand:
        // 아래 기기 해석 → 간단 규칙 → AI 백엔드 경로로 이어진다.
        break;
    }


    final registeredDevices = await _loadRegisteredDevices();
    final resolution = VoiceDeviceResolver.resolve(
      text: text,
      devices: registeredDevices,
      preferredDeviceId: widget.deviceId ?? _resolvedDeviceId,
      preferredDeviceName: widget.deviceName ?? _resolvedDeviceName,
    );

    if (resolution.device != null) {
      await _activateVoiceDevice(resolution.device!);
    }

    // 되묻는 건 "어느 기기인지" 모호할 때뿐이다.
    // needsAction(기기는 특정됐고 동작 키워드만 못 찾은 경우)은 여기서 막지 않고
    // 아래 간단 규칙 → AI 백엔드까지 흘려보낸다. VoiceDeviceResolver의 키워드
    // 목록은 20개 남짓이라 "햇반 돌려줘" 같은 목록 밖 표현을 잡지 못하는데,
    // 그걸 게이트로 쓰면 정작 그런 표현을 해석하라고 둔 백엔드에 도달조차 못 한다.
    if (resolution.needsClarification) {
      _followUpAttempts++;
      AppLogger.info('voice.device_resolution.follow_up', {
        'requestId': requestId,
        'needsClarification': true,
        'attempt': _followUpAttempts,
      });
      // 같은 답이 반복되면 자동 재청취를 멈춘다. 끝없이 되묻으면 화면을 못 보는
      // 사용자에게는 빠져나갈 방법이 없는 상태가 된다.
      final giveUp = _followUpAttempts >= _kMaxFollowUpAttempts;
      final prompt = giveUp
          ? '${resolution.message} 잘 안 되면 마이크 버튼을 누르고 기기 이름부터 말씀해 주세요.'
          : resolution.message;
      setState(() {
        _statusMessage = prompt;
        _isProcessing = false;
      });
      await _speak(prompt);
      if (!giveUp) _restartListeningAfterPrompt();
      return;
    }
    _followUpAttempts = 0;

    final commandText = resolution.commandText.isNotEmpty
        ? resolution.commandText
        : text;
    final ruleResult = ApplianceCommandRouter.checkSimpleRules(
      commandText,
      deviceName: ActiveDeviceService.instance.getActiveDeviceName(),
      deviceType: ActiveDeviceService.instance.getActiveDeviceType(),
    );
    if (ruleResult != null) {
      if (requestId != _analysisRequestId) return;
      AppLogger.info('voice.parse.simple_rule_hit', {'requestId': requestId});
      await _handleCommand(ruleResult, recognizedText: text);
      return;
    }

    try {
      final commandData = await AiBackendService.instance.parseVoiceCommand(
        commandText,
      );
      if (requestId != _analysisRequestId) return;
      AppLogger.info('voice.parse.backend_ok', {
        'requestId': requestId,
        'action': commandData['action'],
      });
      await _handleCommand(commandData, recognizedText: text);
    } catch (e) {
      AppLogger.error('voice.parse.error', {
        'requestId': requestId,
        'error': e.toString(),
      });
      if (requestId != _analysisRequestId) return;
      // 여기로 오는 것은 대부분 서버에 닿지 못한 경우다(연결·시간 초과·주소 설정).
      // 예전에는 모두 "명령을 이해하지 못했습니다"라고 해서, 사용자가 같은 말을
      // 계속 되풀이했다(실기·외부 평가). 응답 형식이 틀린 경우만 "이해하지 못했다"고 한다.
      final String failMsg;
      if (e is FormatException) {
        _consecutiveFailures++;
        failMsg = _consecutiveFailures >= 2
            ? '명령을 이해하지 못했습니다. 도움말을 들으시려면 "도움말"이라고 말씀해 주세요.'
            : '명령을 이해하지 못했습니다. 기기 이름과 동작을 함께 말해 주세요.';
      } else {
        failMsg = '음성 해석 서버에 연결하지 못했습니다. "30초 돌려줘"처럼 간단한 시간 명령은 '
            '서버 없이도 됩니다. 계속 안 되면 보호자에게 알려 주세요.';
      }
      setState(() {
        _statusMessage = failMsg;
        _isProcessing = false;
      });
      // 낭독기를 쓰면 상태 문구(liveRegion)를 낭독기가 읽으므로 앱 음성은 내지 않는다(겹침 방지).
      if (!AccessibilitySettings.isScreenReaderActive) _speak(failMsg);
    }
  }

  void _cancelAnalysis() {
    _analysisRequestId++;
    _pendingCommandData = null;
    setState(() {
      _isProcessing = false;
      _statusMessage = '취소되었습니다.';
    });
    _speak('취소되었습니다.');
  }

  /// 어떤 흐름에서도 공용으로 쓰는 정직한 비상 정지 처리.
  /// 실제 하드웨어에 정지 명령을 보내고, 확인 결과에 따라 안내를 분기한다.
  Future<void> _handleEmergencyStop() async {
    if (_isExecuting) _stopRequestedThisRun = true;
    FeedbackService.instance.vibrateError();
    // 대상 결정 → 재연결 → STOP 전송 → ACK 해석은 EmergencyStopService가 맡는다.
    final outcome = await EmergencyStopService.instance.stopActiveDevice();
    await _announceStopOutcome(outcome);
  }

  /// 실행 중 화면의 단일 탭 정지. 확인창·두 번째 탭 없이 바로 우선 정지 경로를
  /// 부른다. 진행 중 중복 탭은 컨트롤러가 무시하고, 실패·미확인 뒤에는 재시도할 수 있다.
  Future<void> _onSingleTapStop() async {
    if (_stopController.inFlight) return;
    // 정지 경로는 연결을 기다린 뒤에야 명령을 보낼 수 있다. 그 전에 시퀀스가
    // 시작되지 않도록 탭한 순간 기록한다.
    _stopRequestedThisRun = true;
    FeedbackService.instance.vibrateError();
    AppLogger.warn('voice.single_tap_stop.requested', {
      'executing': _isExecuting,
      'attempt': _stopController.requestCount + 1,
    });
    final outcome = await _stopController.requestStop();
    if (outcome == null) return; // 이미 진행 중이던 요청이 있었다.
    await _announceStopOutcome(outcome);
    // 미확인·실패인데 시퀀스가 이미 끝났으면 재시도 UI를 유지한 채 문구만 갱신.
    if (mounted && !outcome.acknowledged && _awaitingStopResolution) {
      setState(() => _executingLabel = '정지 확인이 필요합니다');
    }
  }

  /// 정지 결과 안내. ACK 확인 / 전송만 됨(미확인) / 전송 실패를 그대로 말하며,
  /// acknowledged일 때만 완료 화면으로 간다(거짓 완료 금지).
  Future<void> _announceStopOutcome(EmergencyStopOutcome outcome) async {
    if (outcome.acknowledged) {
      FeedbackService.instance.playSuccess();
    } else {
      FeedbackService.instance.playFailure();
    }
    // 정지 결과는 안전 정보: emergency 우선순위로 스크린리더 활성 시에도 반드시
    // 들려주고, liveRegion(_statusMessage) 채널로도 함께 전달한다.
    if (mounted) setState(() => _statusMessage = outcome.message);
    await _speak(
      outcome.message,
      interrupt: true,
      priority: TtsPriority.emergency,
    );
    if (!mounted) return;
    if (outcome.acknowledged) {
      _clearPress();
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()),
      );
    }
  }

  /// 버튼 시퀀스를 기기에 전송한다. 전송 성공 시 true, 실패 시(연결/매핑 실패 등)
  /// 사용자에게 원인을 안내하고 false를 반환한다. 호출부는 이 값으로 성공 피드백을 건다.
  Future<bool> _sendBleSequence(List<dynamic> commands) async {
    _lastSequenceStopped = false;
    _sequenceRunning = true;
    try {
      return await _sendBleSequenceInner(commands);
    } finally {
      _sequenceRunning = false;
    }
  }

  /// 이번 실행에 정지가 요청됐으면 전송을 시작하지 않는다(안내는 정지 경로가 맡는다).
  /// 호출 직후 await 없이 전송 함수를 불러야 이 확인과 실행 토큰 캡처 사이에
  /// 틈이 생기지 않는다.
  bool _stopRequestedBeforeSend() {
    if (!_stopRequestedThisRun) return false;
    _lastSequenceStopped = true;
    AppLogger.info('voice.sequence.aborted_before_send');
    return true;
  }

  /// 실행 토큰이 바뀌어 시퀀스가 도중에 끊겼을 때. 사용자가 정지했으면 정지 결과
  /// 안내에 맡기고, 아니면(= BLE 링크 끊김) 끝까지 전달하지 못했다고 알린다.
  bool _onSequenceInterrupted() {
    if (_stopRequestedThisRun) {
      // 정지 결과(ACK 기준) 안내가 liveRegion·TTS를 맡는다. 늦게 돌아온 이
      // 결과로 상태 문구를 덮거나 다시 말하지 않는다.
      _lastSequenceStopped = true;
      return false;
    }
    // "기기 상태를 확인해 주세요"는 볼 수 없는 사용자가 할 수 없다(외부 평가).
    // 무엇을 할 수 있는지 알린다.
    const msg = '기기 연결이 끊겨 동작을 끝까지 전달하지 못했습니다. 일부 버튼은 이미 눌렸을 수 있습니다. '
        '다시 연결되면 "취소해 줘"로 가전을 끌 수 있습니다.';
    AppLogger.warn('voice.sequence.interrupted_without_stop');
    if (mounted) setState(() => _statusMessage = msg);
    _speak(msg);
    return false;
  }

  Future<bool> _sendBleSequenceInner(List<dynamic> commands) async {
    if (_stopRequestedBeforeSend()) return false;

    // 이미 연결된 기기가 이 가전에 등록된 Touch Bridge면 그대로 쓴다. 다른 장치에
    // 붙어 있으면 그 장치로 보내지 않고 이 가전의 장치로 다시 연결한다. 예전에는
    // 연결된 장치를 무조건 써서, 가전을 골라도 다른 장치가 움직일 수 있었다(외부 평가).
    String deviceId = BleService.instance.connectedDeviceId;
    final targetBleId = ActiveDeviceService.instance.getActiveBleId();
    final connectedToOther = deviceId.isNotEmpty &&
        targetBleId != null &&
        targetBleId.isNotEmpty &&
        deviceId != targetBleId;

    if (deviceId.isEmpty || connectedToOther) {
      // 연결된 게 없을 때만 활성 가전을 자동으로 고른다.
      if (deviceId.isEmpty) {
        await ActiveDeviceService.instance.autoPickFirstDevice();
      }
      if (_stopRequestedBeforeSend()) return false;
      final activeBleId = ActiveDeviceService.instance.getActiveBleId();
      if (activeBleId == null) {
        // 실패 원인을 _statusMessage에도 반영해 liveRegion(스크린리더 채널)으로
        // 전달한다 — TTS만으로는 스크린리더 활성 시 억제되어 무음이 된다.
        if (mounted) {
          setState(() => _statusMessage = '먼저 보호자에게 기기 연결을 요청해 주세요.');
        }
        _speak('먼저 보호자에게 기기 연결을 요청해 주세요.');
        return false;
      }

      if (mounted) setState(() => _statusMessage = '기기에 연결 중입니다...');
      _speak('기기에 연결 중입니다...');
      final connected = await BleService.instance.ensureConnected(activeBleId);
      if (_stopRequestedBeforeSend()) return false;
      if (!connected) {
        if (mounted) {
          setState(() => _statusMessage = 'Touch Bridge에 연결하지 못했습니다. 전원이 켜져 있는지 확인하거나 보호자에게 알려 주세요.');
        }
        _deferredPressLabel = null;
        _speak('Touch Bridge에 연결하지 못했습니다. 전원이 켜져 있는지 확인하거나 보호자에게 알려 주세요.');
        return false;
      }
      deviceId = BleService.instance.connectedDeviceId;
      final pending = _deferredPressLabel;
      if (pending != null) {
        await _announcePressing(pending);
        if (_stopRequestedBeforeSend()) return false;
      }
    }

    // 활성 기기 프로필 로드. 저장된 매핑이 있으면 목데이터보다 우선 사용한다.
    final activeApplianceId =
        ActiveDeviceService.instance.getActiveDeviceId() ?? '';
    final profile = await DeviceMappingService.instance.load(activeApplianceId);
    // 여기부터 전송 함수 호출까지 await가 없어야 한다(위 확인과 토큰 캡처 사이 틈 방지).
    if (_stopRequestedBeforeSend()) return false;
    final useProfileMapping =
        activeApplianceId.isNotEmpty &&
        (profile.buttonMap.isNotEmpty ||
            profile.rows != 3 ||
            profile.cols != 3 ||
            profile.originX != 0 ||
            profile.originY != 0 ||
            profile.pitchX != 1 ||
            profile.pitchY != 1);

    if (useProfileMapping) {
      final result = await MappingExecutionService.instance.pressSequence(
        deviceId: deviceId,
        profile: profile,
        buttonIds: commands.cast<String>(),
      );
      if (!result.ok) {
        if (result.stoppedByEmergency) return _onSequenceInterrupted();
        if (mounted) setState(() => _statusMessage = result.userMessage);
        _speak(result.userMessage);
        return false;
      }
      return true;
    }

    // 저장 매핑이 없는 실제 기기에 데모 좌표로 누르면 엉뚱한 버튼이 눌린다.
    // 데모 빌드(또는 테스트)에서만 목데이터로 넘어가고, 그 밖에는 거절한다.
    if (!allowMockMappingFallback) {
      const msg = '이 기기의 버튼 위치가 아직 설정되지 않았습니다. 보호자에게 위치 맞추기를 요청해 주세요.';
      if (mounted) setState(() => _statusMessage = msg);
      _speak(msg);
      return false;
    }
    // 저장 매핑이 없을 때만 검증된 데모 목데이터 물리 좌표를 fallback으로 쓴다.
    // 실제 G-code 조립·전송은 MappingExecutionService.pressPhysical이 한다.
    // 버튼 사이 대기까지 하나의 실행 토큰으로 묶는다 — 화면에서 pressPhysical을
    // 직접 반복하면 대기 중 비상 정지가 다음 버튼을 막지 못한다.
    {
      final result = await MappingExecutionService.instance
          .pressPhysicalSequence(commands.cast<String>());
      if (!result.ok) {
        if (result.stoppedByEmergency) return _onSequenceInterrupted();
        if (mounted) setState(() => _statusMessage = result.userMessage);
        _speak(result.userMessage);
        return false;
      }
    }
    return true;
  }

  /// 전송에 성공한 물리 명령을 "아까 그거 다시" 재실행용으로 기록한다.
  void _recordLastCommand(Map<String, dynamic> data, String description) {
    final deviceId = ActiveDeviceService.instance.getActiveDeviceId() ?? '';
    if (deviceId.isEmpty) return;
    unawaited(
      LastCommandService.instance.record(
        data: data,
        deviceId: deviceId,
        deviceName: ActiveDeviceService.instance.getActiveDeviceName() ?? '기기',
        description: description,
      ),
    );
  }

  Future<void> _handleCommand(
    Map<String, dynamic> data, {
    required String recognizedText,
    bool forceExecution = false,
  }) async {
    final action = data['action'] as String? ?? 'NONE';
    AppLogger.info('voice.handle_command', {
      'action': action,
      'force': forceExecution,
    });
    final message = (data['message'] as String? ?? '').trim();
    final commands = (data['commands'] as List<dynamic>?) ?? [];
    final inferredSeconds = (data['inferred_seconds'] as num?)?.toInt();
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.5;
    final needsConfirmation = (data['needs_confirmation'] as bool?) ?? false;
    final confirmationMessage = (data['confirmation_message'] as String? ?? '')
        .trim();

    setState(() {
      _isProcessing = false;
      _recognizedText = recognizedText;
      _confirmQuestion = null;
    });

    // 가전 버튼을 누르는 명령은 모두 실행 전에 확인한다(재설계 결정 ①).
    // "30초 돌려줘"처럼 명확한 명령도 예외가 아니다. 화면의 '실행'·'취소'나
    // 음성 '네'·'아니요'로 답한다. 정지는 확인하지 않는다.
    // 백엔드가 이미 확인 질문을 만든 경우(needs_confirmation)와 다시 말해 달라고
    // 할 경우(저신뢰)는 아래 각 분기가 맡는다.
    const physicalActions = {
      'IMMEDIATE_PRESS',
      'MICROWAVE_CONTROL',
      'WASHER_CONTROL',
      'AC_CONTROL',
    };
    final asksAgain = action == 'MICROWAVE_CONTROL' &&
        (needsConfirmation || confidence < 0.55);
    if (!forceExecution &&
        physicalActions.contains(action) &&
        commands.isNotEmpty &&
        !asksAgain) {
      _pendingCommandData = Map<String, dynamic>.from(data);
      final what = message.isNotEmpty ? message : '버튼 ${commands.length}개를 누릅니다.';
      // 버튼을 찾지 않고 말로 답하면 된다는 것을 질문에 함께 알린다.
      final question = '$what 실행할까요? "네" 또는 "아니요"로 답해 주세요.';
      setState(() {
        _confirmQuestion = question;
        _statusMessage = question;
      });
      // 낭독기를 쓰면 질문은 상태 문구(liveRegion)로 낭독기가 읽는다. 앱 음성까지 내면
      // 두 목소리가 겹쳐 언제 답해야 할지 알 수 없다(외부 평가). 쓰지 않으면 앱이 말한다.
      if (!AccessibilitySettings.isScreenReaderActive) {
        await _speak(question, interrupt: true);
      }
      _restartListeningAfterPrompt();
      return;
    }

    switch (action) {
      case 'IMMEDIATE_PRESS':
        final pressBase = message.isNotEmpty ? message : '버튼을 누릅니다.';
        // 전송 "전"에 누르는 중임을 알린다.
        await _beginPress(_toPressingMessage(pressBase));
        final immediateSent = await _sendBleSequence(commands);
        if (!immediateSent) {
          _afterSequenceNotSent(); // 실패 안내는 _sendBleSequence가, 정지 안내는 정지 경로가 함
          return;
        }
        _consecutiveFailures = 0;
        // "성공"이 아니라 "전송됨"이다: BLE write 성공일 뿐 GRBL 확인이 아니다.
        FeedbackService.instance.signalSent();
        _recordLastCommand(data, pressBase);
        // _finishPress가 _statusMessage도 갱신한다 → liveRegion이 스크린리더
        // 채널로 결과를 전달한다. (interrupt:true만으로는 스크린리더 활성 시
        // TTS가 억제되므로 result 우선순위와 liveRegion이 함께 필요하다.)
        await _finishPress(_toDoneMessage(pressBase));
        return;

      case 'EMERGENCY_STOP':
        await _handleEmergencyStop();
        return;

      case 'MICROWAVE_CONTROL':
        if (needsConfirmation && !forceExecution) {
          if (commands.isNotEmpty) {
            _pendingCommandData = Map<String, dynamic>.from(data);
          }
          final clarification = message.isNotEmpty
              ? message
              : '명령을 다시 말씀해 주세요.';
          setState(() {
            _statusMessage = clarification;
            // 실행할 명령이 있으면 같은 '실행'·'취소' 버튼으로도 답할 수 있게 한다.
            if (commands.isNotEmpty) _confirmQuestion = clarification;
          });
          await _speak(clarification);
          // 확인 질문/재발화 요청 뒤에는 답을 들을 수 있게 마이크를 자동으로 연다.
          _restartListeningAfterPrompt();
          return;
        }

        if (confidence < 0.55 || commands.isEmpty) {
          final clarification = message.isNotEmpty
              ? message
              : '명령을 다시 말씀해 주세요.';
          setState(() {
            _statusMessage = clarification;
          });
          await _speak(clarification);
          _restartListeningAfterPrompt();
          return;
        }

        final seconds =
            inferredSeconds ??
            MicrowaveCommandService.calculateSeconds(commands);
        // 버튼을 여러 개 연달아 누르는 경로라 실행 구간이 가장 길다(로그 기준
        // 4개에 약 7.7초). 진행 화면 없이는 그동안 멈춘 것처럼 보인다.
        await _beginPress(_pressingLabelForSequence(commands));
        final microwaveSent = await _sendBleSequence(commands);
        if (!microwaveSent) {
          _afterSequenceNotSent(); // 실패 안내는 _sendBleSequence가, 정지 안내는 정지 경로가 함
          return;
        }
        _consecutiveFailures = 0;
        // "성공"이 아니라 "전송됨"이다: BLE write 성공일 뿐 GRBL 확인이 아니다.
        FeedbackService.instance.signalSent();
        final spokenMessage = forceExecution && confirmationMessage.isNotEmpty
            ? confirmationMessage
            : message;
        final finalMsg = _toSentMessage(
          spokenMessage.isNotEmpty ? spokenMessage : '시작할게요.',
        );
        _recordLastCommand(data, finalMsg);

        if (seconds > 0) {
          // 곧 타이머 화면이 완료 상태를 대신하므로 진행 화면만 걷어낸다.
          _clearPress();
          if (!mounted) return;
          setState(() => _statusMessage = finalMsg);
          await _speak(finalMsg, interrupt: true);
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EmergencyStopScreen(
                initialSeconds: seconds,
                // 실제 대상 기기 이름. 세탁기 등에서도 "전자레인지 작동 중"이라고 하지 않게 한다.
                deviceName: widget.deviceName ??
                    _resolvedDeviceName ??
                    ActiveDeviceService.instance.getActiveDeviceName() ??
                    '가전',
              ),
            ),
          );
          return;
        }
        // 시간이 없는 명령(취소 등)은 넘어갈 화면이 없으니 완료 화면으로 알린다.
        await _finishPress(finalMsg);
        return;

      case 'WASHER_CONTROL':
        if (commands.isEmpty) {
          final clarification = message.isNotEmpty ? message : '명령을 다시 말씀해 주세요.';
          setState(() => _statusMessage = clarification);
          await _speak(clarification);
          _restartListeningAfterPrompt();
          return;
        }
        await _beginPress(_pressingLabelForSequence(commands));
        final washerSent = await _sendBleSequence(commands);
        if (!washerSent) {
          _afterSequenceNotSent(); // 실패 안내는 _sendBleSequence가, 정지 안내는 정지 경로가 함
          return;
        }
        _consecutiveFailures = 0;
        FeedbackService.instance.signalSent();
        final washerMsg = message.isNotEmpty
            ? message
            : WashingMachineCommandService.buildCommandsLabel(commands);
        _recordLastCommand(data, washerMsg);
        await _finishPress(washerMsg);
        return;

      case 'AC_CONTROL':
        if (commands.isEmpty) {
          final clarification = message.isNotEmpty ? message : '명령을 다시 말씀해 주세요.';
          setState(() => _statusMessage = clarification);
          await _speak(clarification);
          _restartListeningAfterPrompt();
          return;
        }
        await _beginPress(_pressingLabelForSequence(commands));
        final acSent = await _sendBleSequence(commands);
        if (!acSent) {
          _afterSequenceNotSent(); // 실패 안내는 _sendBleSequence가, 정지 안내는 정지 경로가 함
          return;
        }
        _consecutiveFailures = 0;
        FeedbackService.instance.signalSent();
        final acMsg = message.isNotEmpty
            ? message
            : AcCommandService.buildCommandsLabel(commands);
        _recordLastCommand(data, acMsg);
        await _finishPress(acMsg);
        return;

      case 'NAVIGATE':
        final target = data['target'] as String? ?? '';
        final Widget? navigateDest;
        final String destName;
        switch (target) {
          // 기기 연결·버튼 위치는 보호자 기능이라 보호자 설정 한곳으로 보낸다.
          case 'connection':
          case 'mapping':
            navigateDest = const GuardianHubScreen();
            destName = '보호자 설정';
          case 'settings':
            navigateDest = const SettingsScreen();
            destName = '설정';
          default:
            navigateDest = null;
            destName = '';
        }
        if (navigateDest == null) return;
        _consecutiveFailures = 0;
        await _speak('$destName 화면으로 이동합니다.', interrupt: true, priority: TtsPriority.navigation);
        if (!mounted) return;
        final navScreen = navigateDest;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => navScreen),
        );
        return;

      default:
        _consecutiveFailures++;
        final fallback = message.isNotEmpty
            ? message
            : (_consecutiveFailures >= 2
                ? '이해하지 못했습니다. 도움말을 들으시려면 "도움말"이라고 말씀해 주세요.'
                : '이해하지 못했습니다. 기기 이름과 동작을 함께 말씀해 주세요.');
        setState(() {
          _statusMessage = fallback;
        });
        await _speak(fallback);
        return;
    }
  }

  /// 누르는 중(진행) / 전달 완료를 같은 레이아웃으로 보여준다. 진행 중에는
  /// 단일 탭 비상 정지 버튼이 항상 보인다 ([PressProgressView]).
  Widget _buildPressStatusView(double rs) {
    final done = _pressDoneLabel.isNotEmpty;
    return PressProgressView(
      label: done ? _pressDoneLabel : _executingLabel,
      done: done,
      stopController: _stopController,
      onStopTap: _onSingleTapStop,
      awaitingStopResolution: _awaitingStopResolution,
      scale: rs,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final screenH = MediaQuery.sizeOf(context).height;
    final waveH = (screenH * 0.12).clamp(48.0, 100.0);
    final bool isIdle = !_isRecording && !_isProcessing;

    // 누르는 중 / 누르기 완료는 화면 전체로 크게 보여준다. 하드웨어가 실제로
    // 움직이는 구간과 끝난 시점을 화면·음성 양쪽에서 분명히 구분하기 위함이다.
    if (_isExecuting || _pressDoneLabel.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        // 오른쪽 위 정지도 남긴다. 첫 실행 안내가 "어느 화면에서든 오른쪽 위"라고 가르치므로
        // 실행 중에 그 버튼이 사라지면 안 된다(외부 평가). 이 화면의 한 번 탭 정지와 같은 절차를 부른다.
        appBar: TopAppBar(title: 'Touch Bridge', onEmergency: _onSingleTapStop),
        body: SafeArea(child: Center(child: _buildPressStatusView(rs))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: 'Touch Bridge'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * rs),
                    child: Column(
                      children: [
                        SizedBox(height: 12 * rs),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: BleStatusBanner(),
                        ),
                        SizedBox(height: 28 * rs),
                        // liveRegion: true — 스크린리더 활성 시 억제되는
                        // navigation 우선순위 TTS 대신 스크린리더 채널로
                        // 상태 변화를 알린다.
                        // 큰 제목은 낭독기가 자동으로 읽지 않는다(liveRegion 아님). 상태는 아래
                        // 상태 문구 하나가 알린다. 예전에는 조용히 다시 여는 짧은 틈에 제목이
                        // '말씀해 주세요.'로 바뀌며 낭독기가 읽었고, 다시 열린 마이크가 그 소리를
                        // 명령으로 받아 서버로 보냈다(실기).
                        Semantics(
                          header: true,
                          child: Text(
                            _isProcessing
                                ? '분석 중...'
                                : ((_isRecording || _quietRestart)
                                    ? '듣고 있습니다'
                                    : '말씀해 주세요.'),
                            style: TextStyle(
                              color: (_isRecording || _isProcessing)
                                  ? AppColors.primary
                                  : Colors.white,
                              fontSize: 34 * rs,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 10)),
                        // liveRegion: true — _statusMessage 변경 시 스크린리더가
                        // 자동으로 읽는다. 성공/실패 결과 메시지를 _statusMessage에
                        // 저장하면 TTS 억제(navigation 우선순위)와 관계없이
                        // 스크린리더 채널로 전달된다.
                        // 마이크가 듣는 동안에는 바뀌어도 낭독기가 읽지 않는다. 듣기 시작에
                        // "듣고 있습니다"를 읽으면 그 소리가 녹음됐다(실기). 시작은 띵 소리로 알린다.
                        Semantics(
                          liveRegion: !(_isRecording ||
                              _quietRestart ||
                              _speechSession.shouldStayQuiet),
                          child: Text(
                            _isRecording ? '듣고 있습니다.' : _statusMessage,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16 * rs,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 40 * rs),
                        VoiceWaveVisualizer(
                          waveHeights: _waveHeights,
                          waveHeight: waveH,
                          isRecording: _isRecording,
                          scale: rs,
                        ),
                        if (_isRecording &&
                            _recognizedText.isNotEmpty &&
                            _recognizedText != '아직 인식된 명령이 없어요.') ...[
                          SizedBox(height: ResponsiveScale.v(context, 16)),
                          Text(
                            '"$_recognizedText"',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15 * rs,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        SizedBox(height: 40 * rs),
                        VoiceActionButtons(
                          isRecording: _isRecording,
                          isIdle: isIdle,
                          micArmed: _micArmed,
                          scale: rs,
                          onMicTap: _handleMicTap,
                          onCancelRecording: () {
                            _speechSession.stop();
                            _recordingTimeoutTimer?.cancel();
                            _stopWaveAnimation();
                            setState(() {
                              _isRecording = false;
                              _isProcessing = false;
                            });
                            _speak('취소되었습니다.');
                          },
                          onCancelAnalysis: _cancelAnalysis,
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 24)),
                        // 실행 확인 중에는 '실행'·'취소'를 보이고 예시 명령은 숨긴다.
                        // 실행 확인에 답한 "네"를 잘못 들었을 수 있어 되물으면 두 질문이 함께
                        // 걸린다. 더 최근인 되묻기를 먼저 보여 준다(외부 평가).
                        if (_pendingLowConfidenceText != null &&
                            _lowConfidenceQuestion != null) ...[
                          _buildConfirmQuestionCard(rs, _lowConfidenceQuestion),
                          SizedBox(height: ResponsiveScale.v(context, 16)),
                          _buildLowConfidenceButtons(rs),
                        ] else if (_pendingCommandData != null &&
                            _confirmQuestion != null) ...[
                          _buildConfirmQuestionCard(rs),
                          SizedBox(height: ResponsiveScale.v(context, 16)),
                          _buildConfirmButtons(rs),
                        ]
                        else if (isIdle)
                          VoiceExampleCommands(
                            scale: rs,
                            onSelected: (cmd) {
                              setState(() {
                                _recognizedText = cmd;
                                _isProcessing = true;
                              });
                              _speak('$cmd 명령을 처리합니다.');
                              _sendTextToGemini(cmd);
                            },
                          ),
                        SizedBox(height: 24 * rs),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
