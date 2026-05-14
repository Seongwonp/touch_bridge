import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/timer_service.dart';
import '../../services/tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../widgets/responsive_scale.dart';
import 'stop_done_screen.dart';

class EmergencyStopScreen extends StatefulWidget {
  const EmergencyStopScreen({
    super.key,
    this.initialSeconds = 150,
    this.deviceName = '기기',
  });

  final int initialSeconds;
  final String deviceName;

  @override
  State<EmergencyStopScreen> createState() => _EmergencyStopScreenState();
}

class _EmergencyStopScreenState extends State<EmergencyStopScreen>
    with SingleTickerProviderStateMixin {
  final TtsService _tts = TtsService();
  final SpeechToText _speech = SpeechToText();

  late final AnimationController _holdController;
  final CountdownService _timerService = CountdownService();

  late int _secondsLeft;
  bool _isHolding = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _isStartingListening = false;

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
    _speak('${widget.deviceName} 작동 중입니다. 남은 시간 ${_formatTime(_secondsLeft)}. 중단하려면 버튼을 길게 누르거나 "멈춰"라고 말하세요.');
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted && _secondsLeft > 0) {
              _startListening();
            }
          }
        },
        onError: (errorNotification) {
          if (mounted) {
            _speak('음성 인식 오류가 발생했습니다: ${errorNotification.errorMsg}');
            setState(() => _speechEnabled = false);
          }
        },
      );
      if (_speechEnabled) {
        _startListening();
      } else {
        _speak('음성 인식을 사용할 수 없습니다. 버튼을 길게 눌러 중단하세요.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EmergencyStop speech init error: $e');
      if (mounted) setState(() => _speechEnabled = false);
    }
  }

  void _startListening() async {
    if (!_speechEnabled || _speech.isListening || _isStartingListening) return;

    _isStartingListening = true;
    try {
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
    } catch (_) {
      if (mounted) {
        setState(() => _isListening = false);
      }
    } finally {
      _isStartingListening = false;
    }
  }

  void _startCountdown() {
    _timerService.start(
      _secondsLeft,
      onTick: (seconds) {
        if (mounted) {
          setState(() => _secondsLeft = seconds);
          // 짧은 타이머: 5초 이하 매초 카운트다운
          if (seconds > 0 && seconds <= 5) {
            _tts.speak('$seconds');
          } else if (seconds > 5 && seconds <= 10 && seconds % 5 == 0) {
            _tts.speak('$seconds초 남았습니다.');
          } else if (seconds > 10 && seconds % 30 == 0) {
            final m = seconds ~/ 60;
            final s = seconds % 60;
            _tts.speak(m > 0 ? '$m분 ${s > 0 ? "$s초 " : ""}남았습니다.' : '$s초 남았습니다.');
          }
        }
      },
      onFinished: () {
        if (mounted) {
          _tts.speak('${widget.deviceName} 작동이 끝났습니다.');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()),
          );
        }
      },
    );
  }

  String _formatMMSS(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    if (m > 0 && s > 0) return '$m분 $s초';
    if (m > 0) return '$m분';
    return '$s초';
  }

  Future<void> _speak(String message) async {
    await _tts.speak(message);
  }

  void _onHoldStart() {
    setState(() {
      _isHolding = true;
    });
    HapticFeedback.heavyImpact();
    _holdController.forward(from: 0);
    _speak('정지 버튼을 길게 누르는 중. 3초 유지.'); // 길게 누르기 시작 TTS
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
    _speak('정지 버튼 누르기 해제.'); // 길게 누르기 해제 TTS
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
    _timerService.stop();

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
    _timerService.stop();
    _holdController.dispose();
    _tts.stop();
    _speech.stop();
    _speech.cancel(); // SpeechToText 리소스 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      body: Stack(
        children: [
          // Background Decoration Glows (Semantics는 필요 없음)
          Positioned(
            top: ResponsiveScale.v(context, 120),
            right: -ResponsiveScale.v(context, 120),
            child: IgnorePointer(
              child: Container(
                width: ResponsiveScale.v(context, 380),
                height: ResponsiveScale.v(context, 380),
                decoration: BoxDecoration(
                  color: const Color(0x33FDE047),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33FDE047),
                      blurRadius: 120,
                      spreadRadius: 20,
                    ),
                  ],
                  borderRadius: BorderRadius.circular(190),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: ResponsiveScale.v(context, 180),
            left: -ResponsiveScale.v(context, 100),
            child: IgnorePointer(
              child: Container(
                width: ResponsiveScale.v(context, 320),
                height: ResponsiveScale.v(context, 320),
                decoration: BoxDecoration(
                  color: const Color(0x33FFB4AB),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33FFB4AB),
                      blurRadius: 100,
                      spreadRadius: 10,
                    ),
                  ],
                  borderRadius: BorderRadius.circular(160),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // TopAppBar
                Container(
                  height: ResponsiveScale.v(context, 64),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveScale.v(context, 24),
                  ),
                  child: Row(
                    children: [
                      Semantics( // 메뉴 아이콘 Semantics 추가
                        label: '메뉴 버튼',
                        button: true,
                        child: const Icon(
                          Icons.menu,
                          color: Color(0xFFFDE047),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Semantics( // 앱 타이틀 Semantics 추가
                        label: 'Touch Bridge 앱',
                        child: const Text(
                          'Touch Bridge',
                          style: TextStyle(
                            color: Color(0xFFFDE047),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Voice Listening Indicator
                      if (_speechEnabled)
                        Semantics( // 음성 듣기 표시기 Semantics 추가
                          label: _isListening ? '음성 명령 듣는 중' : '음성 명령 대기 중',
                          liveRegion: true,
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _isListening
                                  ? const Color(0x33FDE047)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isListening
                                  ? const Color(0xFFFDE047)
                                  : const Color(0x40FDE047),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic,
                                  size: 14,
                                  color: _isListening
                                      ? const Color(0xFFFDE047)
                                      : const Color(0x80FDE047),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isListening ? '듣는 중' : '대기 중',
                                  style: TextStyle(
                                    color: _isListening
                                        ? const Color(0xFFFDE047)
                                        : const Color(0x80FDE047),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Semantics( // 사용자 프로필 아이콘 Semantics 추가
                        label: '사용자 프로필',
                        button: true,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2A41),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFDE047),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFFD6E3FF),
                            size: 22,
                          ),
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
                        SizedBox(height: ResponsiveScale.v(context, 32)),
                        // Status Card
                        Semantics(
                          label: '${widget.deviceName} 작동 중',
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C2A41),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFFDE047),
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.settings_remote_rounded,
                                  color: Color(0xFFFDE047),
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${widget.deviceName} 작동 중',
                                  style: const TextStyle(
                                    color: Color(0xFFFDE047),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Timer Section
                        const Text( // 남은 시간 텍스트는 Semantics로 감싸지 않고, 아래 Text 위젯에 label 추가
                          '남은 시간',
                          style: TextStyle(
                            color: Color(0xFFCEC6AD),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 8)),
                        Semantics( // 남은 시간 표시 Semantics 추가
                          label: '남은 시간 ${_formatMMSS(_secondsLeft).replaceAll(':', '분 ')}초',
                          liveRegion: true, // 시간이 변경될 때마다 자동으로 읽도록 설정
                          child: Text(
                            _formatMMSS(_secondsLeft),
                            style: TextStyle(
                              color: const Color(0xFFFDE047),
                              fontSize: 100 * rs,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              letterSpacing: -4,
                              shadows: const [
                                Shadow(
                                  color: Color(0x66FDE047),
                                  blurRadius: 30,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Instruction Text
                        Semantics( // 지시 텍스트 Semantics 추가
                          label: '중단하려면 아래 버튼을 3초간 길게 누르세요. 또는 "멈춰"라고 말하세요.',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x660D1C32),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFF27354C)),
                            ),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: const TextSpan(
                                style: TextStyle(
                                  color: Color(0xFFD6E3FF),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700, // bold에서 w700으로 변경
                                  height: 1.4,
                                  fontFamily: 'Inter',
                                ),
                                children: [
                                  TextSpan(text: '\'중단하려면 아래 버튼을 '),
                                  TextSpan(
                                    text: '3초간 길게',
                                    style: TextStyle(color: Color(0xFFFDE047)),
                                  ),
                                  TextSpan(text: ' 누르세요\''),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 20)),
                        // Emergency Button Area
                        Column(
                          children: [
                            // Progress Bar (Semantics는 필요 없음)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 8,
                                width: double.infinity,
                                color: const Color(0xFF27354C),
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
                                        color: Color(0xFFFDE047),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0xFFFDE047),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveScale.v(context, 16)),
                            Semantics( // 비상 정지 버튼 Semantics 추가
                              label: '비상 정지 버튼. 3초간 길게 누르거나 "멈춰"라고 말하여 작동을 중단합니다.',
                              button: true,
                              onLongPressHint: '길게 눌러서 작동 중단', // TalkBack/VoiceOver 힌트
                              child: GestureDetector(
                                onTap: () {
                                  _speak('중단하려면 버튼을 3초간 길게 누르세요.');
                                },
                                onLongPressStart: (_) => _onHoldStart(),
                                onLongPressEnd: (_) => _onHoldEnd(),
                                onLongPressCancel: _onHoldEnd,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: double.infinity,
                                  height: ResponsiveScale.v(context, 240),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF5252),
                                        Color(0xFF93000A),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(40),
                                    border: Border.all(
                                      color: _isHolding
                                          ? Colors.white
                                          : const Color(0xFFFFB4AB),
                                      width: _isHolding ? 6 : 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0x9993000A),
                                        blurRadius: _isHolding ? 50 : 30,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Pulse Ring Effect (Static Border for UI recreation)
                                      Container(
                                        margin: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(32),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            width: 16,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.back_hand,
                                            size: 90 * rs,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            '길게 눌러서 중단',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 36 * rs,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'HOLD FOR 3 SEC',
                                            style: TextStyle(
                                              color: const Color(0xFFFFDAD6),
                                              fontSize: 18 * rs,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 3,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_isHolding)
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(40),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 24)),
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
