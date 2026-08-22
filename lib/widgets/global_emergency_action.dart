import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/safety/stop_done_screen.dart';
import '../services/accessibility_settings.dart';
import '../services/emergency_stop_service.dart';
import '../services/feedback_service.dart';
import '../services/tts_service.dart';
import '../theme/app_colors.dart';

/// 모든 화면의 상단 앱바에 상주하는 전역 비상 정지 버튼.
///
/// 배경: 비상 탭은 메인 내비게이션에만 있어, 이미지 제어·숫자 패드·간편 코스
/// 같은 push된 화면에서 기기를 멈추려면 "뒤로가기 → 비상 탭 이중 탭 → 비상 버튼
/// 이중 탭"의 다단계가 필요했다. 이 버튼으로 **어떤 화면에서든 두 번 탭이면
/// 즉시 중단**이 가능하다.
///
/// 패턴은 다른 비상 버튼과 동일: 첫 탭 안내(arm) → 20초 내 둘째 탭 실행.
/// 모든 발화는 emergency 우선순위 — 스크린리더 활성 시에도 반드시 들린다.
class GlobalEmergencyAction extends StatefulWidget {
  const GlobalEmergencyAction({super.key});

  @override
  State<GlobalEmergencyAction> createState() => _GlobalEmergencyActionState();
}

class _GlobalEmergencyActionState extends State<GlobalEmergencyAction>
    with WidgetsBindingObserver {
  final TtsService _tts = TtsService();
  Timer? _armTimer;
  bool _armed = false;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드 전환 시 armed 해제 — 복귀 후 의도치 않은 한 번 탭 실행 방지.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _armTimer?.cancel();
      if (mounted && _armed) setState(() => _armed = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _armTimer?.cancel();
    _tts.cancelSource('GlobalEmergencyAction');
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_stopping) return;

    if (!_armed) {
      setState(() => _armed = true);
      HapticFeedback.heavyImpact();
      _armTimer?.cancel();
      _armTimer = Timer(kDoubleTapArmTimeout, () {
        if (mounted) setState(() => _armed = false);
      });
      await _tts.speak(
        '비상 정지 버튼입니다. 한 번 더 누르면 현재 기기를 즉시 중단합니다.',
        source: 'GlobalEmergencyAction',
        priority: TtsPriority.emergency,
        interrupt: true,
      );
      return;
    }

    _armTimer?.cancel();
    setState(() {
      _armed = false;
      _stopping = true;
    });
    FeedbackService.instance.vibrateError();
    await _tts.speak(
      '즉시 중단합니다.',
      source: 'GlobalEmergencyAction',
      priority: TtsPriority.emergency,
      interrupt: true,
    );

    final outcome = await EmergencyStopService.instance.stopActiveDevice();
    if (outcome.acknowledged) {
      FeedbackService.instance.playSuccess();
    } else {
      FeedbackService.instance.playFailure();
    }
    await _tts.speak(
      outcome.message,
      source: 'GlobalEmergencyAction',
      priority: TtsPriority.emergency,
      interrupt: true,
    );

    if (!mounted) return;
    setState(() => _stopping = false);
    if (outcome.acknowledged) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '비상 정지',
      hint: _armed ? '한 번 더 누르면 즉시 중단합니다' : '한 번 누르면 안내, 두 번 누르면 즉시 중단',
      value: _armed ? '실행 대기 중' : null,
      liveRegion: _armed,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          // 최소 터치 타겟 48dp 보장 (WCAG 2.5.8).
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _armed ? AppColors.emergency : Colors.transparent,
            border: Border.all(
              color: _armed ? Colors.white : AppColors.emergency,
              width: _armed ? 2.5 : 1.5,
            ),
          ),
          child: _stopping
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                )
              : Icon(
                  Icons.back_hand,
                  size: 24,
                  color: _armed ? Colors.white : AppColors.emergency,
                ),
        ),
      ),
    );
  }
}
