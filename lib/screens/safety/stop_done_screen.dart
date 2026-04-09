import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StopDoneScreen extends StatefulWidget {
  const StopDoneScreen({super.key});

  @override
  State<StopDoneScreen> createState() => _StopDoneScreenState();
}

class _StopDoneScreenState extends State<StopDoneScreen> {
  int? _armedNavIndex;

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _onBottomTap(int index) {
    if (_armedNavIndex != index) {
      setState(() {
        _armedNavIndex = index;
      });
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() {
      _armedNavIndex = null;
    });

    if (index == 0) {
      _goHome();
    }
  }

  Widget _bottomItem({
    required int index,
    required IconData icon,
    required String label,
    required bool active,
  }) {
    final bool isArmed = _armedNavIndex == index;

    return InkWell(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          Positioned(
            top: 150,
            left: 40,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  color: const Color(0x08FDE047),
                  borderRadius: BorderRadius.circular(180),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: 40,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
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
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xCC020617),
                    border: Border(
                      bottom: BorderSide(color: Color(0x14FFFFFF)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu,
                        color: Color(0xFFFDE047),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Touch Bridge',
                        style: TextStyle(
                          color: Color(0xFFFDE047),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Spacer(),
                      Container(
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
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 108),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 192,
                          height: 192,
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
                              width: 160,
                              height: 160,
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
                        const SizedBox(height: 28),
                        const Text(
                          '작동이 안전하게\n중단되었습니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFDE047),
                            fontSize: 40,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        Container(
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
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 96,
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
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.home, size: 42),
                                SizedBox(width: 10),
                                Text(
                                  '홈으로 돌아가기',
                                  style: TextStyle(
                                    fontSize: 33,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ],
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
