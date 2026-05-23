import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../widgets/responsive_scale.dart';
import 'stop_done_screen.dart';

class EmergencyStopScreen extends StatefulWidget {
  const EmergencyStopScreen({super.key, this.initialSeconds = 150});

  final int initialSeconds;

  @override
  State<EmergencyStopScreen> createState() => _EmergencyStopScreenState();
}

class _EmergencyStopScreenState extends State<EmergencyStopScreen>
    with SingleTickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();

  late final AnimationController _holdController;
  Timer? _countdownTimer;

  late int _secondsLeft;
  bool _isHolding = false;
  bool _isListening = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.initialSeconds;
    _holdController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _onHoldCompleted();
            }
          });

    _startCountdown();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted && _secondsLeft > 0) {
              // Keep listening as long as the timer is running
              _startListening();
            }
          }
        },
      );
      if (_speechEnabled) {
        _startListening();
      }
    } catch (_) {}
  }

  void _startListening() async {
    if (!_speechEnabled || _speech.isListening) return;

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords.toLowerCase();
        if (words.contains('멈춰') ||
            words.contains('정지') ||
            words.contains('그만') ||
            words.contains('중단') ||
            words.contains('stop')) {
          _onHoldCompleted();
        }
      },
      localeId: 'ko_KR',
      listenOptions: SpeechListenOptions(listenMode: ListenMode.deviceDefault),
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 0) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsLeft -= 1;
      });
    });
  }

  String _formatMMSS(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _speak(String message) async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.stop();
    await _tts.speak(message);
  }

  void _onHoldStart() {
    setState(() {
      _isHolding = true;
    });
    HapticFeedback.heavyImpact();
    _holdController.forward(from: 0);
  }

  void _onHoldEnd() {
    if (!_isHolding) {
      return;
    }

    setState(() {
      _isHolding = false;
    });
    _holdController.stop();
    _holdController.reset();
  }

  Future<void> _onHoldCompleted() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isHolding = false;
      _isListening = false;
    });

    _speech.stop();
    _countdownTimer?.cancel();

    HapticFeedback.heavyImpact();
    await _speak('작동이 중단되었습니다.');

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _holdController.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // TopAppBar
                Container(
                  height: ResponsiveScale.v(context, 64),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveScale.v(context, 8),
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFFFEB00)),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Touch Bridge',
                        style: TextStyle(
                          color: Color(0xFFFFEB00),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      // Voice Listening Indicator
                      if (_speechEnabled)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isListening
                                ? const Color(0xFFFFEB00).withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isListening
                                  ? const Color(0xFFFFEB00)
                                  : const Color(0xFF2A2A2A),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.mic_rounded,
                                size: 14,
                                color: _isListening
                                    ? const Color(0xFFFFEB00)
                                    : const Color(0xFF888888),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isListening ? '듣는 중' : '대기 중',
                                style: TextStyle(
                                  color: _isListening
                                      ? const Color(0xFFFFEB00)
                                      : const Color(0xFF888888),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveScale.v(context, 24),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: ResponsiveScale.v(context, 24)),
                        // Status Card
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF2A2A2A),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.microwave_rounded,
                                color: Color(0xFFFFEB00),
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                '스마트 전자레인지 작동 중',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Timer Section
                        const Text(
                          '남은 시간',
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 4)),
                        Text(
                          _formatMMSS(_secondsLeft),
                          style: TextStyle(
                            color: const Color(0xFFFFEB00),
                            fontSize: 84 * rs,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const Spacer(),
                        // Instruction Text
                        Text(
                          '중단하려면 아래 버튼을 3초간 길게 누르세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF888888),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 16)),
                        // Emergency Button Area
                        Column(
                          children: [
                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                height: 6,
                                width: double.infinity,
                                color: const Color(0xFF1A1A1A),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedBuilder(
                                    animation: _holdController,
                                    builder: (context, child) {
                                      return FractionallySizedBox(
                                        widthFactor: _holdController.value,
                                        child: child,
                                      );
                                    },
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFEB00),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveScale.v(context, 16)),
                            GestureDetector(
                              onTap: () {
                                _speak('중단하려면 버튼을 3초간 길게 누르세요.');
                              },
                              onLongPressStart: (_) => _onHoldStart(),
                              onLongPressEnd: (_) => _onHoldEnd(),
                              onLongPressCancel: _onHoldEnd,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: double.infinity,
                                height: ResponsiveScale.v(context, 200),
                                decoration: BoxDecoration(
                                  color: _isHolding
                                      ? const Color(0xFFFF4444)
                                      : const Color(0xFF1A0A0A),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: _isHolding
                                        ? Colors.white
                                        : const Color(0xFFFF4444),
                                    width: _isHolding ? 4 : 2,
                                  ),
                                  boxShadow: [
                                    if (_isHolding)
                                      BoxShadow(
                                        color: const Color(0xFFFF4444).withValues(alpha: 0.3),
                                        blurRadius: 30,
                                        spreadRadius: 5,
                                      ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.stop_circle_rounded,
                                      size: 72 * rs,
                                      color: _isHolding ? Colors.white : const Color(0xFFFF4444),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '길게 눌러서 중단',
                                      style: TextStyle(
                                        color: _isHolding ? Colors.white : const Color(0xFFFF4444),
                                        fontSize: 28 * rs,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '3초간 유지하세요',
                                      style: TextStyle(
                                        color: _isHolding ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF884444),
                                        fontSize: 14 * rs,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 32)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
