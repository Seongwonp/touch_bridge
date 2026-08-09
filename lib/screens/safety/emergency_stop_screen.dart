import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/active_device_service.dart';
import '../../services/ble_service.dart';
import '../../services/emergency_intent.dart';
import '../../services/feedback_service.dart';
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
  bool _speechEnabled = false;
  bool _isStartingListening = false;
  bool _stopInProgress = false;
  // 완료/중단 화면으로 넘어갈 때는 dispose에서 TTS를 끊지 않는다
  // (다음 화면의 안내가 "작동이..."처럼 잘리는 문제 방지).
  bool _keepTtsOnDispose = false;

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
    _speak('${widget.deviceName} 작동 중입니다. 중단하려면 아래 버튼을 3초간 누르세요.');
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
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (EmergencyIntent.matches(words)) {
            _onHoldCompleted();
          }
        },
        listenOptions: SpeechListenOptions(localeId: 'ko_KR'),
      );
    } catch (_) {
      // ignore
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
          _keepTtsOnDispose = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const StopDoneScreen(completed: true),
            ),
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

  Future<void> _speak(
    String message, {
    String source = 'emergencystopScreen',
    bool interrupt = false,
  }) async {
    await _tts.speak(message, source: source, interrupt: interrupt);
  }

  void _onHoldStart() {
    setState(() => _isHolding = true);
    HapticFeedback.heavyImpact();
    _holdController.forward(from: 0);
    _speak('멈추는 중입니다. 그대로 눌러주세요.');
  }

  void _onHoldEnd() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    _holdController.stop();
    _holdController.reset();
  }

  Future<void> _onHoldCompleted() async {
    if (!mounted || _stopInProgress) return;
    _stopInProgress = true;
    setState(() {
      _isHolding = false;
    });
    _speech.stop();
    _timerService.stop();
    await AccessibilityExperimentService.instance.recordEmergencyStop();
    HapticFeedback.heavyImpact();

    // 실제 하드웨어로 중단 명령을 보내고, 확인 결과를 정직하게 안내한다.
    // (이전 구현은 아무 명령도 보내지 않고 "멈췄습니다"라고만 말했다.)
    final outcome = await _sendStop();
    if (outcome.acknowledged) {
      FeedbackService.instance.playSuccess();
    } else {
      FeedbackService.instance.playFailure();
    }
    await _speak(outcome.message, interrupt: true);

    if (!mounted) return;
    if (outcome.acknowledged) {
      // 기기 정지가 확인된 경우에만 "안전하게 중단" 완료 화면으로 이동한다.
      _keepTtsOnDispose = true;
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()));
    } else {
      // 전송만 됐거나 실패한 경우: 완료 화면으로 넘기지 않고 재시도할 수 있게 둔다.
      _stopInProgress = false;
    }
  }

  Future<EmergencyStopOutcome> _sendStop() async {
    final connectedId = BleService.instance.connectedDeviceId;
    final targetId = connectedId.isNotEmpty
        ? connectedId
        : (ActiveDeviceService.instance.getActiveBleId() ?? '');
    if (targetId.isEmpty) {
      return const EmergencyStopOutcome(
        acknowledged: false,
        sent: false,
        message: '연결된 기기가 없습니다. 기기 전원을 확인해 주세요.',
      );
    }
    if (!BleService.instance.isConnected) {
      await BleService.instance.ensureConnected(targetId);
    }
    final ack = await BleService.instance.sendEmergencyStop(targetId);
    return EmergencyStopOutcome.fromAck(ack);
  }

  @override
  void dispose() {
    _timerService.stop();
    _holdController.dispose();
    if (!_keepTtsOnDispose) _tts.stop();
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
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(24 * rs),
            child: Column(
              children: [
                SizedBox(height: 20 * rs),
                Text(
                  '남은 시간',
                  style: TextStyle(
                    color: const Color(0xFFCEC6AD),
                    fontSize: 18 * rs,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(height: ResponsiveScale.v(context, 8)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatMMSS(_secondsLeft),
                    style: TextStyle(
                      color: const Color(0xFFFDE047),
                      fontSize: 90 * rs,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                ),
                SizedBox(height: 24 * rs),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * rs,
                    vertical: 18 * rs,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x660D1C32),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF27354C)),
                  ),
                  child: Text(
                    '중단하려면 아래 버튼을 3초간 누르세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFD6E3FF),
                      fontSize: 16 * rs,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveScale.v(context, 20)),
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 8 * rs,
                        width: double.infinity,
                        color: const Color(0xFF27354C),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedBuilder(
                            animation: _holdController,
                            builder: (context, child) => FractionallySizedBox(
                              widthFactor: _holdController.value,
                              child: child,
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFFDE047),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    Semantics(
                      button: true,
                      label: '비상 정지',
                      hint: '길게 눌러 기기를 즉시 중단합니다',
                      onLongPress: _onHoldCompleted,
                      child: GestureDetector(
                        onLongPressStart: (_) => _onHoldStart(),
                        onLongPressEnd: (_) => _onHoldEnd(),
                        onLongPressCancel: _onHoldEnd,
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            minHeight: 160 * rs,
                            maxHeight: 220 * rs,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5252), Color(0xFF93000A)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(32 * rs),
                            border: Border.all(
                              color: _isHolding
                                  ? Colors.white
                                  : const Color(0xFFFFB4AB),
                              width: 4 * rs,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.back_hand,
                                size: 70 * rs,
                                color: Colors.white,
                              ),
                              SizedBox(height: 8 * rs),
                              Text(
                                '길게 눌러 중단',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28 * rs,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20 * rs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
