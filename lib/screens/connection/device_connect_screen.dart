import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../home/home_screen.dart';
import '../voice/voice_listening_screen.dart';
import 'qr_scan_screen.dart';

class DeviceConnectScreen extends StatelessWidget {
  const DeviceConnectScreen({super.key});

  void _showPlaceholder(BuildContext context, String label) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 기능은 다음 단계에서 연결됩니다.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF041329),
        border: Border(bottom: BorderSide(color: Color(0x22FDE047))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.grid_view_rounded, color: Color(0xFFFDE047)),
            tooltip: '뒤로 가기',
          ),
          const SizedBox(width: 4),
          const Text(
            'Touch Bridge',
            style: TextStyle(
              color: Color(0xFFFDE047),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _showPlaceholder(context, '설정'),
            icon: const Icon(Icons.settings, color: Color(0xFFFDE047)),
            tooltip: '설정',
          ),
        ],
      ),
    );
  }

  Widget _statusCard(bool compact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1C32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x335DF9D4)),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFF5DF9D4),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0xAA5DF9D4), blurRadius: 12)],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESP32 Smart Hub',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '연결 가능한 기기 감지됨',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF5DF9D4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool highlighted,
    required bool compact,
  }) {
    final Color cardColor = highlighted
        ? const Color(0xFFFDE047)
        : const Color(0xFF1C2A41);
    final Color titleColor = highlighted
        ? const Color(0xFF211B00)
        : AppColors.textPrimary;
    final Color subtitleColor = highlighted
        ? const Color(0xFF524600)
        : const Color(0xFFCEC6AD);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 16,
            vertical: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? const Color(0x88FFFFFF)
                  : const Color(0x26FFFFFF),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 44 : 48,
                height: compact ? 44 : 48,
                decoration: BoxDecoration(
                  color: highlighted
                      ? const Color(0xFF726300)
                      : const Color(0x2200B8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: highlighted
                      ? const Color(0xFFFDE047)
                      : const Color(0xFF00B8FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: highlighted
                    ? const Color(0xFF211B00)
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallAction({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2A41),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: const Color(0xFFB6C6ED), size: 22),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomIconNav(BuildContext context) {
    Widget navItem({
      required IconData icon,
      required String label,
      required bool active,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFDE047) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: active
                      ? const Color(0xFF726300)
                      : const Color(0x88D6E3FF),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? const Color(0xFF726300)
                        : const Color(0x88D6E3FF),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 86,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
      decoration: const BoxDecoration(
        color: Color(0xF2041329),
        border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
      ),
      child: Row(
        children: [
          navItem(
            icon: Icons.home_rounded,
            label: '홈',
            active: false,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
              );
            },
          ),
          navItem(
            icon: Icons.vibration_rounded,
            label: '기기',
            active: true,
            onTap: () {},
          ),
          navItem(
            icon: Icons.mic_rounded,
            label: '음성',
            active: false,
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const VoiceListeningScreen(),
                ),
              );
            },
          ),
          navItem(
            icon: Icons.settings_rounded,
            label: '설정',
            active: false,
            onTap: () => _showPlaceholder(context, '설정'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxHeight < 760;

        return Scaffold(
          backgroundColor: const Color(0xFF041329),
          body: SafeArea(
            child: Column(
              children: [
                _topBar(context),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      compact ? 8 : 10,
                      16,
                      compact ? 8 : 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'STEP 1: CONNECTION',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(
                              0xFFFDE047,
                            ).withValues(alpha: 0.8),
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          '기기 연결 설정',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 12),
                        _statusCard(compact),
                        SizedBox(height: compact ? 8 : 10),
                        _optionCard(
                          context: context,
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'QR 코드 스캔',
                          subtitle: '허브의 QR을 촬영하여 즉시 연결',
                          highlighted: true,
                          compact: compact,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const QrScanScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: compact ? 8 : 10),
                        _optionCard(
                          context: context,
                          icon: Icons.bluetooth_rounded,
                          title: '블루투스 연결',
                          subtitle: '주변 기기 자동 검색 및 페어링',
                          highlighted: false,
                          compact: compact,
                          onTap: () => _showPlaceholder(context, '블루투스 연결'),
                        ),
                        SizedBox(height: compact ? 8 : 10),
                        Row(
                          children: [
                            _smallAction(
                              context: context,
                              title: 'NFC 태그',
                              icon: Icons.contactless_rounded,
                              onTap: () => _showPlaceholder(context, 'NFC 태그'),
                            ),
                            const SizedBox(width: 10),
                            _smallAction(
                              context: context,
                              title: '수동 입력',
                              icon: Icons.edit_rounded,
                              onTap: () => _showPlaceholder(context, '수동 입력'),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Center(
                          child: Text(
                            '연결에 문제가 있나요? 도움말 보기',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _bottomIconNav(context),
              ],
            ),
          ),
        );
      },
    );
  }
}
