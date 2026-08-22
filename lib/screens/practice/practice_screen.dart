import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/accessibility_settings.dart';
import '../../services/appliance_command_router.dart';
import '../../services/feedback_service.dart';
import '../../services/microwave_command_service.dart';
import '../../services/speech_session_service.dart';
import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';

/// 연습 모드 — 하드웨어·백엔드 없이 조작 방법을 안전하게 익히는 화면.
///
/// 시각장애인 사용자가 실제 가전 앞에서 처음 배우면 실수가 곧 오작동이다.
/// 이 화면에서는 아무것도 실제로 전송되지 않으며(BLE/AI 미사용),
/// 세 가지 핵심 조작을 반복 연습할 수 있다:
/// 1. 이중 탭 확인 (첫 탭 안내 → 둘째 탭 실행)
/// 2. 비상 정지 3초 홀드
/// 3. 음성 명령 (로컬 규칙만으로 해석 — "30초 시작" 등)
///
/// 시연 관점 보너스: 하드웨어가 없는 발표장에서도 앱의 UX를 그대로 보여주는
/// 플랜 B가 된다 (DEMO_SCRIPT 실패 대응표 참조).
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  final TtsService _tts = TtsService();
  final SpeechSessionService _speechSession = SpeechSessionService.instance;

  // 레슨 1: 이중 탭
  bool _tapArmed = false;
  Timer? _tapArmTimer;
  int _tapSuccessCount = 0;

  // 레슨 2: 3초 홀드
  late final AnimationController _holdController;
  bool _isHolding = false;
  int _holdSuccessCount = 0;

  // 레슨 3: 음성 명령
  bool _speechEnabled = false;
  bool _isListening = false;
  String _voiceResult = '아직 연습 전이에요.';
  int _voiceSuccessCount = 0;

  @override
  void initState() {
    super.initState();
    _holdController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _onHoldCompleted();
          });
    _initSpeech();
    _tts.speak(
      '연습 모드입니다. 여기서는 아무것도 실제로 실행되지 않아요. '
      '이중 탭, 비상 정지 홀드, 음성 명령을 마음껏 연습해 보세요.',
      source: 'PracticeScreen',
      interrupt: true,
    );
  }

  Future<void> _initSpeech() async {
    _speechSession.attach(
      SpeechClient(
        name: 'PracticeScreen',
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'listening') {
            setState(() => _isListening = true);
          }
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _isListening = false);
        },
      ),
    );
    final ok = await _speechSession.initialize();
    if (mounted) setState(() => _speechEnabled = ok);
  }

  @override
  void dispose() {
    _tapArmTimer?.cancel();
    _holdController.dispose();
    _speechSession.detach('PracticeScreen');
    _speechSession.stop();
    _tts.cancelSource('PracticeScreen');
    super.dispose();
  }

  // ── 레슨 1: 이중 탭 ──────────────────────────────────────────────────────

  Future<void> _onPracticeTap() async {
    if (!_tapArmed) {
      setState(() => _tapArmed = true);
      HapticFeedback.mediumImpact();
      _tapArmTimer?.cancel();
      _tapArmTimer = Timer(kDoubleTapArmTimeout, () {
        if (!mounted) return;
        setState(() => _tapArmed = false);
        _tts.speak(
          '시간이 지나 자동으로 취소됐어요. 실제 화면에서도 이렇게 20초가 지나면 취소됩니다. 다시 해보세요.',
          source: 'PracticeScreen',
          priority: TtsPriority.result,
        );
      });
      await _tts.speak(
        '연습 시작 버튼입니다. 한 번 더 누르면 실행돼요. 지금처럼 첫 탭은 항상 안내만 합니다.',
        source: 'PracticeScreen',
        priority: TtsPriority.result,
        interrupt: true,
      );
      return;
    }

    _tapArmTimer?.cancel();
    setState(() {
      _tapArmed = false;
      _tapSuccessCount++;
    });
    HapticFeedback.lightImpact();
    FeedbackService.instance.playSuccess();
    await _tts.speak(
      '잘하셨어요! 이중 탭 $_tapSuccessCount번째 성공. 실제 화면에서는 지금 명령이 실행됐을 거예요.',
      source: 'PracticeScreen',
      priority: TtsPriority.result,
      interrupt: true,
    );
  }

  // ── 레슨 2: 3초 홀드 ─────────────────────────────────────────────────────

  void _onHoldStart() {
    setState(() => _isHolding = true);
    HapticFeedback.heavyImpact();
    _holdController.forward(from: 0);
    _tts.speak(
      '누르는 중이에요. 3초간 그대로 유지하세요.',
      source: 'PracticeScreen',
      priority: TtsPriority.result,
      interrupt: true,
    );
  }

  void _onHoldEnd() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    if (_holdController.isAnimating) {
      _holdController.stop();
      _holdController.reset();
      _tts.speak(
        '3초가 되기 전에 손을 뗐어요. 다시 해보세요.',
        source: 'PracticeScreen',
        priority: TtsPriority.result,
      );
    }
  }

  Future<void> _onHoldCompleted() async {
    if (!mounted) return;
    setState(() {
      _isHolding = false;
      _holdSuccessCount++;
    });
    _holdController.reset();
    HapticFeedback.heavyImpact();
    FeedbackService.instance.playSuccess();
    await _tts.speak(
      '잘하셨어요! 비상 정지 홀드 $_holdSuccessCount번째 성공. '
      '실제 상황에서는 지금 기기가 즉시 멈췄을 거예요.',
      source: 'PracticeScreen',
      priority: TtsPriority.result,
      interrupt: true,
    );
  }

  // ── 레슨 3: 음성 명령 (로컬 규칙만) ──────────────────────────────────────

  Future<void> _onVoicePracticeTap() async {
    if (!_speechEnabled) {
      _tts.speak(
        '이 기기에서는 음성 인식을 사용할 수 없어 음성 연습은 건너뛰어요.',
        source: 'PracticeScreen',
        priority: TtsPriority.result,
      );
      return;
    }
    if (_isListening) {
      await _speechSession.stop();
      setState(() => _isListening = false);
      return;
    }

    FeedbackService.instance.playDing();
    await _tts.speak(
      '듣고 있어요. 30초 시작, 이라고 말해보세요.',
      source: 'PracticeScreen',
      priority: TtsPriority.result,
      interrupt: true,
    );
    await _tts.waitUntilIdle();
    if (!mounted) return;

    await _speechSession.listen(
      onResult: (result) {
        if (!result.finalResult || !mounted) return;
        _handleVoicePractice(result.recognizedWords);
      },
    );
    if (mounted) setState(() => _isListening = true);
  }

  Future<void> _handleVoicePractice(String words) async {
    await _speechSession.stop();
    if (!mounted) return;
    setState(() => _isListening = false);

    if (words.trim().isEmpty) {
      setState(() => _voiceResult = '말씀이 들리지 않았어요.');
      await _tts.speak(
        '말씀이 들리지 않았어요. 다시 해보세요.',
        source: 'PracticeScreen',
        priority: TtsPriority.result,
      );
      return;
    }

    // 백엔드 없이 로컬 규칙만으로 해석한다 — 연습은 네트워크에 의존하지 않는다.
    final parsed = ApplianceCommandRouter.checkSimpleRules(
      words,
      deviceName: '전자레인지',
      deviceType: 'microwave',
    );

    final commands = (parsed?['commands'] as List<dynamic>?) ?? const [];
    if (parsed == null || commands.isEmpty) {
      setState(() => _voiceResult = '「$words」 — 이해하지 못했어요.');
      await _tts.speak(
        '$words, 라고 들었지만 이해하지 못했어요. 30초 시작, 1분 시작, 처럼 말해보세요.',
        source: 'PracticeScreen',
        priority: TtsPriority.result,
        interrupt: true,
      );
      return;
    }

    final labels = commands
        .map((c) => MicrowaveCommandService.buttonLabel[c] ?? '$c')
        .join(', ');
    setState(() {
      _voiceSuccessCount++;
      _voiceResult = '「$words」 → $labels';
    });
    FeedbackService.instance.playSuccess();
    await _tts.speak(
      '잘하셨어요! $words, 로 이해했어요. 실제라면 전자레인지의 $labels 버튼을 순서대로 눌렀을 거예요. '
      '연습이라 아무것도 실행되지 않았어요.',
      source: 'PracticeScreen',
      priority: TtsPriority.result,
      interrupt: true,
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: '연습 모드', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20 * rs),
          children: [
            _noticeCard(rs),
            SizedBox(height: 20 * rs),
            _lessonHeader(rs, '1. 이중 탭 연습', '첫 탭은 안내, 둘째 탭이 실행이에요.'),
            SizedBox(height: 10 * rs),
            _practiceTapButton(rs),
            _successBadge(rs, _tapSuccessCount),
            SizedBox(height: 28 * rs),
            _lessonHeader(rs, '2. 비상 정지 연습', '버튼을 3초간 길게 누르세요.'),
            SizedBox(height: 10 * rs),
            _practiceHoldButton(rs),
            _successBadge(rs, _holdSuccessCount),
            SizedBox(height: 28 * rs),
            _lessonHeader(
              rs,
              '3. 음성 명령 연습',
              _speechEnabled ? '"30초 시작"처럼 말해보세요.' : '이 기기에서는 음성 인식을 사용할 수 없어요.',
            ),
            SizedBox(height: 10 * rs),
            _voicePracticeButton(rs),
            SizedBox(height: 8 * rs),
            Semantics(
              liveRegion: true,
              child: Text(
                _voiceResult,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14 * rs,
                ),
              ),
            ),
            _successBadge(rs, _voiceSuccessCount),
            SizedBox(height: 24 * rs),
          ],
        ),
      ),
    );
  }

  Widget _noticeCard(double rs) => Container(
        padding: EdgeInsets.all(14 * rs),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12 * rs),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Text(
          '여기서는 아무것도 실제로 실행되지 않아요.\n실수해도 괜찮으니 마음껏 연습하세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14 * rs,
            height: 1.5,
          ),
        ),
      );

  Widget _lessonHeader(double rs, String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18 * rs,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4 * rs),
          Text(
            subtitle,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13 * rs),
          ),
        ],
      );

  Widget _successBadge(double rs, int count) => Padding(
        padding: EdgeInsets.only(top: 8 * rs),
        child: Semantics(
          liveRegion: true,
          label: '성공 $count번',
          child: ExcludeSemantics(
            child: Text(
              count == 0 ? '아직 성공 전이에요' : '성공 $count번 ✓',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: count == 0 ? AppColors.textTertiary : AppColors.success,
                fontSize: 13 * rs,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );

  Widget _practiceTapButton(double rs) => Semantics(
        button: true,
        label: '연습 시작 버튼',
        value: _tapArmed ? '실행 대기 중' : null,
        hint: _tapArmed ? '한 번 더 누르면 연습 실행' : '한 번 누르면 안내, 두 번 누르면 실행',
        liveRegion: _tapArmed,
        child: InkWell(
          onTap: _onPracticeTap,
          borderRadius: BorderRadius.circular(16 * rs),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 72),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.primaryGradient),
              borderRadius: BorderRadius.circular(16 * rs),
              border: Border.all(
                color: _tapArmed ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                _tapArmed ? '연습 시작 (다시 누르기)' : '연습 시작',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20 * rs,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _practiceHoldButton(double rs) => Semantics(
        button: true,
        label: '비상 정지 연습 버튼',
        hint: '3초간 길게 누르면 연습 성공',
        onLongPress: _onHoldCompleted,
        child: GestureDetector(
          onLongPressStart: (_) => _onHoldStart(),
          onLongPressEnd: (_) => _onHoldEnd(),
          onLongPressCancel: _onHoldEnd,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 6 * rs,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _holdController,
                    builder: (context, _) => LinearProgressIndicator(
                      value: _holdController.value,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.emergency),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8 * rs),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                constraints: const BoxConstraints(minHeight: 84),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.emergency,
                  borderRadius: BorderRadius.circular(16 * rs),
                  border: Border.all(
                    color: _isHolding ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    _isHolding ? '누르는 중...' : '길게 눌러 중단 (연습)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20 * rs,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _voicePracticeButton(double rs) => Semantics(
        button: true,
        label: '음성 연습 버튼',
        hint: _speechEnabled ? '누르면 바로 듣기 시작' : '이 기기에서는 사용할 수 없음',
        child: InkWell(
          onTap: _onVoicePracticeTap,
          borderRadius: BorderRadius.circular(16 * rs),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 72),
            decoration: BoxDecoration(
              color: _speechEnabled
                  ? (_isListening
                      ? AppColors.secondary.withValues(alpha: 0.25)
                      : AppColors.surfaceElevated)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(16 * rs),
              border: Border.all(
                color: _isListening ? AppColors.secondary : AppColors.borderFocus,
                width: _isListening ? 2.5 : 1,
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isListening ? Icons.hearing : Icons.mic,
                    color: _speechEnabled
                        ? AppColors.secondary
                        : AppColors.textTertiary,
                    size: 26 * rs,
                  ),
                  SizedBox(width: 10 * rs),
                  Text(
                    _speechEnabled
                        ? (_isListening ? '듣는 중... (누르면 중지)' : '말하기 연습')
                        : '음성 인식 사용 불가',
                    style: TextStyle(
                      color: _speechEnabled
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontSize: 18 * rs,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
