import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';

/// 비상 정지 완료 화면
/// - 이중 탭 확인 패턴 구현
/// - 단일 "홈으로 돌아가기" 버튼만 제공 (별도 하단 탭은 두지 않음 —
///   이 화면에서 다른 탭으로 이동해도 실제로 화면이 바뀌지 않아 음성 안내와 동작이 불일치하는 문제가 있었음)
/// - 시각장애인 접근성 최우선
class StopDoneScreen extends StatefulWidget {
  const StopDoneScreen({super.key, this.completed = false});

  /// true면 타이머가 정상적으로 끝난 "작동 완료", false면 사용자/비상 "중단".
  final bool completed;

  @override
  State<StopDoneScreen> createState() => _StopDoneScreenState();
}

class _StopDoneScreenState extends State<StopDoneScreen> {
  final TtsService _tts = TtsService();
  bool _armedHomeButton = false;

  @override
  void initState() {
    super.initState();
    // 이 안내는 화면 이름이 아니라 "무슨 일이 일어났는지"의 결과 보고이므로
    // 스크린리더 활성 시에도 들려야 한다 — result 우선순위 명시.
    _tts.speak(
      widget.completed
          ? '작동이 끝났습니다. 홈으로 돌아가려면 버튼을 누르세요.'
          : '즉시 중단했습니다. 홈으로 돌아가려면 버튼을 누르세요.',
      interrupt: true,
      priority: TtsPriority.result,
    );
  }

  Future<void> _goHome() async {
    await _tts.speak('홈 화면으로 돌아갑니다.');
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _onHomeButtonTap() async {
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
      Future.delayed(const Duration(seconds: 15), () {
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
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면(홈)이
    // 막 넣은 안내까지 지워버린다(화면 전환 시 안내가 잘리는 문제).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final headline = widget.completed ? '작동이\n끝났습니다' : '작동이 안전하게\n중단되었습니다';
    final headlineLabel = widget.completed ? '작동이 끝났습니다.' : '작동이 안전하게 중단되었습니다.';
    final circleLabel = widget.completed
        ? '작동이 끝났습니다. 확인 완료.'
        : '작동이 안전하게 중단되었습니다. 확인 완료.';
    final descText = widget.completed
        ? '작동이 정상적으로 끝났습니다.\n홈으로 돌아가려면 버튼을 탭하세요.'
        : '모든 동작이 중단되었습니다.\n홈으로 돌아가려면 버튼을 탭하세요.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: 'Touch Bridge'),
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
                Expanded(
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
                        // 홈으로 돌아가기 버튼
                        SizedBox(
                          width: double.infinity,
                          height: ResponsiveScale.v(context, 86),
                          child: Semantics(
                            label:
                                '홈으로 돌아가기 버튼${_armedHomeButton ? '. 활성화됨. 한 번 더 누르면 실행됨' : ''}',
                            button: true,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _onHomeButtonTap,
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
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
                                      Text(
                                        '홈으로 돌아가기',
                                        style: TextStyle(
                                          fontSize: 28 * rs,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.4,
                                          color: Colors.black,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
