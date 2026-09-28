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
import '../../services/accessibility_settings.dart';
import '../../theme/app_colors.dart';
import 'widgets/voice_wave_visualizer.dart';
import 'widgets/voice_action_buttons.dart';
import 'widgets/voice_example_commands.dart';
import '../../widgets/ble_status_banner.dart';
import '../connection/device_connect_screen.dart';
import '../mapping/manual_mapping_screen.dart';
import '../settings/settings_screen.dart';

class VoiceListeningScreen extends StatefulWidget {
  const VoiceListeningScreen({
    super.key,
    this.deviceId,
    this.deviceName,
    this.autoStart = false,
  });

  final String? deviceId;
  final String? deviceName;
  final bool autoStart;

  @override
  State<VoiceListeningScreen> createState() => VoiceListeningScreenState();
}

/// 공개 State: 위젯 테스트가 실행 중 화면(단일 탭 정지)까지 도달할 수 있도록
/// [handleCommandForTest] 등 테스트 전용 진입점을 둔다.
class VoiceListeningScreenState extends State<VoiceListeningScreen> {
  final TtsService _tts = TtsService();
  final math.Random _random = math.Random();
  // 공용 STT 세션: 화면별 개별 초기화는 패키지 싱글톤 특성상 콜백이 최초
  // 1회만 등록돼, 다른 화면(비상 정지)의 이벤트를 이 화면이 받거나 그 반대의
  // 오염이 있었다. 이벤트는 스택 최상단 화면에만 전달된다.
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
  final Duration _maxRecordingDuration = const Duration(seconds: 10);

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
  /// 정지 버튼은 실행 토큰(epoch)이 잡히기 **전**부터 보인다 — 안내 음성,
  /// 기기 연결, 매핑 로드가 먼저 돈다. 그 사이에 정지하면 epoch는 올라가지만
  /// 아직 시작 전인 시퀀스가 **올라간 값을 새 기준으로 잡아** 버튼을 전부
  /// 누른다. "기기를 멈췄습니다. 안전합니다." 안내 뒤 조리 타이머까지 진입하는
  /// 것이 재현됐다. 그래서 epoch와 별개로 화면이 직접 기록한다.
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
  Future<void> handleCommandForTest(Map<String, dynamic> data) =>
      _handleCommand(data, recognizedText: 'test');
  Timer? _pressDoneTimer;
  static const _kExamplesSeenKey = 'voice_examples_announced';

  /// 실행 중 화면의 단일 탭 비상 정지. 확인 단계 없이 우선 정지 경로를 부른다.
  /// (리뷰 #3: 실행 구간에는 마이크가 닫혀 음성 "멈춰"가 안 되고, 전역 비상 버튼은
  /// 두 번 탭이 필요했다. 실행 중 음성 "멈춰" 지원은 별도 미해결 항목.)
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
      _statusMessage = 'AI_BACKEND_URL이 설정되지 않았습니다.';
      _speak(_statusMessage);
    } else {
      _initSpeech().then((_) {
        if (widget.autoStart && _speechEnabled && mounted) {
          _toggleRecording();
        }
      });
    }
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _recordingTimeoutTimer?.cancel();
    _silenceTimer?.cancel();
    _actionResetTimer?.cancel();
    _pressDoneTimer?.cancel();
    _stopController.dispose();
    _stopRequestSub?.cancel();
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지워버린다(화면 전환 시 안내가 잘리는 문제).
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
  /// 대신 읽는 것만 호출부에서 navigation을 명시한다. (이전에는 기본값이
  /// navigation이라 43곳 중 35곳의 실패·취소 안내가 스크린리더에서 무음이었다.)
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

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(
      Duration(seconds: AccessibilitySettings.instance.sttSilenceTimeoutSeconds),
      () {
      if (!mounted || !_isRecording) return;

      // 만약 이미 명령이 인식되어 처리 중이라면 침묵 타이머 무시
      if (_lastWords.isNotEmpty) {
        AppLogger.info('voice.silence_timer.trigger_stop', {
          'lastWords': _lastWords,
        });
        _toggleRecording();
        return;
      }

      AppLogger.info('voice.silence_timer.no_input');
      _speechSession.stop();
      _recordingTimeoutTimer?.cancel();
      _stopWaveAnimation();
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _statusMessage = '말씀이 들리지 않았습니다. 다시 말하려면 마이크를 누르세요.';
      });
      _speak('말씀이 들리지 않았습니다. 다시 말하려면 마이크를 누르세요.');
    });
  }

  void _onSttNaturalEnd() {
    // 이미 처리 중이거나 녹음 중이 아니면 무시
    if (!_isRecording || _isProcessing) return;

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
    } else {
      _speak('말씀이 들리지 않았습니다. 다시 말하려면 마이크를 누르세요.');
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
      _speechSession.stop();
      _recordingTimeoutTimer?.cancel();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _statusMessage = '명령을 확인하고 있습니다.';
      });
      _stopWaveAnimation();
      _speak('녹음이 종료되었습니다.', priority: TtsPriority.navigation);
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
      _isStartingRecording = true;
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
              if (_lastWords.isNotEmpty) _resetSilenceTimer();
            }
          },
          listenOptions: SpeechListenOptions(
            localeId: 'ko_KR',
            listenMode: ListenMode.dictation,
            partialResults: true,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (_speechSession.isListening || _isRecording) {
          _startWaveAnimation();
          FeedbackService.instance.playDing(); // "띵" 소리 추가
          FeedbackService.instance.vibrateSuccess(); // 짧은 진동 추가
          _speak('녹음을 시작합니다.', priority: TtsPriority.navigation);

          // 멘트가 끝날 때까지 기다린 후(약 1.5초) 침묵 감지 시작
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && _isRecording) _resetSilenceTimer();
          });

          _recordingTimeoutTimer = Timer(_maxRecordingDuration, () {
            if (_isRecording) {
              _speak('녹음 시간이 초과되었습니다.');
              _toggleRecording();
            }
          });
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

  void _handleMicTap() {
    if (_isProcessing) return;

    if (!_micArmed) {
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

    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: device.id,
      deviceName: device.name,
      bleId: preservedBleId,
      bleName: preservedBleName,
    );
  }

  /// 안내/질문 발화가 끝난 뒤 자동으로 청취를 재개한다.
  ///
  /// "예/아니오로 답하세요"라고 말해놓고 마이크가 꺼져 있으면 전맹 사용자는
  /// 마이크 버튼을 다시 찾아 두 번 눌러야 하는 dead-end에 빠진다. 모든
  /// 확인·되묻기 경로는 발화 후 이 메서드를 호출해야 한다.
  /// TTS 큐가 빌 때까지 기다렸다가 마이크를 열어, 질문 소리가 STT에 섞이거나
  /// 질문을 듣는 중에 침묵 타이머가 도는 문제를 막는다.
  /// "2번 버튼을 누릅니다." → "2번 버튼을 누르는 중입니다."
  static String _toPressingMessage(String base) =>
      base.contains('누릅니다') ? base.replaceAll('누릅니다', '누르는 중입니다') : base;

  /// "2번 버튼을 누릅니다." → "2번 버튼을 누르도록 기기에 전달했습니다."
  ///
  /// BLE write 성공은 기기가 눌렀다는 확인이 아니다(이 경로에는 ACK가 없다).
  /// 이전 문구 "눌렀습니다"는 화면을 볼 수 없는 사용자에게 거짓 완료였다.
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

  /// 하드웨어가 실제로 움직이는 구간을 화면과 음성으로 함께 알린다.
  /// 전송이 끝난 뒤에야 "누릅니다"라고 말하던 때는 이 구간(로그 기준 약 1.9초)
  /// 동안 아무 안내가 없어, 화면을 못 보는 사용자가 진행 여부를 알 수 없었다.
  Future<void> _beginPress(String label) async {
    _pressDoneTimer?.cancel();
    if (!mounted) return;
    _stopController.reset(); // 이전 실행의 정지 결과를 새 실행 화면에 남기지 않는다.
    _stopRequestedThisRun = false;
    setState(() {
      _isExecuting = true;
      _executingLabel = label;
      _pressDoneLabel = '';
      _statusMessage = label;
    });
    await _speak(label, interrupt: true, priority: TtsPriority.result);
  }

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

  void _restartListeningAfterPrompt() {
    if (!_speechEnabled || !mounted) return;
    Future<void>(() async {
      await _tts.waitUntilIdle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted || _isRecording || _isProcessing) return;
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
    if (decision.clearPendingLowConfidence) _pendingLowConfidenceText = null;

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
            '다시 실행할까요? 맞으면 예라고 말씀해 주세요.';
        setState(() {
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
            '"$text"라고 들었어요. 맞으면 "예", 아니면 "아니오"라고 말씀해 주세요.';
        setState(() {
          // 확인 질문 전문을 liveRegion에 실어 스크린리더 사용자도 질문 내용을
          // 들을 수 있게 한다('다시 확인 중'만으로는 무엇을 확인하는지 알 수 없다).
          _statusMessage = confirmQuestion;
          _isProcessing = false;
        });
        await _speak(confirmQuestion, interrupt: true);
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
    // ("돌려"가 "들려"로 오인식되자 같은 질문만 무한 반복된 사고가 있었다.)
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
      _consecutiveFailures++;
      final failMsg = _consecutiveFailures >= 2
          ? '명령을 이해하지 못했습니다. 도움말을 들으시려면 "도움말"이라고 말씀해 주세요.'
          : '명령을 이해하지 못했습니다. 기기 이름과 동작을 함께 말해 주세요.';
      _speak(failMsg);
      setState(() {
        _statusMessage = failMsg;
        _isProcessing = false;
      });
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
    // 대상 결정 → 재연결 → STOP 전송 → ACK 해석은 EmergencyStopService가
    // 단일하게 책임진다(과거 3개 화면 복제 로직 통합).
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
    const msg = '기기 연결이 끊겨 동작을 끝까지 전달하지 못했습니다. 기기 상태를 확인해 주세요.';
    AppLogger.warn('voice.sequence.interrupted_without_stop');
    if (mounted) setState(() => _statusMessage = msg);
    _speak(msg);
    return false;
  }

  Future<bool> _sendBleSequenceInner(List<dynamic> commands) async {
    if (_stopRequestedBeforeSend()) return false;

    // [DEMO PRIORITY] 이미 연결된 기기가 있다면 즉시 사용
    String deviceId = BleService.instance.connectedDeviceId;

    if (deviceId.isEmpty) {
      // 연결된 게 없을 때만 자동 선택 및 재연결 시도
      await ActiveDeviceService.instance.autoPickFirstDevice();
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
          setState(() => _statusMessage = '연결에 실패했습니다. 기기 전원을 확인하세요.');
        }
        _speak('연결에 실패했습니다. 기기 전원을 확인하세요.');
        return false;
      }
      deviceId = BleService.instance.connectedDeviceId;
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

    // 저장 매핑이 없을 때만 검증된 데모 목데이터 물리 좌표를 fallback으로 쓴다.
    // 실제 G-code 조립/전송은 MappingExecutionService.pressPhysical에 있다
    // (이전엔 여기 인라인으로 중복돼 있었다).
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
    });

    switch (action) {
      case 'IMMEDIATE_PRESS':
        final pressBase = message.isNotEmpty ? message : '버튼을 누릅니다.';
        // 전송 "전"에 누르는 중임을 알린다. 이전에는 전송이 끝난 뒤에야
        // "누릅니다"라고 말해 시제도 결과도 어긋났다.
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
                deviceName: '전자레인지',
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
          case 'connection':
            navigateDest = const DeviceConnectScreen();
            destName = '기기 연결';
          case 'mapping':
            navigateDest = const ManualMappingScreen();
            destName = '버튼 매핑';
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
        appBar: const TopAppBar(title: 'Touch Bridge AI'),
        body: SafeArea(child: Center(child: _buildPressStatusView(rs))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: 'Touch Bridge AI'),
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
                        // liveRegion: true — 스크린리더 활성 시 이 상태 변화는
                        // 억제되는 navigation 우선순위 TTS를 대신해 스크린리더
                        // 자체 채널로 안내된다(억제만 하고 대체 채널이 없으면
                        // 사용자에게 아무 정보도 안 남는 문제를 막는다).
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _isProcessing
                                ? '분석 중...'
                                : (_isRecording ? 'Listening...' : '말씀해 주세요.'),
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
                        Semantics(
                          liveRegion: true,
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
                        if (isIdle)
                          VoiceExampleCommands(
                            scale: rs,
                            onCommandTap: (cmd) {
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
