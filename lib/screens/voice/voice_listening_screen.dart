import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../services/tts_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart'; // Speech-to-Text 패키지 임포트
import 'package:google_generative_ai/google_generative_ai.dart'; // Gemini API 패키지 임포트

import '../../widgets/responsive_scale.dart';
import '../safety/emergency_stop_screen.dart';
import '../connection/device_connect_screen.dart';
import '../mapping/photo_mapping_screen.dart';
import '../settings/settings_screen.dart';

class VoiceListeningScreen extends StatefulWidget {
  const VoiceListeningScreen({super.key});

  @override
  State<VoiceListeningScreen> createState() => _VoiceListeningScreenState();
}

class _VoiceListeningScreenState extends State<VoiceListeningScreen> {
  final TtsService _tts = TtsService();
  final math.Random _random = math.Random();
  final SpeechToText _speech = SpeechToText(); // SpeechToText 인스턴스

  late final GenerativeModel _geminiModel; // Gemini 모델 인스턴스
  late final String _googleAiProApiKey; // Gemini API 키
  late final String _geminiModelName; // Gemini 모델명

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
  Timer? _actionResetTimer;
  bool _micArmed = false;
  final Duration _maxRecordingDuration = const Duration(seconds: 8); // 최대 녹음 시간

  @override
  void initState() {
    super.initState();
    _googleAiProApiKey = dotenv.get('GOOGLE_AI_PRO_API_KEY', fallback: ''); // fallback 추가
    _geminiModelName = dotenv.get('GEMINI_MODEL', fallback: 'gemini-2.5-flash');
    if (_googleAiProApiKey.isEmpty) {
      _statusMessage = 'API 키가 설정되지 않았습니다. .env 파일을 확인해주세요.';
      _speak(_statusMessage);
    } else {
      _geminiModel = GenerativeModel(model: _geminiModelName, apiKey: _googleAiProApiKey);
      _initSpeech();
    }
  }

  Future<void> _initSpeech() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      setState(() {
        _speechEnabled = false;
        _statusMessage = 'macOS에서는 음성 인식 기능이 현재 비활성화되어 있습니다.';
      });
      _speak(_statusMessage);
      return;
    }

    _speechEnabled = await _speech.initialize(
      onStatus: (status) {
        // SpeechToText의 상태 변화를 감지 (선택 사항)
        // print('SpeechToText status: $status');
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
    if (!_speechEnabled) {
      _speak('음성 인식 기능을 사용할 수 없습니다.');
      return;
    }
    if (_googleAiProApiKey.isEmpty) {
      _speak('API 키가 설정되지 않아 음성 명령을 처리할 수 없습니다.');
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
      _lastWords = ''; // 새로운 녹음 시작 시 초기화
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _lastWords = result.recognizedWords;
              _recognizedText = _lastWords; // 실시간 인식 결과 업데이트
            });
          }
        },
        localeId: 'ko_KR',
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true, // 부분 결과도 받아서 실시간 피드백 가능
        ),
      );

      if (_speech.isListening) {
        setState(() {
          _isRecording = true;
          _statusMessage = '듣고 있습니다...';
        });
        _startWaveAnimation();
        HapticFeedback.mediumImpact();
        _speak('녹음을 시작합니다. 명령을 말씀해주세요.');

        _recordingTimeoutTimer = Timer(_maxRecordingDuration, () {
          if (_isRecording) {
            _speak('녹음 시간이 초과되었습니다. 명령을 분석 중입니다.');
            _toggleRecording(); // 자동으로 녹음 종료
          }
        });
      } else {
        _speak('마이크를 사용할 수 없습니다. 권한을 확인해주세요.');
        setState(() {
          _statusMessage = '마이크를 사용할 수 없습니다.';
        });
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
          : '녹음 시작 버튼입니다. 한 번 더 누르면 녹음을 시작합니다.');
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

    try {
      final content = [
        Content.text('''
          You are an AI assistant that controls smart home devices.
          Analyze the user's voice command and respond in a JSON format.
          The "action" field must be one of: EMERGENCY_STOP, NAVIGATE, MICROWAVE_CONTROL, NONE.
          If the "action" is "NAVIGATE", include a "target" field with a value of: connection, mapping, settings.
          If the "action" is "MICROWAVE_CONTROL", include a "commands" field as an array, with values like: "start", "stop", "set_time_30s", "set_time_1m", "set_time_2m".
          If you cannot understand the command, set "action" to "NONE" and include a "message" field with an appropriate response for the user.
          Your response must be a JSON object. Do not include any other explanations or text outside the JSON.

          User's command: "$text"
          '''),
      ];

      final response = await _geminiModel.generateContent(content);

      if (response.text != null) {
        String geminiOutputText = response.text!.trim();
        // Gemini가 JSON 문자열을 마크다운 코드 블록으로 반환할 수 있으므로 파싱
        if (geminiOutputText.startsWith('```json')) {
          geminiOutputText = geminiOutputText.substring(7, geminiOutputText.length - 3).trim();
        } else if (geminiOutputText.startsWith('```')) { // 일반 코드 블록도 처리
          geminiOutputText = geminiOutputText.substring(3, geminiOutputText.length - 3).trim();
        }
        
        final commandData = jsonDecode(geminiOutputText);
        _handleCommand(commandData, recognizedText: text);
      } else {
        _speak('AI로부터 유효한 응답을 받지 못했습니다.');
        setState(() {
          _statusMessage = 'AI 응답 없음';
          _isProcessing = false;
        });
      }
    } catch (e) {
      _speak('AI 처리 중 문제가 발생했습니다: $e');
      setState(() {
        _statusMessage = 'AI 처리 오류: $e';
        _isProcessing = false;
      });
    }
  }

  void _handleCommand(Map<String, dynamic> data, {required String recognizedText}) {
    final action = data['action'];
    final message = data['message'] ?? ''; // Gemini 응답에 message 필드가 있다면 사용
    final String ttsMessage;

    setState(() {
      _isProcessing = false;
      _recognizedText = recognizedText; // STT로 인식된 원본 텍스트
    });

    if (message.isNotEmpty) {
      ttsMessage = message;
    } else {
      switch (action) {
        case 'EMERGENCY_STOP':
          ttsMessage = '비상 정지 명령을 수행합니다.';
          break;
        case 'NAVIGATE':
          final target = data['target'];
          String targetName = '';
          if (target == 'connection') {
            targetName = '기기 연결';
          } else if (target == 'mapping') {
            targetName = '사진 매핑';
          } else if (target == 'settings') {
            targetName = '설정';
          }
          ttsMessage = '$targetName 화면으로 이동합니다.';
          break;
        case 'MICROWAVE_CONTROL':
          final commands = data['commands'] as List<dynamic>?;
          if (commands != null && commands.isNotEmpty) {
            ttsMessage = '전자레인지 ${commands.join(" 그리고 ")} 명령을 수행합니다.';
          } else {
            ttsMessage = '전자레인지 제어 명령을 이해하지 못했습니다.';
          }
          break;
        case 'NONE':
        default:
          ttsMessage = '명령을 이해하지 못했습니다. 다시 말씀해 주세요.';
          break;
      }
    }
    _speak(ttsMessage);

    switch (action) {
      case 'EMERGENCY_STOP':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyStopScreen()),
        );
        break;
      case 'NAVIGATE':
        final target = data['target'];
        Widget? screen;
        if (target == 'connection') screen = const DeviceConnectScreen();
        if (target == 'mapping') screen = const PhotoMappingScreen();
        if (target == 'settings') screen = const SettingsScreen();
        
        if (screen != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
        } else {
          _speak('요청하신 화면으로 이동할 수 없습니다.');
        }
        break;
      case 'MICROWAVE_CONTROL':
        final commands = data['commands'] as List<dynamic>?;
        if (commands != null && commands.isNotEmpty) {
          setState(() {
            _statusMessage = '명령 수행 중: ${commands.join(" → ")}';
          });
          _showMicrowaveAction(commands.cast<String>());
        }
        break;
      case 'NONE':
      default:
        setState(() => _statusMessage = '다시 말씀해 주세요.');
        break;
    }
  }

  void _showMicrowaveAction(List<String> commands) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('전자레인지 조작: ${commands.join(" → ")}'),
        backgroundColor: const Color(0xFFFFEB00),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.black,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _recordingTimeoutTimer?.cancel();
    _actionResetTimer?.cancel();
    _speech.stop(); // SpeechToText 리소스 해제
    _speech.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final screenH = MediaQuery.sizeOf(context).height;

    // 화면 높이 기준으로 파형·버튼 크기 결정 (macOS/태블릿/폰 모두 대응)
    final waveH = (screenH * 0.11).clamp(48.0, 100.0);
    final btnSize = (screenH * 0.15).clamp(80.0, 130.0);
    final btnIconSize = btnSize * 0.42;

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

              // 콘텐츠 영역 — Spacer로 여백 분배해 오버플로우 방지
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Spacer(flex: 2),

                      // 상태 메시지
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _isRecording
                              ? const Color(0xFFFFEB00)
                              : Colors.white,
                          fontSize: 20 * rs,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
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

                      const Spacer(flex: 2),

                      // 메인 녹음 버튼
                      Semantics(
                        label: _isRecording
                            ? (_micArmed
                                ? '음성 녹음 중지 버튼 선택됨. 한 번 더 탭하면 중지됩니다.'
                                : '음성 녹음 중지 버튼')
                            : (_micArmed
                                ? '음성 명령 시작 버튼 선택됨. 한 번 더 탭하면 녹음이 시작됩니다.'
                                : '음성 명령 시작 버튼'),
                        button: true,
                        child: GestureDetector(
                          onTap: _isProcessing ? null : _handleMicTap,
                          child: Container(
                            width: btnSize,
                            height: btnSize,
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? const Color(0xFF2A2A2A)
                                  : const Color(0xFFFFEB00),
                              shape: BoxShape.circle,
                              border: _isRecording
                                  ? Border.all(
                                      color: _micArmed
                                          ? Colors.white
                                          : const Color(0xFFFFEB00),
                                      width: _micArmed ? 5 : 4,
                                    )
                                  : (_micArmed
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 4,
                                        )
                                      : null),
                              boxShadow: [
                                BoxShadow(
                                  color: _isRecording
                                      ? const Color(0x66FFEB00)
                                      : Colors.black45,
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isProcessing
                                  ? Icons.sync
                                  : (_isRecording ? Icons.stop : Icons.mic),
                              color: _isRecording
                                  ? const Color(0xFFFFEB00)
                                  : Colors.black,
                              size: btnIconSize,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),

                      // 인식된 결과 텍스트 박스
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF2A2A2A)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              '인식 결과',
                              style: TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _recognizedText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16 * rs,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

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
