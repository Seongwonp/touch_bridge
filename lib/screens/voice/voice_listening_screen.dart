import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../widgets/responsive_scale.dart';

class VoiceListeningScreen extends StatefulWidget {
  const VoiceListeningScreen({super.key});

  @override
  State<VoiceListeningScreen> createState() => _VoiceListeningScreenState();
}

class _VoiceListeningScreenState extends State<VoiceListeningScreen> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final math.Random _random = math.Random();

  bool _isSpeechReady = false;
  bool _isListening = false;
  String _statusMessage = '말씀해 주세요. 듣고 있습니다.';
  String _recognizedText = '아직 인식된 음성이 없어요.';

  Timer? _waveTimer;
  Timer? _actionResetTimer;
  String? _armedActionId;

  List<double> _waveHeights = const [
    0.20, 0.50, 0.80, 1.00, 0.60, 0.30, 1.00, 0.50, 0.70, 0.80, 0.20,
  ];

  final List<String> _quickCommands = const [
    '거실 불 켜줘',
    '내일 오전 7시 알람',
    '오늘 날씨 어때?',
    '에어컨 24도로 설정',
    '음악 틀어줘',
  ];

  @override
  void initState() {
    super.initState();
    _initializeVoiceFeatures();
  }

  Future<void> _initializeVoiceFeatures() async {
    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.45);
      final bool available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _statusMessage = '상태: $status';
              if (status == 'notListening' || status == 'done') _isListening = false;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _statusMessage = '오류: ${error.errorMsg}';
              _isListening = false;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isSpeechReady = available;
          _statusMessage = available ? '말씀해 주세요. 듣고 있습니다.' : '음성 인식을 사용할 수 없어요.';
        });
      }
    } catch (_) {}
  }

  Future<void> _speak(String message) async {
    await _tts.stop();
    await _tts.speak(message);
  }

  void _startWaveAnimation() {
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted && _isListening) {
        setState(() {
          _waveHeights = List<double>.generate(
            _waveHeights.length,
            (index) => 0.18 + _random.nextDouble() * 0.82,
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

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      _stopWaveAnimation();
    } else {
      if (!_isSpeechReady) return;
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => _recognizedText = result.recognizedWords);
          }
        },
        localeId: 'ko_KR',
      );
      setState(() => _isListening = true);
      _startWaveAnimation();
    }
  }

  Future<void> _armAndRun({
    required String id,
    required String guide,
    required VoidCallback onConfirmed,
  }) async {
    if (_armedActionId != id) {
      setState(() => _armedActionId = id);
      HapticFeedback.mediumImpact();
      _actionResetTimer?.cancel();
      _actionResetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _armedActionId = null);
      });
      await _speak(guide);
    } else {
      _actionResetTimer?.cancel();
      setState(() => _armedActionId = null);
      onConfirmed();
    }
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _actionResetTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final bool armed = _armedActionId == 'toggle';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: const Row(
                children: [
                  Text(
                    'Touch Bridge',
                    style: TextStyle(
                      color: Color(0xFFFFEB00),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '음성 인식',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28 * rs,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: const Color(0xFF888888),
                        fontSize: 14 * rs,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 인식된 텍스트 박스
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Text(
                        _recognizedText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18 * rs,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // 파형
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _waveHeights.map((h) => AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        width: 7,
                        height: 80 * h,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: _isListening
                              ? const Color(0xFFFFEB00)
                              : const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 36),

                    // 메인 버튼
                    GestureDetector(
                      onTap: () => _armAndRun(
                        id: 'toggle',
                        guide: _isListening ? '듣기를 멈춥니다.' : '듣기를 시작합니다.',
                        onConfirmed: _toggleListening,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 72,
                        decoration: BoxDecoration(
                          color: _isListening
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFFFFEB00),
                          borderRadius: BorderRadius.circular(16),
                          border: armed
                              ? Border.all(color: Colors.white, width: 2.5)
                              : _isListening
                                  ? Border.all(color: const Color(0xFFFFEB00), width: 2)
                                  : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isListening ? Icons.mic_off_rounded : Icons.mic_rounded,
                              color: _isListening
                                  ? const Color(0xFFFFEB00)
                                  : Colors.black,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isListening ? '듣기 멈추기' : '듣기 시작',
                              style: TextStyle(
                                fontSize: 20 * rs,
                                fontWeight: FontWeight.w800,
                                color: _isListening
                                    ? const Color(0xFFFFEB00)
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 빠른 명령
                    const Text(
                      '빠른 명령',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickCommands.map((cmd) {
                        return GestureDetector(
                          onTap: () => setState(() => _recognizedText = cmd),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF2A2A2A)),
                            ),
                            child: Text(
                              cmd,
                              style: const TextStyle(
                                color: Color(0xFFCCCCCC),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
