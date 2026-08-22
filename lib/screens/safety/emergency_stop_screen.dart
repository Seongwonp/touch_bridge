import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/emergency_intent.dart';
import '../../services/emergency_stop_service.dart';
import '../../services/feedback_service.dart';
import '../../services/speech_session_service.dart';
import '../../services/timer_service.dart';
import '../../services/tts_service.dart';
import '../../services/accessibility_experiment_service.dart';

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
  // 공용 STT 세션: 화면별 SpeechToText 개별 초기화는 패키지 싱글톤 특성상
  // 콜백이 최초 1회만 등록돼 "멈춰" 재청취 루프가 조용히 죽는 문제가 있었다.
  final SpeechSessionService _speechSession = SpeechSessionService.instance;

  late final AnimationController _holdController;
  final CountdownService _timerService = CountdownService();

  late int _secondsLeft;
  bool _isHolding = false;
  bool _speechEnabled = false;
  bool _isStartingListening = false;
  bool _stopInProgress = false;

  // 구간 TTS: 동일 구간이 두 번 울리지 않도록 한 번 발화한 초를 기록한다.
  final Set<int> _announcedMilestones = {};

  // 홀드 중 1초 간격 햅틱 — 진행 상황을 촉각으로 전달한다 (VUI 연구 권고).
  Timer? _holdHapticTimer;

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
    // 이 화면이 스택 최상단인 동안만 이벤트를 받는다(공용 세션의 스택 구조).
    _speechSession.attach(
      SpeechClient(
        name: 'EmergencyStopScreen',
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted && _secondsLeft > 0) _startListening();
          }
        },
        onError: (_) {
          if (mounted) setState(() => _speechEnabled = false);
        },
      ),
    );
    try {
      _speechEnabled = await _speechSession.initialize();
      if (_speechEnabled) _startListening();
    } catch (_) {}
  }

  void _startListening() async {
    if (!_speechEnabled ||
        _speechSession.isListening ||
        _isStartingListening) {
      return;
    }
    _isStartingListening = true;
    try {
      await _speechSession.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (EmergencyIntent.matches(words)) {
            _onHoldCompleted();
          }
        },
      );
    } catch (_) {
      // ignore
    } finally {
      _isStartingListening = false;
    }
  }

  void _maybeAnnounceMilestone(int seconds) {
    const milestones = {300, 120, 60, 30, 10, 5, 3};
    if (!milestones.contains(seconds)) return;
    if (_announcedMilestones.contains(seconds)) return;
    _announcedMilestones.add(seconds);
    final msg = seconds >= 60 ? '${seconds ~/ 60}분 남았습니다.' : '$seconds초 남았습니다.';
    // 카운트다운 구간 안내는 스크린리더가 자동으로 읽어주지 않는 상태 변화이므로
    // result 우선순위로 스크린리더 활성 시에도 들려준다.
    _speak(msg, priority: TtsPriority.result);
  }

  void _startCountdown() {
    _timerService.start(
      _secondsLeft,
      onTick: (seconds) {
        if (mounted) {
          setState(() => _secondsLeft = seconds);
          _maybeAnnounceMilestone(seconds);
        }
      },
      onFinished: () {
        if (mounted) {
          AccessibilityExperimentService.instance.recordTaskCompleted();

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
    String source = 'EmergencyStopScreen',
    bool interrupt = false,
    TtsPriority priority = TtsPriority.navigation,
  }) async {
    await _tts.speak(
      message,
      source: source,
      interrupt: interrupt,
      priority: priority,
    );
  }

  void _onHoldStart() {
    setState(() => _isHolding = true);
    HapticFeedback.heavyImpact();
    _holdController.forward(from: 0);
    _speak('멈추는 중입니다. 그대로 눌러주세요.', priority: TtsPriority.result);
    _holdHapticTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isHolding) HapticFeedback.mediumImpact();
    });
  }

  void _onHoldEnd() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    _holdHapticTimer?.cancel();
    _holdController.stop();
    _holdController.reset();
  }

  Future<void> _onHoldCompleted() async {
    if (!mounted || _stopInProgress) return;
    _stopInProgress = true;
    setState(() {
      _isHolding = false;
    });
    _speechSession.stop();
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
    // 정지 성공/미확인/실패 결과는 안전 정보이므로 스크린리더 활성 시에도
    // 반드시 들려야 한다 — emergency 우선순위 명시.
    await _speak(
      outcome.message,
      interrupt: true,
      priority: TtsPriority.emergency,
    );

    if (!mounted) return;
    if (outcome.acknowledged) {
      // 기기 정지가 확인된 경우에만 "안전하게 중단" 완료 화면으로 이동한다.
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()));
    } else {
      // 전송만 됐거나 실패한 경우: 완료 화면으로 넘기지 않고 재시도할 수 있게 둔다.
      _stopInProgress = false;
      // 정지 실패 시 음성 감지를 즉시 재시작해 "멈춰" 재시도를 받을 수 있게 한다.
      if (mounted && _speechEnabled) _startListening();
    }
  }

  // 대상 결정 → 재연결 → STOP 전송 → ACK 해석은 EmergencyStopService가
  // 단일하게 책임진다(과거 3개 화면 복제 로직 통합).
  Future<EmergencyStopOutcome> _sendStop() =>
      EmergencyStopService.instance.stopActiveDevice();

  @override
  void dispose() {
    _timerService.stop();
    _holdHapticTimer?.cancel();
    _holdController.dispose();
    // 이 화면 자신의 대기 항목만 취소한다. 화면 전환 후 다음 화면의 안내를
    // 날리지 않기 위해 stop() 대신 cancelSource를 쓴다.
    _tts.cancelSource('EmergencyStopScreen');
    // 공용 세션 스택에서 빠져 이전 화면이 STT 이벤트를 이어받게 한다.
    _speechSession.detach('EmergencyStopScreen');
    _speechSession.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      appBar: TopAppBar(
        title: '${widget.deviceName} 작동 중',
        showBack: true,
        // 화면 중앙에 전용 비상 정지 버튼이 있으므로 앱바 중복 노출은 끈다.
        showEmergency: false,
      ),
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
                Semantics(
                  label: '남은 시간',
                  value: _formatMMSS(_secondsLeft),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ExcludeSemantics(
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
