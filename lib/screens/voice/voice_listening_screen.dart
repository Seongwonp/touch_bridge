import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import '../../services/help_intent.dart';
import '../../services/microwave_command_service.dart';
import '../../services/appliance_command_router.dart';
import '../../services/replay_intent.dart';
import '../../services/device_mapping_service.dart';
import '../../services/feedback_service.dart';
import '../../services/voice_device_resolver.dart';
import '../../services/mapping_execution_service.dart';
import '../../services/home_device_store.dart';
import '../../services/voice_text_matcher.dart';
import '../../theme/app_colors.dart';
import 'widgets/voice_wave_visualizer.dart';
import 'widgets/voice_action_buttons.dart';
import 'widgets/voice_example_commands.dart';
import '../../widgets/ble_status_banner.dart';

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
  State<VoiceListeningScreen> createState() => _VoiceListeningScreenState();
}

class _VoiceListeningScreenState extends State<VoiceListeningScreen> {
  final TtsService _tts = TtsService();
  final math.Random _random = math.Random();
  final SpeechToText _speech = SpeechToText();

  bool _isRecording = false;
  bool _isProcessing = false;
  String _statusMessage = '말하기 버튼을 눌러 명령하세요.';
  String _recognizedText = '아직 인식된 명령이 없어요.';
  bool _speechEnabled = false;

  String _lastWords = '';

  // 부엌 소음 대응: STT 인식 신뢰도가 낮으면 바로 실행하지 않고 인식한
  // 문장을 먼저 확인한다. missingConfidence(-1)일 때는 신뢰도를 신뢰할 수
  // 없는 신호이므로 게이트를 걸지 않는다(플랫폼에 따라 항상 -1/1.0을 주는
  // 경우가 있어, 없는 신호로 정상 동작을 막지 않기 위함).
  double _lastConfidence = SpeechRecognitionWords.missingConfidence;
  static const double _lowConfidenceThreshold = 0.5;
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
  static const _silenceTimeout = Duration(seconds: 8);

  String? _resolvedDeviceId;
  String? _resolvedDeviceName;

  @override
  void initState() {
    super.initState();
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
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지워버린다(화면 전환 시 안내가 잘리는 문제).
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      if (mounted) {
        setState(() => _statusMessage = 'macOS 앱에서는 음성 인식이 지원되지 않습니다.');
      }
      return;
    }
    _speechEnabled = await _speech.initialize(
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
      onError: (errorNotification) {
        if (mounted) {
          _speak('음성 인식에 실패했습니다. 마이크 버튼을 다시 눌러주세요.');
          setState(() {
            _statusMessage = '음성 인식 실패';
            _isProcessing = false;
            _isRecording = false;
          });
          _stopWaveAnimation();
          _recordingTimeoutTimer?.cancel();
        }
      },
    );
    if (_speechEnabled) {
      _speak('음성 명령입니다. 마이크 버튼을 눌러 명령하세요.');
    } else {
      _speak('음성 인식 기능을 사용할 수 없습니다.');
      setState(() {
        _statusMessage = '음성 인식 기능을 사용할 수 없습니다.';
      });
    }
  }

  Future<void> _speak(
    String message, {
    String source = 'voicelisteningScreen',
    bool interrupt = false,
  }) async {
    await _tts.speak(message, source: source, interrupt: interrupt);
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
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
      _speech.stop();
      _recordingTimeoutTimer?.cancel();
      _stopWaveAnimation();
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _statusMessage = '말씀이 들리지 않았습니다.';
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
      _speech.stop();
      _recordingTimeoutTimer?.cancel();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _statusMessage = '명령을 확인하고 있습니다.';
      });
      _stopWaveAnimation();
      _speak('녹음이 종료되었습니다.');
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
        if (_speech.isListening) {
          await _speech.stop();
        }
        if (mounted) {
          setState(() {
            _isRecording = true;
            _statusMessage = '듣고 있습니다.';
          });
        }
        await _speech.listen(
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
        if (_speech.isListening || _isRecording) {
          _startWaveAnimation();
          FeedbackService.instance.playDing(); // "띵" 소리 추가
          FeedbackService.instance.vibrateSuccess(); // 짧은 진동 추가
          _speak('녹음을 시작합니다.');

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
      _actionResetTimer = Timer(const Duration(seconds: 20), () {
        if (mounted) setState(() => _micArmed = false);
      });
      _speak(_isRecording ? '녹음 중지' : '녹음 시작');
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

  void _restartListeningAfterPrompt() {
    if (!_speechEnabled || !mounted) return;
    Future<void>.delayed(const Duration(milliseconds: 900), () {
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

    if (text.isEmpty) {
      AppLogger.warn('voice.send_to_gemini.empty_text');
      setState(() {
        _statusMessage = '명령이 없습니다.';
        _isProcessing = false;
      });
      return;
    }

    // 어떤 상태(확인 대기/기기 선택/AI 분석)보다 먼저 "멈춰/그만/정지"를 최우선 처리한다.
    if (EmergencyIntent.matches(text)) {
      AppLogger.info('voice.emergency_intercept', {'requestId': requestId});
      _pendingCommandData = null;
      setState(() {
        _statusMessage = '중단';
        _isProcessing = false;
      });
      await _handleEmergencyStop();
      return;
    }

    // "무엇을 할 수 있어?" 류 발화도 AI를 거치지 않고 즉시 답한다. 화면의
    // 예시 명령어 칩을 볼 수 없는 사용자를 위한 발견성 보완.
    if (HelpIntent.matches(text)) {
      AppLogger.info('voice.help_intercept', {'requestId': requestId});
      _pendingCommandData = null;
      setState(() {
        _statusMessage = '도움말';
        _isProcessing = false;
      });
      await _speak(HelpIntent.buildResponse(), interrupt: true);
      return;
    }

    // "다시 말해줘/뭐라고/안 들려"는 부엌 소음으로 안내를 놓쳤을 때 쓴다.
    // 확인 대기 상태(_pendingCommandData/_pendingLowConfidenceText)는 지우지
    // 않는다 — 놓친 게 확인 질문 자체일 수 있으므로 맥락을 그대로 유지한 채
    // 마지막 안내만 다시 들려준다.
    if (ReplayIntent.matches(text)) {
      AppLogger.info('voice.replay_intercept', {'requestId': requestId});
      setState(() => _isProcessing = false);
      await _tts.replayLast();
      return;
    }

    // 낮은 신뢰도로 확인을 요청했던 문장에 대한 예/아니오 응답 처리.
    // 부엌 소음(후드·전자레인지 등)으로 오인식된 문장을 그대로 실행하지
    // 않기 위한 안전장치 — _pendingCommandData(이미 파싱된 명령 확인)와는
    // 별개로, "무엇을 들었는지" 자체를 먼저 확인한다.
    if (_pendingLowConfidenceText != null) {
      final pendingText = _pendingLowConfidenceText!;
      _pendingLowConfidenceText = null;
      if (VoiceTextMatcher.isAffirmative(text)) {
        AppLogger.info('voice.low_confidence.confirmed', {
          'requestId': requestId,
        });
        // 사용자가 직접 확인했으므로 재확인 루프에 빠지지 않게 신뢰도를
        // 신뢰 가능한 값으로 리셋한 뒤 원문을 다시 처리한다.
        _lastConfidence = 1.0;
        await _sendTextToGemini(pendingText);
        return;
      }
      if (VoiceTextMatcher.isNegative(text)) {
        AppLogger.info('voice.low_confidence.rejected', {
          'requestId': requestId,
        });
        setState(() {
          _statusMessage = '취소됨';
          _isProcessing = false;
        });
        await _speak('알겠습니다. 다시 말씀해 주세요.');
        return;
      }
      // 예/아니오가 아니면 새로 들어온 문장을 새 명령으로 계속 처리한다.
    }

    // 소음 환경 등으로 인식 신뢰도가 낮으면 바로 실행하지 않고 들은 문장을
    // 먼저 확인한다. missingConfidence(-1)일 때는 게이트를 걸지 않는다.
    if (_lastConfidence != SpeechRecognitionWords.missingConfidence &&
        _lastConfidence < _lowConfidenceThreshold) {
      AppLogger.info('voice.low_confidence_confirm', {
        'requestId': requestId,
        'confidence': _lastConfidence,
      });
      _pendingLowConfidenceText = text;
      setState(() {
        _statusMessage = '다시 확인 중';
        _isProcessing = false;
      });
      await _speak('"$text"라고 들었어요. 맞으면 "예", 아니면 "아니오"라고 말씀해 주세요.', interrupt: true);
      return;
    }

    if (_pendingCommandData != null) {
      if (VoiceTextMatcher.isAffirmative(text)) {
        AppLogger.info('voice.response.affirmative', {'requestId': requestId});
        final pending = _pendingCommandData!;
        _pendingCommandData = null;
        await _handleCommand(
          pending,
          recognizedText: text,
          forceExecution: true,
        );
        return;
      }

      if (VoiceTextMatcher.isNegative(text)) {
        AppLogger.info('voice.response.negative', {'requestId': requestId});
        _pendingCommandData = null;
        setState(() {
          _statusMessage = '취소됨';
          _isProcessing = false;
        });
        await _speak('알겠습니다. 취소할게요.');
        return;
      }

      _pendingCommandData = null;
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

    if (resolution.needsClarification || resolution.needsAction) {
      AppLogger.info('voice.device_resolution.follow_up', {
        'requestId': requestId,
        'needsClarification': resolution.needsClarification,
        'needsAction': resolution.needsAction,
      });
      setState(() {
        _statusMessage = resolution.message;
        _isProcessing = false;
      });
      await _speak(resolution.message);
      _restartListeningAfterPrompt();
      return;
    }

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
      _speak('명령을 이해하지 못했습니다. 기기 이름과 동작을 함께 말해 주세요.');
      setState(() {
        _statusMessage = '명령 이해 실패';
        _isProcessing = false;
      });
    }
  }

  void _cancelAnalysis() {
    _analysisRequestId++;
    _pendingCommandData = null;
    setState(() {
      _isProcessing = false;
      _statusMessage = '취소됨';
    });
    _speak('취소되었습니다.');
  }

  /// 어떤 흐름에서도 공용으로 쓰는 정직한 비상 정지 처리.
  /// 실제 하드웨어에 정지 명령을 보내고, 확인 결과에 따라 안내를 분기한다.
  Future<void> _handleEmergencyStop() async {
    FeedbackService.instance.vibrateError();
    final targetId = BleService.instance.connectedDeviceId.isNotEmpty
        ? BleService.instance.connectedDeviceId
        : (ActiveDeviceService.instance.getActiveBleId() ?? '');

    EmergencyStopOutcome outcome;
    if (targetId.isEmpty) {
      outcome = const EmergencyStopOutcome(
        acknowledged: false,
        sent: false,
        message: '연결된 기기가 없습니다. 기기 전원을 확인해 주세요.',
      );
    } else {
      if (!BleService.instance.isConnected) {
        await BleService.instance.ensureConnected(targetId);
      }
      final ack = await BleService.instance.sendEmergencyStop(targetId);
      outcome = EmergencyStopOutcome.fromAck(ack);
    }

    if (outcome.acknowledged) {
      FeedbackService.instance.playSuccess();
    } else {
      FeedbackService.instance.playFailure();
    }
    await _speak(outcome.message, interrupt: true);
    if (!mounted) return;
    if (outcome.acknowledged) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()),
      );
    }
  }

  /// 버튼 시퀀스를 기기에 전송한다. 전송 성공 시 true, 실패 시(연결/매핑 실패 등)
  /// 사용자에게 원인을 안내하고 false를 반환한다. 호출부는 이 값으로 성공 피드백을 건다.
  Future<bool> _sendBleSequence(List<dynamic> commands) async {
    // [DEMO PRIORITY] 이미 연결된 기기가 있다면 즉시 사용
    String deviceId = BleService.instance.connectedDeviceId;

    if (deviceId.isEmpty) {
      // 연결된 게 없을 때만 자동 선택 및 재연결 시도
      await ActiveDeviceService.instance.autoPickFirstDevice();
      final activeBleId = ActiveDeviceService.instance.getActiveBleId();
      if (activeBleId == null) {
        _speak('먼저 보호자에게 기기 연결을 요청해 주세요.');
        return false;
      }

      _speak('기기에 연결 중입니다...');
      final connected = await BleService.instance.ensureConnected(activeBleId);
      if (!connected) {
        _speak('연결에 실패했습니다. 기기 전원을 확인하세요.');
        return false;
      }
      deviceId = BleService.instance.connectedDeviceId;
    }

    // 활성 기기 프로필 로드. 저장된 매핑이 있으면 목데이터보다 우선 사용한다.
    final activeApplianceId =
        ActiveDeviceService.instance.getActiveDeviceId() ?? '';
    final profile = await DeviceMappingService.instance.load(activeApplianceId);
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
        _speak(result.userMessage);
        return false;
      }
      return true;
    }

    // 저장 매핑이 없을 때만 검증된 데모 목데이터 물리 좌표를 fallback으로 쓴다.
    // 실제 G-code 조립/전송은 MappingExecutionService.pressPhysical에 있다
    // (이전엔 여기 인라인으로 중복돼 있었다).
    for (final dynamic raw in commands) {
      final btn = raw as String;
      final result = await MappingExecutionService.instance.pressPhysical(btn);
      if (!result.ok) {
        _speak(result.userMessage);
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    return true;
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
        final immediateSent = await _sendBleSequence(commands);
        if (!immediateSent) {
          FeedbackService.instance.playFailure(); // 실패 안내는 _sendBleSequence가 함
          return;
        }
        // "성공"이 아니라 "전송됨"이다: BLE write 성공일 뿐 GRBL 확인이 아니다.
        FeedbackService.instance.signalSent();
        // interrupt: true → TtsPriority.result로 승격. 스크린리더 활성 시에도 억제되지
        // 않으므로 전맹 사용자도 "무엇이 전송됐는지" 안내를 받는다.
        // _statusMessage 갱신 → liveRegion이 스크린리더 채널로 동일 내용을 다시 전달(이중 보장).
        setState(() => _statusMessage = message);
        await _speak(message, interrupt: true);
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
          return;
        }

        final seconds =
            inferredSeconds ??
            MicrowaveCommandService.calculateSeconds(commands);
        final microwaveSent = await _sendBleSequence(commands);
        if (!microwaveSent) {
          FeedbackService.instance.playFailure(); // 실패: 성공 피드백/이동 금지
          return;
        }
        // "성공"이 아니라 "전송됨"이다: BLE write 성공일 뿐 GRBL 확인이 아니다.
        FeedbackService.instance.signalSent();
        final spokenMessage = forceExecution && confirmationMessage.isNotEmpty
            ? confirmationMessage
            : message;
        final finalMsg = spokenMessage.isNotEmpty ? spokenMessage : '시작할게요.';
        setState(() => _statusMessage = finalMsg);
        await _speak(finalMsg, interrupt: true);

        if (seconds > 0 && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => EmergencyStopScreen(
                initialSeconds: seconds,
                deviceName: '전자레인지',
              ),
            ),
          );
        }
        return;

      default:
        final fallback = message.isNotEmpty ? message : '이해하지 못했습니다.';
        setState(() {
          _statusMessage = fallback;
        });
        await _speak(fallback);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final screenH = MediaQuery.sizeOf(context).height;
    final waveH = (screenH * 0.12).clamp(48.0, 100.0);
    final bool isIdle = !_isRecording && !_isProcessing;

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
                            _speech.stop();
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
