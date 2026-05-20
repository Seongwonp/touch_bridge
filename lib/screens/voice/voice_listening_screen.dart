import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../services/tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart'; // Speech-to-Text 패키지 임포트

import '../../widgets/responsive_scale.dart';
import '../safety/emergency_stop_screen.dart';
import '../connection/device_connect_screen.dart';
import '../mapping/photo_mapping_screen.dart';
import '../settings/settings_screen.dart';
import '../../services/ai_backend_service.dart';
import '../../services/ble_service.dart';
import '../../services/microwave_command_service.dart';
import '../../services/accessibility_experiment_service.dart';

class VoiceListeningScreen extends StatefulWidget {
  const VoiceListeningScreen({super.key});

  @override
  State<VoiceListeningScreen> createState() => _VoiceListeningScreenState();
}

class _VoiceListeningScreenState extends State<VoiceListeningScreen> {
  final TtsService _tts = TtsService();
  final math.Random _random = math.Random();
  final SpeechToText _speech = SpeechToText(); // SpeechToText 인스턴스

  bool _isRecording = false;
  bool _isProcessing = false;
  String _statusMessage = '버튼을 눌러 명령을 말씀해 주세요.';
  String _recognizedText = '아직 인식된 명령이 없어요.';
  bool _speechEnabled = false; // SpeechToText 초기화 상태

  String _lastWords = ''; // SpeechToText에서 인식된 최종 단어

  Timer? _waveTimer;
  List<double> _waveHeights = const [
    0.20, 0.50, 0.80, 1.00, 0.60, 0.30, 1.00, 0.50, 0.70, 0.80, 0.20,
  ];

  Timer? _recordingTimeoutTimer;
  Timer? _silenceTimer;
  Timer? _actionResetTimer;
  bool _micArmed = false;
  bool _isStartingRecording = false;
  final Duration _maxRecordingDuration = const Duration(seconds: 8);
  static const _silenceTimeout = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    if (!AiBackendService.instance.isConfigured) {
      _statusMessage = 'AI_BACKEND_URL이 설정되지 않았습니다. .env 파일을 확인해주세요.';
      _speak(_statusMessage);
    } else {
      _initSpeech();
    }
  }

  Future<void> _initSpeech() async {
    // macOS 26 beta: SFSpeechRecognizer triggers TCC abort (OS bug)
    // kIsWeb: browser STT works fine even on Mac host
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      if (mounted) setState(() => _statusMessage = 'macOS 앱에서는 음성 인식이 지원되지 않습니다.');
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
        // Chrome Web Speech API calls 'done' when it stops naturally (silence)
        if ((status == 'done' || status == 'notListening') && _isRecording) {
          _onSttNaturalEnd();
        }
      },
      onError: (errorNotification) {
        if (mounted) {
          _speak('음성 인식 오류가 발생했습니다: ${errorNotification.errorMsg}');
          setState(() {
            _statusMessage = '음성 인식 오류: ${errorNotification.errorMsg}';
            _isProcessing = false;
            _isRecording = false;
          });
          _stopWaveAnimation();
          _recordingTimeoutTimer?.cancel();
        }
      },
    );
    if (_speechEnabled) {
      _speak('음성 명령 화면입니다. 마이크 버튼을 한 번 누르면 선택되고, 한 번 더 누르면 녹음이 시작됩니다. 이전 화면으로 돌아가려면 화면을 왼쪽에서 오른쪽으로 쓸어주세요.');
    } else {
      _speak('음성 인식 기능을 사용할 수 없습니다. 마이크 권한을 확인해주세요.');
      setState(() {
        _statusMessage = '음성 인식 기능을 사용할 수 없습니다.';
      });
    }
  }

  Future<void> _speak(String message) async {
    await _tts.speak(message);
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, () {
      if (!mounted || !_isRecording) return;
      if (_lastWords.isEmpty) {
        _speech.stop();
        _recordingTimeoutTimer?.cancel();
        _stopWaveAnimation();
        setState(() {
          _isRecording = false;
          _isProcessing = false;
          _statusMessage = '아무 말씀도 인식되지 않았습니다.';
        });
        _speak('아무 말씀도 인식되지 않았습니다. 버튼을 눌러 다시 시도해주세요.');
      } else {
        // 말이 있으면 바로 처리
        _toggleRecording();
      }
    });
  }

  void _onSttNaturalEnd() {
    if (!_isRecording) return;
    _silenceTimer?.cancel();
    _recordingTimeoutTimer?.cancel();
    _stopWaveAnimation();
    setState(() {
      _isRecording = false;
      _isProcessing = _lastWords.isNotEmpty;
      _statusMessage = _lastWords.isNotEmpty ? '명령 분석 중...' : '아무 말씀도 인식되지 않았습니다.';
    });
    if (_lastWords.isNotEmpty) {
      _speak('녹음이 완료되었습니다. 명령을 분석 중입니다.');
      _sendTextToGemini(_lastWords);
    } else {
      _speak('아무 말씀도 인식되지 않았습니다. 버튼을 눌러 다시 시도해주세요.');
    }
  }

  Future<void> _goBackWithSwipe() async {
    final navigator = Navigator.of(context);

    if (_isRecording) {
      await _speech.stop();
      _recordingTimeoutTimer?.cancel();
      _stopWaveAnimation();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessing = false;
        });
      }
    }
    if (navigator.canPop()) {
      await _tts.speak('이전 화면으로 돌아갑니다.');
      if (mounted) {
        navigator.pop();
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 450) {
      _goBackWithSwipe();
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
        0.20, 0.50, 0.80, 1.00, 0.60, 0.30, 1.00, 0.50, 0.70, 0.80, 0.20,
      ];
    });
  }

  Future<void> _toggleRecording() async {
    if (_isStartingRecording) return;
    if (!_speechEnabled) {
      _speak('음성 인식 기능을 사용할 수 없습니다.');
      return;
    }
    if (!AiBackendService.instance.isConfigured) {
      _speak('AI 백엔드가 설정되지 않아 음성 명령을 처리할 수 없습니다.');
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
      _speak('녹음이 종료되었습니다. 명령을 분석 중입니다.');
      if (_lastWords.isNotEmpty) {
        _sendTextToGemini(_lastWords);
      } else {
        _speak('인식된 음성이 없습니다. 다시 말씀해 주세요.');
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
          localeId: 'ko_KR',
          listenOptions: SpeechListenOptions(
            listenMode: ListenMode.dictation,
            partialResults: true,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (_speech.isListening || _isRecording) {
          _startWaveAnimation();
          HapticFeedback.mediumImpact();
          _speak('녹음을 시작합니다. 명령을 말씀해주세요.');
          _resetSilenceTimer(); // 5초 침묵 감지 시작

          _recordingTimeoutTimer = Timer(_maxRecordingDuration, () {
            if (_isRecording) {
              _speak('녹음 시간이 초과되었습니다. 명령을 분석 중입니다.');
              _toggleRecording();
            }
          });
        } else {
          _speak('마이크를 사용할 수 없습니다. 권한을 확인해주세요.');
          setState(() {
            _isRecording = false;
            _statusMessage = '마이크를 사용할 수 없습니다.';
          });
        }
      } catch (_) {
        setState(() {
          _isRecording = false;
          _statusMessage = '마이크 시작 중 충돌이 발생했습니다. 다시 시도해주세요.';
        });
      } finally {
        _isStartingRecording = false;
      }
    }
  }

  void _handleMicTap() {
    if (_isProcessing) {
      return;
    }

    if (!_micArmed) {
      setState(() {
        _micArmed = true;
      });
      HapticFeedback.mediumImpact();
      _actionResetTimer?.cancel();
      _actionResetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _micArmed = false;
          });
        }
      });
      _speak(_isRecording
          ? '녹음 중지 버튼입니다. 한 번 더 누르면 녹음을 중지합니다.'
          : '녹음 준비 버튼입니다. 지금 한 번 더 누르면 녹음이 시작됩니다.');
      return;
    }

    _actionResetTimer?.cancel();
    setState(() {
      _micArmed = false;
    });
    _toggleRecording();
  }

  Future<void> _sendTextToGemini(String text) async {
    if (text.isEmpty) {
      _speak('처리할 명령이 없습니다.');
      setState(() {
        _statusMessage = '처리할 명령이 없습니다.';
        _isProcessing = false;
      });
      return;
    }

    // 간단한 명령은 AI 호출 없이 즉시 처리
    final ruleResult = MicrowaveCommandService.checkSimpleRules(text);
    if (ruleResult != null) {
      _handleCommand(ruleResult, recognizedText: text);
      return;
    }

    try {
      final commandData = await AiBackendService.instance.parseVoiceCommand(text);
      _handleCommand(commandData, recognizedText: text);
    } catch (e) {
      _speak('AI 처리 중 문제가 발생했습니다: $e');
      setState(() {
        _statusMessage = 'AI 처리 오류: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _sendBleSequence(List<dynamic> commands) async {
    final deviceId = BleService.instance.connectedDeviceId;
    if (!BleService.instance.isConnected || deviceId.isEmpty) {
      _speak('블루투스가 연결되어 있지 않아 실제 기기 제어는 실행되지 않았습니다.');
      return;
    }

    for (final dynamic raw in commands) {
      final btn = raw as String;
      if (btn == 'BT-05') continue; // 시작 버튼은 논리 신호로만 사용
      final pos = MicrowaveCommandService.btnToGrid(btn);
      if (pos == null) continue;
      await BleService.instance.sendPress(
        x: pos.$2,
        y: pos.$1,
        deviceId: deviceId,
      );
    }
  }

  Future<void> _handleCommand(Map<String, dynamic> data, {required String recognizedText}) async {
    final action = data['action'] as String? ?? 'NONE';
    final message = (data['message'] as String? ?? '').trim();
    final commands = (data['commands'] as List<dynamic>?) ?? [];

    setState(() {
      _isProcessing = false;
      _recognizedText = recognizedText;
    });

    switch (action) {
      case 'EMERGENCY_STOP':
        final tts = message.isNotEmpty ? message : '비상 정지 명령을 수행합니다.';
        await _speak(tts);
        final deviceId = BleService.instance.connectedDeviceId;
        if (deviceId.isNotEmpty) {
          await BleService.instance.sendEmergencyStop(deviceId);
        }
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyStopScreen()));
        return;

      case 'NAVIGATE':
        final target = data['target'] as String?;
        final targetName = switch (target) {
          'connection' => '기기 연결',
          'mapping'    => '버튼 매핑',
          'settings'   => '설정',
          _            => null,
        };
        if (targetName == null) {
          await _speak('이동할 화면을 이해하지 못했습니다.');
          setState(() => _statusMessage = '이동할 화면을 이해하지 못했습니다.');
          return;
        }
        final tts = message.isNotEmpty ? message : '$targetName 화면으로 이동합니다.';
        await _speak(tts);
        final Widget? screen = switch (target) {
          'connection' => const DeviceConnectScreen(),
          'mapping'    => const PhotoMappingScreen(),
          'settings'   => const SettingsScreen(),
          _            => null,
        };
        if (!mounted) return;
        if (screen != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        }
        return;

      case 'MICROWAVE_CONTROL':
        if (commands.isEmpty) {
          await _speak(message.isNotEmpty ? message : '시간을 말씀해 주세요. 예: 30초 돌려줘');
          setState(() => _statusMessage = '시간을 말씀해 주세요.');
          return;
        }

        // 취소/정지 명령
        if (commands.length == 1 && commands.first == 'BT-06') {
          await _speak(message.isNotEmpty ? message : '조리를 중단합니다.');
          setState(() => _statusMessage = '조리 중단');
          final deviceId = BleService.instance.connectedDeviceId;
          if (deviceId.isNotEmpty) {
            await BleService.instance.sendEmergencyStop(deviceId);
          }
          return;
        }

        final seconds = MicrowaveCommandService.calculateSeconds(commands);
        final cmdLabel = MicrowaveCommandService.buildCommandsLabel(commands);
        final tts = message.isNotEmpty ? message : '$cmdLabel. 조리를 시작합니다.';

        setState(() => _statusMessage = cmdLabel);

        await _sendBleSequence(commands);

        if (seconds > 0) {
          await AccessibilityExperimentService.instance.recordTaskStarted(TaskMode.voice);
          await _speak(tts);
          if (mounted) {
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
        } else {
          await _speak(tts);
        }
        return;

      case 'NONE':
      default:
        final tts = message.isNotEmpty ? message : '명령을 이해하지 못했습니다. 다시 말씀해 주세요.';
        await _speak(tts);
        setState(() => _statusMessage = '다시 말씀해 주세요.');
        return;
    }
  }


  @override
  void dispose() {
    _waveTimer?.cancel();
    _recordingTimeoutTimer?.cancel();
    _silenceTimer?.cancel();
    _actionResetTimer?.cancel();
    _speech.stop(); // SpeechToText 리소스 해제
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }

  static const _exampleCommands = [
    '30초 돌려줘',
    '1분 조리해줘',
    '2분 30초',
    '해동해줘',
    '취소해줘',
  ];

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final screenH = MediaQuery.sizeOf(context).height;
    final waveH = (screenH * 0.12).clamp(48.0, 100.0);

    final bool isIdle = !_isRecording && !_isProcessing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: SafeArea(
          child: Column(
            children: [
              // 상단 앱바
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Touch Bridge AI',
                    style: TextStyle(
                      color: Color(0xFFFFEB00),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // 큰 타이틀 (Listening... / 분석 중... / 말씀해 주세요.)
                      Text(
                        _isProcessing
                            ? '분석 중...'
                            : (_isRecording ? 'Listening...' : '말씀해 주세요.'),
                        style: TextStyle(
                          color: (_isRecording || _isProcessing)
                              ? const Color(0xFFFFEB00)
                              : Colors.white,
                          fontSize: 36 * rs,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 10),

                      // 부제목
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

                      // 음성 파형 애니메이션
                      SizedBox(
                        height: waveH,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _waveHeights
                              .map(
                                (h) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 7,
                                  height: waveH * h,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: _isRecording
                                        ? const Color(0xFFFFEB00)
                                        : const Color(0xFF333333),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),

                      // 인식 중 텍스트 (녹음 중에만 표시)
                      if (_isRecording && _recognizedText.isNotEmpty &&
                          _recognizedText != '아직 인식된 명령이 없어요.') ...[
                        const SizedBox(height: 16),
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

                      // 버튼 영역: 듣기 멈추기 + 취소 (녹음 중) / 시작 (대기 중)
                      if (_isRecording) ...[
                        // 녹음 중 — 듣기 멈추기(노랑) + 취소(어두운) 2버튼
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Semantics(
                                label: _micArmed
                                    ? '듣기 멈추기 버튼 선택됨. 한 번 더 탭하면 녹음을 중지합니다.'
                                    : '듣기 멈추기 버튼',
                                button: true,
                                child: GestureDetector(
                                  onTap: _handleMicTap,
                                  child: Container(
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: _micArmed
                                          ? const Color(0xFFFFD700)
                                          : const Color(0xFFFFEB00),
                                      borderRadius: BorderRadius.circular(16),
                                      border: _micArmed
                                          ? Border.all(color: Colors.white, width: 3)
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.stop_circle_outlined,
                                            color: Colors.black, size: 24),
                                        const SizedBox(width: 8),
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
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Semantics(
                                label: '취소 버튼',
                                button: true,
                                child: GestureDetector(
                                  onTap: () {
                                    _speech.stop();
                                    _recordingTimeoutTimer?.cancel();
                                    _silenceTimer?.cancel();
                                    _actionResetTimer?.cancel();
                                    _stopWaveAnimation();
                                    setState(() {
                                      _isRecording = false;
                                      _isProcessing = false;
                                      _micArmed = false;
                                      _lastWords = '';
                                      _statusMessage = '버튼을 눌러 명령을 말씀해 주세요.';
                                    });
                                    _speak('녹음이 취소되었습니다.');
                                  },
                                  child: Container(
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFF3A3A3A)),
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
                        // 대기 중 — 시작 버튼 1개
                        Semantics(
                          label: _micArmed
                              ? '음성 명령 시작 버튼 선택됨. 한 번 더 탭하면 녹음이 시작됩니다.'
                              : '음성 명령 시작 버튼',
                          button: true,
                          child: GestureDetector(
                            onTap: _handleMicTap,
                            child: Container(
                              width: double.infinity,
                              height: 64,
                              decoration: BoxDecoration(
                                color: _micArmed
                                    ? const Color(0xFFFFD700)
                                    : const Color(0xFFFFEB00),
                                borderRadius: BorderRadius.circular(16),
                                border: _micArmed
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.mic, color: Colors.black, size: 26),
                                  const SizedBox(width: 10),
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
                        // 분석 중 — 비활성 버튼
                        Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFFFEB00),
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '명령 분석 중...',
                                  style: TextStyle(
                                    color: const Color(0xFF888888),
                                    fontSize: 16 * rs,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // 예제 명령어 칩 (대기 중에만 표시)
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
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _exampleCommands
                              .map(
                                (cmd) => GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _recognizedText = cmd;
                                      _isProcessing = true;
                                      _statusMessage = '명령 분석 중...';
                                    });
                                    _speak('$cmd 명령을 처리합니다.');
                                    _sendTextToGemini(cmd);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1A),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFF333333)),
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
            ],
          ),
        ),
      ),
    );
  }
}
