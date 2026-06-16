import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../services/tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../safety/emergency_stop_screen.dart';
import '../../services/app_logger.dart';
import '../../services/ai_backend_service.dart';
import '../../services/active_device_service.dart';
import '../../services/ble_service.dart';
import '../../services/microwave_command_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_colors.dart';

class VoiceListeningScreen extends StatefulWidget {
  const VoiceListeningScreen({super.key, this.deviceId, this.deviceName, this.autoStart = false});

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
  String _statusMessage = '버튼을 눌러 명령을 말씀해 주세요.';
  String _recognizedText = '아직 인식된 명령이 없어요.';
  bool _speechEnabled = false;

  String _lastWords = '';

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
    _tts.stop();
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
            _statusMessage = '듣고 있습니다...';
          });
          return;
        }
        if ((status == 'done' || status == 'notListening') && _isRecording) {
          _onSttNaturalEnd();
        }
      },
      onError: (errorNotification) {
        if (mounted) {
          _speak('음성 인식 오류가 발생했습니다.');
          setState(() {
            _statusMessage = '음성 인식 오류';
            _isProcessing = false;
            _isRecording = false;
          });
          _stopWaveAnimation();
          _recordingTimeoutTimer?.cancel();
        }
      },
    );
    if (_speechEnabled) {
      _speak('음성 명령 화면입니다. 마이크 버튼을 한 번 누르면 선택되고, 한 번 더 누르면 녹음이 시작됩니다.');
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
  }) async {
    await _tts.speak(message, source: source);
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
      if (!mounted || !_isRecording) return;
      
      // 만약 이미 명령이 인식되어 처리 중이라면 침묵 타이머 무시
      if (_lastWords.isNotEmpty) {
        AppLogger.info('voice.silence_timer.trigger_stop', {'lastWords': _lastWords});
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
        _statusMessage = '아무 말씀도 인식되지 않았습니다.';
      });
      _speak('아무 말씀도 인식되지 않았습니다.');
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
          ? '명령 분석 중...'
          : '아무 말씀도 인식되지 않았습니다.';
    });

    if (_lastWords.isNotEmpty) {
      FeedbackService.instance.playDing();
      _speak('녹음이 완료되었습니다. 명령을 분석 중입니다.');
      _sendTextToGemini(_lastWords);
    } else {
      _speak('아무 말씀도 인식되지 않았습니다.');
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
        _statusMessage = '명령 분석 중...';
      });
      _stopWaveAnimation();
      _speak('녹음이 종료되었습니다.');
      if (_lastWords.isNotEmpty) {
        _sendTextToGemini(_lastWords);
      } else {
        _speak('인식된 음성이 없습니다.');
        setState(() {
          _statusMessage = '인식된 음성이 없습니다.';
          _isProcessing = false;
        });
      }
    } else {
      _isStartingRecording = true;
      _lastWords = '';
      try {
        if (_speech.isListening) {
          await _speech.stop();
        }
        if (mounted) {
          setState(() {
            _isRecording = true;
            _statusMessage = '듣고 있습니다...';
          });
        }
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _lastWords = result.recognizedWords;
                _recognizedText = _lastWords;
              });
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
      _actionResetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _micArmed = false);
      });
      _speak(_isRecording ? '녹음 중지' : '녹음 시작');
      return;
    }

    _actionResetTimer?.cancel();
    setState(() => _micArmed = false);
    _toggleRecording();
  }

  String _normalizeVoiceText(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  bool _isAffirmativeResponse(String text) {
    final t = _normalizeVoiceText(text);
    return const [
      '응',
      '네',
      '예',
      '맞아',
      '맞아요',
      '그래',
      '그래요',
      '좋아',
      '좋아요',
      'ok',
      'okay',
      '오케이',
    ].any((token) => t == token || t.contains(token));
  }

  bool _isNegativeResponse(String text) {
    final t = _normalizeVoiceText(text);
    return const [
      '아니',
      '아니야',
      '아니요',
      '아뇨',
      '취소',
      '그만',
      '중지',
      '멈춰',
      '안돼',
      '안해',
      '하지마',
    ].any((token) => t == token || t.contains(token));
  }

  Future<void> _sendTextToGemini(String text) async {
    final requestId = ++_analysisRequestId;
    AppLogger.info('voice.send_to_gemini.start', {'requestId': requestId, 'text': text});

    if (text.isEmpty) {
      AppLogger.warn('voice.send_to_gemini.empty_text');
      setState(() {
        _statusMessage = '명령이 없습니다.';
        _isProcessing = false;
      });
      return;
    }

    if (_pendingCommandData != null) {
      if (_isAffirmativeResponse(text)) {
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

      if (_isNegativeResponse(text)) {
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

    final ruleResult = MicrowaveCommandService.checkSimpleRules(text);
    if (ruleResult != null) {
      if (requestId != _analysisRequestId) return;
      AppLogger.info('voice.parse.simple_rule_hit', {'requestId': requestId});
      await _handleCommand(ruleResult, recognizedText: text);
      return;
    }

    try {
      final commandData = await AiBackendService.instance.parseVoiceCommand(
        text,
      );
      if (requestId != _analysisRequestId) return;
      AppLogger.info('voice.parse.backend_ok', {'requestId': requestId, 'action': commandData['action']});
      await _handleCommand(commandData, recognizedText: text);
    } catch (e) {
      AppLogger.error('voice.parse.error', {'requestId': requestId, 'error': e.toString()});
      if (requestId != _analysisRequestId) return;
      _speak('분석에 실패했습니다.');
      setState(() {
        _statusMessage = '분석 실패';
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

  Future<String?> _resolveMappingDeviceId() async {
    final explicitId = widget.deviceId?.trim();
    if (explicitId != null && explicitId.isNotEmpty) {
      return explicitId;
    }
    return ActiveDeviceService.instance.getActiveDeviceId();
  }

  Future<void> _sendBleSequence(List<dynamic> commands) async {
    final deviceId = BleService.instance.connectedDeviceId;
    if (!BleService.instance.isConnected || deviceId.isEmpty) {
      _speak('블루투스 연결이 필요합니다.');
      return;
    }

    final activeDeviceId = await _resolveMappingDeviceId();
    if (activeDeviceId == null || activeDeviceId.isEmpty) {
      _speak('먼저 홈 화면에서 제어할 기기를 선택해 주세요.');
      return;
    }

    final profile = await DeviceMappingService.instance.load(activeDeviceId);

    final gridOk = await BleService.instance.sendSetGrid(
      rows: profile.rows,
      cols: profile.cols,
      originX: profile.originX,
      originY: profile.originY,
      pitchX: profile.pitchX,
      pitchY: profile.pitchY,
      deviceId: deviceId,
    );

    if (!gridOk) {
      _speak('기기 설정 전송에 실패했습니다.');
      return;
    }

    // ESP32가 첫 번째 명령(set_grid)을 처리할 시간을 충분히 줌 (DROP 방지)
    await Future<void>.delayed(const Duration(milliseconds: 800));

    for (final dynamic raw in commands) {
      final btn = raw as String;
      final mapped = profile.buttonMap[btn];
      final pos = mapped == null
          ? MicrowaveCommandService.btnToGrid(btn)
          : (mapped.row, mapped.col);

      if (pos != null) {
        final ok = await BleService.instance.sendPress(
          x: pos.$2,
          y: pos.$1,
          cols: profile.cols,
          deviceId: deviceId,
        );
        if (!ok) {
          _speak('명령 전송 중 오류가 발생했습니다.');
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    // 모든 명령 수행 후 홈 위치로 복귀 (2초 대기 후 이동)
    await Future<void>.delayed(const Duration(seconds: 2));
    await BleService.instance.sendPress(
      x: profile.homeCol,
      y: profile.homeRow,
      cols: profile.cols,
      deviceId: deviceId,
    );
    AppLogger.info('voice.home_return', {
      'row': profile.homeRow,
      'col': profile.homeCol,
    });
  }

  Future<void> _handleCommand(
    Map<String, dynamic> data, {
    required String recognizedText,
    bool forceExecution = false,
  }) async {
    final action = data['action'] as String? ?? 'NONE';
    AppLogger.info('voice.handle_command', {'action': action, 'force': forceExecution});
    final message = (data['message'] as String? ?? '').trim();
    final commands = (data['commands'] as List<dynamic>?) ?? [];
    final inferredSeconds = (data['inferred_seconds'] as num?)?.toInt();
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.5;
    final needsConfirmation = (data['needs_confirmation'] as bool?) ?? false;
    final confirmationMessage =
        (data['confirmation_message'] as String? ?? '').trim();

    setState(() {
      _isProcessing = false;
      _recognizedText = recognizedText;
    });

    switch (action) {
      case 'IMMEDIATE_PRESS':
        await _sendBleSequence(commands);
        FeedbackService.instance.vibrateSuccess();
        await _speak(message);
        return;
        
      case 'EMERGENCY_STOP':
        FeedbackService.instance.vibrateError(); // 강한 진동
        await _speak(message.isNotEmpty ? message : '중단합니다.');
        final deviceId = BleService.instance.connectedDeviceId;
        if (deviceId.isNotEmpty) {
          await BleService.instance.sendEmergencyStop(deviceId);
        }
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyStopScreen()),
        );
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
        await _sendBleSequence(commands);
        FeedbackService.instance.vibrateSuccess(); // 성공 진동
        final spokenMessage = forceExecution && confirmationMessage.isNotEmpty
            ? confirmationMessage
            : message;
        await _speak(spokenMessage.isNotEmpty ? spokenMessage : '시작할게요.');

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
                        const Spacer(flex: 2),
                        Text(
                          _isProcessing
                              ? '분석 중...'
                              : (_isRecording ? 'Listening...' : '말씀해 주세요.'),
                          style: TextStyle(
                            color: (_isRecording || _isProcessing)
                                ? const Color(0xFFFFEB00)
                                : Colors.white,
                            fontSize: 34 * rs,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 10)),
                        Text(
                          _isProcessing
                              ? _statusMessage
                              : (_isRecording
                                  ? '듣고 있습니다.'
                                  : '버튼을 눌러 명령을 말씀해 주세요.'),
                          style: TextStyle(
                            color: const Color(0xFFD1D5DB),
                            fontSize: 16 * rs,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(flex: 2),
                        SizedBox(
                          height: waveH,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _waveHeights
                                .map(
                                  (h) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 7 * rs,
                                    height: waveH * h,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 3 * rs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isRecording
                                          ? const Color(0xFFFFEB00)
                                          : const Color(0xFF333333),
                                      borderRadius:
                                          BorderRadius.circular(4 * rs),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
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
                        const Spacer(flex: 2),
                        if (_isRecording) ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Semantics(
                                  label: '듣기 멈추기',
                                  button: true,
                                  child: GestureDetector(
                                    onTap: _handleMicTap,
                                    child: Container(
                                      height: 64 * rs,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEB00),
                                        borderRadius:
                                            BorderRadius.circular(16 * rs),
                                        border: _micArmed
                                            ? Border.all(
                                                color: Colors.white,
                                                width: 3 * rs,
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.stop_circle_outlined,
                                            color: Colors.black,
                                            size: 24 * rs,
                                          ),
                                          SizedBox(width: 8 * rs),
                                          Text(
                                            '듣기 멈추기',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 17 * rs,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12 * rs),
                              Expanded(
                                flex: 2,
                                child: Semantics(
                                  label: '취소',
                                  button: true,
                                  child: GestureDetector(
                                    onTap: () {
                                      _speech.stop();
                                      _recordingTimeoutTimer?.cancel();
                                      _stopWaveAnimation();
                                      setState(() {
                                        _isRecording = false;
                                        _isProcessing = false;
                                      });
                                      _speak('취소되었습니다.');
                                    },
                                    child: Container(
                                      height: 64 * rs,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E1E1E),
                                        borderRadius:
                                            BorderRadius.circular(16 * rs),
                                        border: Border.all(
                                          color: const Color(0xFF3A3A3A),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '취소',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 17 * rs,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (isIdle) ...[
                          Semantics(
                            label: '음성 명령 시작',
                            button: true,
                            child: GestureDetector(
                              onTap: _handleMicTap,
                              child: Container(
                                width: double.infinity,
                                height: 64 * rs,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEB00),
                                  borderRadius: BorderRadius.circular(16 * rs),
                                  border: _micArmed
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 3 * rs,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.mic,
                                      color: Colors.black,
                                      size: 26 * rs,
                                    ),
                                    SizedBox(width: 10 * rs),
                                    Text(
                                      _micArmed ? '지금 누르면 녹음 시작' : '녹음 준비',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 17 * rs,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            height: 64 * rs,
                            child: OutlinedButton.icon(
                              onPressed: _cancelAnalysis,
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFF555555)),
                                foregroundColor: const Color(0xFFD1D5DB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16 * rs),
                                ),
                              ),
                              icon: const Icon(Icons.close_rounded),
                              label: Text(
                                '분석 취소',
                                style: TextStyle(
                                  fontSize: 16 * rs,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: ResponsiveScale.v(context, 24)),
                        if (isIdle) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '예시 명령어',
                              style: TextStyle(
                                color: const Color(0xFF888888),
                                fontSize: 13 * rs,
                              ),
                            ),
                          ),
                          SizedBox(height: ResponsiveScale.v(context, 8)),
                          Wrap(
                            spacing: 8 * rs,
                            runSpacing: 8 * rs,
                            children: ['만두 데워줘', '우유 따뜻하게', '30초 돌려줘', '해동해줘']
                                .map(
                                  (cmd) => GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _recognizedText = cmd;
                                        _isProcessing = true;
                                      });
                                      _speak('$cmd 명령을 처리합니다.');
                                      _sendTextToGemini(cmd);
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14 * rs,
                                        vertical: 8 * rs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1A1A),
                                        borderRadius: BorderRadius.circular(
                                          20 * rs,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF333333),
                                        ),
                                      ),
                                      child: Text(
                                        cmd,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14 * rs,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const Spacer(flex: 1),
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
