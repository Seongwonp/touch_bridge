import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';

import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../services/accessibility_settings.dart';
import '../../services/accessibility_confirmation_policy.dart';
import '../../services/app_logger.dart';
import '../../services/power_status_service.dart';
import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';
import '../voice/voice_listening_screen.dart';

/// 비상 정지 완료 화면
/// - 이중 탭 확인 패턴
/// - "홈으로 돌아가기" 버튼 하나만 둔다. 하단 탭을 두면 다른 탭으로 이동해도
///   화면이 바뀌지 않아 음성 안내와 동작이 어긋난다.
/// - 시각장애인 접근성 최우선
/// 끝난 화면의 전원 상태 문장(테스트에서도 같은 문장을 확인한다).
class StopDoneScreenPowerText {
  const StopDoneScreenPowerText._();
  static String of(PowerState state) => _StopDoneScreenState.powerSentence(state);
}

class StopDoneScreen extends StatefulWidget {
  const StopDoneScreen({super.key, this.completed = false});

  /// true면 앱 타이머가 끝난 것, false면 터치브릿지 정지가 확인된 것.
  ///
  /// 타이머 종료는 앱 시간일 뿐 가전이 멈췄다는 확인이 아니고, 정지 확인도 가전의
  /// 취소 버튼을 누른 것은 아니다. 문구가 이 차이를 지킨다.
  final bool completed;

  @override
  State<StopDoneScreen> createState() => _StopDoneScreenState();
}

class _StopDoneScreenState extends State<StopDoneScreen> {
  final TtsService _tts = TtsService();
  bool _armedHomeButton = false;

  /// 전류 센서가 본 가전 전원 상태 문장. 참고 정보일 뿐 완료·안전 판단이 아니다.
  /// 센서 보고가 없으면 앱이 모른다고 솔직히 말하고, 볼 수 없어도 할 수 있는 확인
  /// 방법(종료음)을 알려 준다. 예전에는 "가전이 멈췄는지 확인해 주세요"뿐이라 화면을
  /// 못 보는 사용자는 할 수 없는 일을 요구했다(외부 평가).
  static String powerSentence(PowerState state) {
    switch (state) {
      case PowerState.on:
        return '전류 센서로 보면 가전 전원이 아직 켜져 있습니다.';
      case PowerState.off:
        return '전류 센서로 보면 가전 전원이 꺼졌습니다.';
      case PowerState.unknown:
        return '가전이 멈췄는지는 앱이 확인할 수 없습니다. 가전의 종료음을 들어 보세요.';
    }
  }

  PowerState _power = PowerStatusService.instance.state;

  void _onPower() {
    final now = PowerStatusService.instance.state;
    if (!mounted || now == _power) return;
    final before = _power;
    setState(() => _power = now);
    // 의미가 바뀌는 순간만 한 번씩 알린다. 센서가 끊기면 앞의 판단을 더는 쓸 수 없다고
    // 알린다(외부 평가: 예전엔 켜짐→꺼짐만 말했다).
    if (now == PowerState.unknown && before != PowerState.unknown) {
      _tts.speak('전류 센서 정보가 끊겨 가전 전원 상태를 알 수 없습니다.',
          priority: TtsPriority.result);
    } else if (now != PowerState.unknown) {
      _tts.speak(powerSentence(now), priority: TtsPriority.result);
    }
  }

  @override
  void initState() {
    super.initState();
    PowerStatusService.instance.status.addListener(_onPower);
    final power = powerSentence(_power);
    // 이 안내는 화면 이름이 아니라 "무슨 일이 일어났는지"의 결과 보고이므로
    // 스크린리더 활성 시에도 들려야 한다 — result 우선순위 명시.
    _tts.speak(
      widget.completed
          ? '설정한 시간이 지났습니다. $power 홈으로 돌아가려면 버튼을 누르세요.'
          : '터치브릿지를 멈췄습니다. 가전이 이미 돌고 있었다면 가전은 계속 돌 수 있습니다. $power '
              '가전도 끄려면 가전 취소 버튼 누르기를 누르세요.',
      interrupt: true,
      priority: TtsPriority.result,
    );
  }

  Future<void> _pressApplianceCancel() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const VoiceListeningScreen(initialText: '취소'),
      ),
    );
  }

  Future<void> _goHome() async {
    unawaited(_tts.speak('홈 화면으로 돌아갑니다.'));
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _onHomeButtonTap() async {
    final screenReaderActive =
        MediaQuery.maybeOf(context)?.accessibleNavigation ??
        AccessibilitySettings.isScreenReaderActive;
    if (!AccessibilityConfirmationPolicy.requiresAppConfirmation(
      kind: ConfirmationActionKind.navigation,
      screenReaderActive: screenReaderActive,
    )) {
      AppLogger.info('accessibility.navigation_confirmation_skipped', {
        'destination': 'home',
        'reason': 'screen_reader_active',
      });
      HapticFeedback.lightImpact();
      await _goHome();
      return;
    }
    if (!_armedHomeButton) {
      setState(() => _armedHomeButton = true);
      HapticFeedback.mediumImpact();
      // arm 안내는 스크린리더가 자동으로 다시 읽어주지 않으므로 result
      // 우선순위를 명시해야 스크린리더 활성 시에도 들린다(interrupt만으로는
      // 억제됨 — TtsService 억제 계약 참조).
      await _tts.speak(
        '홈으로 돌아가기 버튼입니다. 한 번 더 누르면 홈으로 이동합니다.',
        interrupt: true,
        priority: TtsPriority.result,
      );
      // WCAG 2.2.1: 이중 탭 대기(armed)는 앱 전체 20초로 통일.
      Future.delayed(kDoubleTapArmTimeout, () {
        if (mounted) setState(() => _armedHomeButton = false);
      });
      return;
    }
    setState(() => _armedHomeButton = false);
    HapticFeedback.lightImpact();
    await _goHome();
  }

  @override
  void dispose() {
    PowerStatusService.instance.status.removeListener(_onPower);
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면(홈)이
    // 막 넣은 안내까지 지워진다.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final headline = widget.completed ? '설정한 시간이\n지났습니다' : '터치브릿지를\n멈췄습니다';
    final headlineLabel = widget.completed ? '설정한 시간이 지났습니다.' : '터치브릿지를 멈췄습니다.';
    final circleLabel = widget.completed ? '설정한 시간이 지났습니다.' : '터치브릿지 멈춤 확인.';
    final power = powerSentence(_power);
    final descText = widget.completed
        ? power
        : '가전이 이미 돌고 있었다면 계속 돌 수 있습니다. $power';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: 'Touch Bridge', showEmergency: false),
      body: Stack(
        children: [
          // Background Glows (장식 효과, 상호작용 없음)
          Positioned(
            top: ResponsiveScale.v(context, 150),
            left: ResponsiveScale.v(context, 40),
            child: IgnorePointer(
              child: Container(
                width: ResponsiveScale.v(context, 320),
                height: ResponsiveScale.v(context, 320),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(180),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: ResponsiveScale.v(context, 120),
            right: ResponsiveScale.v(context, 40),
            child: IgnorePointer(
              child: Container(
                width: ResponsiveScale.v(context, 260),
                height: ResponsiveScale.v(context, 260),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(150),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 메인 콘텐츠
                // 작은 화면·큰 글씨에서는 내용이 화면보다 길어진다. 넘치지 않고
                // 스크롤되게 하되, 남을 때는 지금처럼 가운데에 둔다.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveScale.v(context, 24),
                      ResponsiveScale.v(context, 20),
                      ResponsiveScale.v(context, 24),
                      ResponsiveScale.v(context, 24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 체크 원
                        Semantics(
                          label: circleLabel,
                          child: Container(
                            width: ResponsiveScale.v(context, 170),
                            height: ResponsiveScale.v(context, 170),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceElevated,
                              border: Border.all(color: AppColors.borderFocus),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.shadowPrimary,
                                  blurRadius: 36,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: ResponsiveScale.v(context, 140),
                                height: ResponsiveScale.v(context, 140),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 4,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  size: 96,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 20)),
                        // 제목
                        Semantics(
                          label: headlineLabel,
                          excludeSemantics: true,
                          child: Text(
                            headline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 34 * rs,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.7,
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 14)),
                        // 설명 텍스트
                        Semantics(
                          label: descText,
                          excludeSemantics: true,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.borderDefault,
                              ),
                            ),
                            child: Text(
                              descText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 20)),
                        // 터치브릿지 정지는 가전 정지가 아니다. 볼 수 없는 사용자에게 가전 버튼을
                        // 직접 누르라고 하는 대신, 앱이 가전의 취소 버튼을 눌러 준다(외부 평가).
                        // 음성 화면에서 "취소"로 처리해 평소처럼 '실행'·'취소' 확인을 거친다.
                        if (!widget.completed) ...[
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: double.infinity,
                              minHeight: ResponsiveScale.v(context, 72),
                            ),
                            child: OutlinedButton.icon(
                              key: const Key('stop_done_cancel_appliance'),
                              onPressed: _pressApplianceCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.primary, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(Icons.cancel_rounded, size: 28),
                              label: const Text(
                                '가전 취소 버튼 누르기',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          SizedBox(height: ResponsiveScale.v(context, 14)),
                        ],
                        // 홈으로 돌아가기 버튼
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: double.infinity,
                            minHeight: ResponsiveScale.v(context, 86),
                          ),
                          child: Semantics(
                            // 역할("버튼")은 button: true가 붙인다. 라벨과 자식 글자가 겹쳐
                            // 두 번 읽히지 않게 자식 시맨틱은 뺀다.
                            label: '홈으로 돌아가기',
                            value: _armedHomeButton ? '한 번 더 누르면 실행' : null,
                            button: true,
                            excludeSemantics: true,
                            onTap: _onHomeButtonTap,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _onHomeButtonTap,
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: AppColors.primaryGradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: _armedHomeButton
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.shadowPrimary,
                                        blurRadius: 12,
                                        spreadRadius: _armedHomeButton ? 4 : 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.home,
                                        size: 34 * rs,
                                        color: Colors.black,
                                      ),
                                      SizedBox(
                                        width: ResponsiveScale.v(context, 10),
                                      ),
                                      Flexible(
                                        child: Text(
                                          '홈으로 돌아가기',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 28 * rs,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.4,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                      ),
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
