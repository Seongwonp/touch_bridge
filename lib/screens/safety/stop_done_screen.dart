import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/responsive_scale.dart';
import '../../services/tts_service.dart'; // TtsService 임포트

class StopDoneScreen extends StatefulWidget {
  const StopDoneScreen({super.key});

  @override
  State<StopDoneScreen> createState() => _StopDoneScreenState();
}

class _StopDoneScreenState extends State<StopDoneScreen> {
  final TtsService _tts = TtsService(); // TtsService 인스턴스 생성
  int? _armedNavIndex;

  @override
  void initState() {
    super.initState();
    _tts.speak('작동이 안전하게 중단되었습니다. 홈으로 돌아가려면 버튼을 탭하세요.'); // 화면 진입 시 TTS 안내
  }

  void _goHome() async {
    await _tts.speak('홈 화면으로 돌아갑니다.'); // 홈 이동 전 TTS 안내
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _onBottomTap(int index) async {
    if (_armedNavIndex != index) {
      setState(() {
        _armedNavIndex = index;
      });
      HapticFeedback.mediumImpact();
      await _tts.speak('${_getBottomItemLabel(index)} 탭입니다. 한 번 더 누르면 이동합니다.'); // 탭 선택 안내
      return;
    }

    _armedNavIndex = null; // armed 상태 해제
    if (index == 0) {
      _goHome();
    } else {
      // 다른 탭으로 이동하는 경우 (현재는 홈만 구현되어 있으므로 플레이스홀더)
      await _tts.speak('${_getBottomItemLabel(index)} 탭은 현재 이동할 수 없습니다.');
      setState(() {}); // armed 상태 해제를 위해 rebuild
    }
  }

  String _getBottomItemLabel(int index) {
    switch (index) {
      case 0: return '홈';
      case 1: return '음성';
      case 2: return '제어';
      case 3: return '설정';
      default: return '';
    }
  }

  Widget _bottomItem({
    required int index,
    required IconData icon,
    required String label,
    required bool active,
  }) {
    final bool isArmed = _armedNavIndex == index;

    return Semantics( // 하단 아이템 Semantics 추가
      label: '$label 탭. ${active ? '현재 선택됨' : ''} ${isArmed ? '활성화하려면 두 번 탭하세요.' : ''}',
      selected: active,
      button: true,
      child: InkWell(
        onTap: () => _onBottomTap(index),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: 70,
          height: 62,
          decoration: BoxDecoration(
            color: active ? const Color(0x1AFDE047) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isArmed
                  ? Colors.white
                  : (active ? const Color(0x4DFDE047) : Colors.transparent),
              width: isArmed ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: active ? const Color(0xFFFDE047) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: active
                      ? const Color(0xFFFDE047)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop(); // TtsService 리소스 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          // Background Decoration Glows (Semantics는 필요 없음)
          Positioned(
            top: ResponsiveScale.v(context, 150),
            left: ResponsiveScale.v(context, 40),
            child: IgnorePointer(
              child: Container(
                width: ResponsiveScale.v(context, 320),
                height: ResponsiveScale.v(context, 320),
                decoration: BoxDecoration(
                  color: const Color(0x08FDE047),
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
                Container(
                  height: ResponsiveScale.v(context, 64),
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveScale.v(context, 16),
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xCC020617),
                    border: Border(
                      bottom: BorderSide(color: Color(0x14FFFFFF)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Semantics( // 메뉴 아이콘 Semantics 추가
                        label: '메뉴 버튼',
                        button: true,
                        child: const Icon(
                          Icons.menu,
                          color: Color(0xFFFDE047),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Semantics( // 앱 타이틀 Semantics 추가
                        label: 'Touch Bridge 앱',
                        child: const Text(
                          'Touch Bridge',
                          style: TextStyle(
                            color: Color(0xFFFDE047),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Semantics( // 사용자 프로필 아이콘 Semantics 추가
                        label: '사용자 프로필',
                        button: true,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x4DFDE047)),
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
                        Semantics( // 완료 아이콘 및 메시지 그룹 Semantics 추가
                          label: '작동이 안전하게 중단되었습니다. 확인 완료.',
                          child: Container(
                            width: ResponsiveScale.v(context, 170),
                            height: ResponsiveScale.v(context, 170),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0x100F172A),
                              border: Border.all(color: const Color(0x33FDE047)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26FDE047),
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
                                    color: const Color(0xFFFDE047),
                                    width: 4,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  size: 96,
                                  color: Color(0xFFFDE047),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 20)),
                        Semantics( // 주요 상태 메시지 Semantics 추가
                          label: '작동이 안전하게 중단되었습니다.',
                          child: Text(
                            '작동이 안전하게\n중단되었습니다',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFFDE047),
                              fontSize: 34 * rs,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.7,
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 14)),
                        Semantics( // 추가 안내 메시지 Semantics 추가
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
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 20)),
                        SizedBox(
                          width: double.infinity,
                          height: ResponsiveScale.v(context, 86),
                          child: Semantics( // 홈으로 돌아가기 버튼 Semantics 추가
                            label: '홈으로 돌아가기 버튼',
                            button: true,
                            child: ElevatedButton(
                              onPressed: _goHome,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDE047),
                                foregroundColor: const Color(0xFF422006),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 12,
                                shadowColor: const Color(0x26FDE047),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.home, size: 34 * rs),
                                  SizedBox(width: ResponsiveScale.v(context, 10)),
                                  Text(
                                    '홈으로 돌아가기',
                                    style: TextStyle(
                                      fontSize: 28 * rs,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF020617),
                    Color(0xE6020617),
                    Color(0x00020617),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _bottomItem(
                    index: 0,
                    icon: Icons.home,
                    label: 'HOME',
                    active: true,
                  ),
                  _bottomItem(
                    index: 1,
                    icon: Icons.mic,
                    label: 'VOICE',
                    active: false,
                  ),
                  _bottomItem(
                    index: 2,
                    icon: Icons.settings_remote,
                    label: 'CONTROL',
                    active: false,
                  ),
                  _bottomItem(
                    index: 3,
                    icon: Icons.settings,
                    label: 'SETTINGS',
                    active: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
