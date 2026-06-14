import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/responsive_scale.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../services/tts_service.dart';

/// 비상 정지 완료 화면
/// - 이중 탭 확인 패턴 구현
/// - BottomNavBar로 통일된 네비게이션
/// - 시각장애인 접근성 최우선
class StopDoneScreen extends StatefulWidget {
  const StopDoneScreen({super.key});

  @override
  State<StopDoneScreen> createState() => _StopDoneScreenState();
}

class _StopDoneScreenState extends State<StopDoneScreen> {
  final TtsService _tts = TtsService();
  static const MainTab _currentTab = MainTab.home;
  bool _armedHomeButton = false;

  @override
  void initState() {
    super.initState();
    _tts.speak('작동이 안전하게 중단되었습니다. 홈으로 돌아가려면 버튼을 탭하세요.', interrupt: true);
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
      await _tts.speak('홈으로 돌아가기 버튼입니다. 한 번 더 누르면 실행합니다.');
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _armedHomeButton = false);
      });
      return;
    }
    setState(() => _armedHomeButton = false);
    HapticFeedback.lightImpact();
    await _goHome();
  }

  void _handleTabSelected(MainTab tab) {
    if (tab == MainTab.home) {
      _goHome();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
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
                  color: const Color(0x08FFEB00),
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
                  color: const Color(0x063B82F6),
                  borderRadius: BorderRadius.circular(150),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 상단 앱바
                Container(
                  height: ResponsiveScale.v(context, 64),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveScale.v(context, 16),
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xCC000000),
                    border: Border(
                      bottom: BorderSide(color: Color(0x14FFFFFF)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Semantics(
                        label: '메뉴 버튼',
                        button: true,
                        child: const Icon(
                          Icons.menu,
                          color: Color(0xFFFFEB00),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Semantics(
                        label: 'Touch Bridge 앱',
                        child: const Text(
                          'Touch Bridge',
                          style: TextStyle(
                            color: Color(0xFFFFEB00),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        label: '사용자 프로필',
                        button: true,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x4DFFEB00)),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFFF8FAFC),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 메인 콘텐츠
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveScale.v(context, 24),
                      ResponsiveScale.v(context, 20),
                      ResponsiveScale.v(context, 24),
                      ResponsiveScale.v(context, 108),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 체크 원
                        Semantics(
                          label: '작동이 안전하게 중단되었습니다. 확인 완료.',
                          child: Container(
                            width: ResponsiveScale.v(context, 170),
                            height: ResponsiveScale.v(context, 170),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0x100F172A),
                              border: Border.all(color: const Color(0x33FFEB00)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26FFEB00),
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
                                    color: const Color(0xFFFFEB00),
                                    width: 4,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  size: 96,
                                  color: Color(0xFFFFEB00),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 20)),
                        // 제목
                        Semantics(
                          label: '작동이 안전하게 중단되었습니다.',
                          child: Text(
                            '작동이 안전하게\n중단되었습니다',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFFFEB00),
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
                          label: '모든 동작이 중단되었습니다. 홈으로 돌아가려면 버튼을 탭하세요.',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x991E293B),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0x1AFFFFFF)),
                            ),
                            child: const Text(
                              '모든 동작이 중단되었습니다.\n홈으로 돌아가려면 버튼을 탭하세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
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
                            label: '홈으로 돌아가기 버튼${_armedHomeButton ? '. 활성화됨. 한 번 더 누르면 실행됨' : ''}',
                            button: true,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _onHomeButtonTap,
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEB00),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: _armedHomeButton
                                          ? const Color(0xFF422006)
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0x26FFEB00),
                                        blurRadius: 12,
                                        spreadRadius: _armedHomeButton ? 4 : 0,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.home, size: 34 * rs, color: const Color(0xFF000000)),
                                      SizedBox(width: ResponsiveScale.v(context, 10)),
                                      Text(
                                        '홈으로 돌아가기',
                                        style: TextStyle(
                                          fontSize: 28 * rs,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.4,
                                          color: const Color(0xFF000000),
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
      // 하단 네비게이션 — BottomNavBar로 통일
      bottomNavigationBar: BottomNavBar(
        currentTab: _currentTab,
        onTabSelected: _handleTabSelected,
      ),
    );
  }
}
