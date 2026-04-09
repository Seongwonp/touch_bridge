import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../widgets/responsive_scale.dart';
import 'stop_done_screen.dart';

class EmergencyStopScreen extends StatefulWidget {
  const EmergencyStopScreen({super.key});

  @override
  State<EmergencyStopScreen> createState() => _EmergencyStopScreenState();
}

class _EmergencyStopScreenState extends State<EmergencyStopScreen>
    with SingleTickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();

  late final AnimationController _holdController;
  Timer? _countdownTimer;

  int _secondsLeft = 150;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _holdController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _onHoldCompleted();
            }
          });

    _startCountdown();
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
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      body: Stack(
        children: [
          Positioned(
            top: ResponsiveScale.v(context, 120),
            right: -ResponsiveScale.v(context, 120),
            child: IgnorePointer(
              child: Container(
                width: ResponsiveScale.v(context, 380),
                height: ResponsiveScale.v(context, 380),
                decoration: BoxDecoration(
                  color: const Color(0x1AFDE047),
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
                  color: const Color(0x1AFFB4AB),
                  borderRadius: BorderRadius.circular(160),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  height: ResponsiveScale.v(context, 64),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveScale.v(context, 16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu,
                        color: Color(0xFFFDE047),
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Touch Bridge',
                        style: TextStyle(
                          color: Color(0xFFFDE047),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Container(
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
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveScale.v(context, 20),
                      ResponsiveScale.v(context, 8),
                      ResponsiveScale.v(context, 20),
                      ResponsiveScale.v(context, 12),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2A41),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFFDE047),
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 10,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.microwave,
                                color: Color(0xFFFDE047),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '전자레인지 30초 작동 중',
                                style: TextStyle(
                                  color: Color(0xFFFDE047),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '남은 시간',
                          style: TextStyle(
                            color: Color(0xFFCEC6AD),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 8)),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatMMSS(_secondsLeft),
                              // 7rem equivalent target while preventing overflow on small widths.
                              style: TextStyle(
                                color: Color(0xFFFDE047),
                                fontSize: 112 * rs,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: -2,
                                shadows: [
                                  Shadow(
                                    color: Color(0x66FDE047),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x80112D4D),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFF4B4734)),
                          ),
                          child: const Text(
                            '중단하려면 아래 버튼을 3초간 길게 누르세요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFD6E3FF),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 14)),
                        AnimatedBuilder(
                          animation: _holdController,
                          builder: (context, _) {
                            return Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    height: 6,
                                    width: double.infinity,
                                    color: const Color(0xFF27354C),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: _holdController.value,
                                        child: Container(
                                          color: const Color(0xFFFDE047),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: ResponsiveScale.v(context, 12),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _speak('중단하려면 버튼을 3초간 길게 누르세요.');
                                  },
                                  onLongPressStart: (_) => _onHoldStart(),
                                  onLongPressEnd: (_) => _onHoldEnd(),
                                  onLongPressCancel: _onHoldEnd,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    width: double.infinity,
                                    height: ResponsiveScale.v(context, 220),
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
                                        width: _isHolding ? 5 : 4,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x6693000A),
                                          blurRadius: 30,
                                          offset: Offset(0, 16),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(40),
                                                border: Border.all(
                                                  color: const Color(
                                                    0x12FFFFFF,
                                                  ),
                                                  width: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.back_hand,
                                                size: 86 * rs,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                '길게 눌러서 중단',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 34 * rs,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -1,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'HOLD FOR 3 SEC',
                                                style: TextStyle(
                                                  color: Color(0xFFFFDAD6),
                                                  fontSize: 18 * rs,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
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
