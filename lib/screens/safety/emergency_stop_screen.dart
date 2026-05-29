import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/timer_service.dart';
import '../../services/tts_service.dart';
import '../../services/accessibility_experiment_service.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
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
    _speak('${widget.deviceName} 작동 중입니다. 중단하려면 버튼을 길게 누르세요.');
  }

  Future<void> _initSpeech() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) return;
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted && _secondsLeft > 0) _startListening();
          }
        },
        onError: (errorNotification) {
          if (mounted) setState(() => _speechEnabled = false);
        },
      );
      if (_speechEnabled) _startListening();
    } catch (_) {}
  }

  void _startListening() async {
    if (!_speechEnabled || _speech.isListening || _isStartingListening) return;
    _isStartingListening = true;
    try {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.toLowerCase();
          if (words.contains('멈춰') || words.contains('정지') || words.contains('stop')) {
            _onHoldCompleted();
          }
        },
        localeId: 'ko_KR',
      );
    } catch (_) {
      if (mounted) setState(() => _isListening = false);
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
        }
      },
      onFinished: () {
        if (mounted) {
          AccessibilityExperimentService.instance.recordTaskCompleted();
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

  Future<void> _speak(String message) async {
    await _tts.speak(message);
  }

  void _onHoldStart() {
    setState(() => _isHolding = true);
    HapticFeedback.heavyImpact();
    _holdController.forward(from: 0);
    _speak('중지 버튼 누름');
  }

  void _onHoldEnd() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    _holdController.stop();
    _holdController.reset();
  }

  Future<void> _onHoldCompleted() async {
    if (!mounted) return;
    setState(() { _isHolding = false; _isListening = false; });
    _speech.stop();
    _timerService.stop();
    await AccessibilityExperimentService.instance.recordEmergencyStop();
    HapticFeedback.heavyImpact();
    await _speak('작동 중단.');
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()));
  }

  @override
  void dispose() {
    _timerService.stop();
    _holdController.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      appBar: TopAppBar(title: '${widget.deviceName} 작동 중', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24 * rs),
          child: Column(
            children: [
              const Spacer(),
              Text('남은 시간', style: TextStyle(color: const Color(0xFFCEC6AD), fontSize: 18 * rs, fontWeight: FontWeight.bold, letterSpacing: 4)),
              SizedBox(height: ResponsiveScale.v(context, 8)),
              Text(
                _formatMMSS(_secondsLeft),
                style: TextStyle(color: const Color(0xFFFDE047), fontSize: 90 * rs, fontWeight: FontWeight.w900, letterSpacing: -2),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 20 * rs, vertical: 18 * rs),
                decoration: BoxDecoration(color: const Color(0x660D1C32), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFF27354C))),
                child: Text('중단하려면 아래 버튼을 3초간 누르세요', textAlign: TextAlign.center, style: TextStyle(color: const Color(0xFFD6E3FF), fontSize: 16 * rs, fontWeight: FontWeight.w700)),
              ),
              SizedBox(height: ResponsiveScale.v(context, 20)),
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 8 * rs, width: double.infinity, color: const Color(0xFF27354C),
                      child: Align(alignment: Alignment.centerLeft, child: AnimatedBuilder(
                        animation: _holdController,
                        builder: (context, child) => FractionallySizedBox(widthFactor: _holdController.value, child: child),
                        child: Container(decoration: const BoxDecoration(color: Color(0xFFFDE047))),
                      )),
                    ),
                  ),
                  SizedBox(height: ResponsiveScale.v(context, 16)),
                  GestureDetector(
                    onLongPressStart: (_) => _onHoldStart(),
                    onLongPressEnd: (_) => _onHoldEnd(),
                    onLongPressCancel: _onHoldEnd,
                    child: Container(
                      width: double.infinity,
                      height: ResponsiveScale.v(context, 200),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF5252), Color(0xFF93000A)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(32 * rs),
                        border: Border.all(color: _isHolding ? Colors.white : const Color(0xFFFFB4AB), width: 4 * rs),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.back_hand, size: 80 * rs, color: Colors.white),
                          Text('길게 눌러 중단', style: TextStyle(color: Colors.white, fontSize: 32 * rs, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
