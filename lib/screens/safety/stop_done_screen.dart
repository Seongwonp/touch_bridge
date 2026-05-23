import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/responsive_scale.dart';

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
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              height: ResponsiveScale.v(context, 64),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveScale.v(context, 8),
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Text(
                    'Touch Bridge',
                    style: TextStyle(
                      color: Color(0xFFFFEB00),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveScale.v(context, 24),
                  ResponsiveScale.v(context, 40),
                  ResponsiveScale.v(context, 24),
                  ResponsiveScale.v(context, 40),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: ResponsiveScale.v(context, 140),
                      height: ResponsiveScale.v(context, 140),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF111111),
                        border: Border.all(
                          color: const Color(0xFFFFEB00),
                          width: 4,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 84,
                          color: Color(0xFFFFEB00),
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 32)),
                    Text(
                      '작동이 안전하게\n중단되었습니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32 * rs,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    const Text(
                      '모든 기기 동작이 멈췄습니다.\n안심하고 확인하셔도 좋습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: ResponsiveScale.v(context, 72),
                      child: ElevatedButton.icon(
                        onPressed: _goHome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEB00),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.home_rounded, size: 28),
                        label: Text(
                          '홈으로 돌아가기',
                          style: TextStyle(
                            fontSize: 22 * rs,
                            fontWeight: FontWeight.w900,
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
    );
  }
}
