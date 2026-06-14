import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home/home_screen.dart';
import 'connection/device_connect_screen.dart';
import 'voice/voice_listening_screen.dart';
import 'settings/settings_screen.dart';
import '../services/tts_service.dart';
import '../services/accessibility_settings.dart';
import '../services/feedback_service.dart';
import '../widgets/responsive_scale.dart';
import '../../theme/app_colors.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final TtsService _tts = TtsService();
  Timer? _navResetTimer;
  int? _armedNavIndex;

  final List<Widget> _screens = const [
    HomeScreen(),
    DeviceConnectScreen(),
    VoiceListeningScreen(),
    SettingsScreen(),
  ];

  final List<({IconData icon, String label})> _navItems = const [
    (icon: Icons.home_rounded, label: '홈'),
    (icon: Icons.devices_rounded, label: '연결'),
    (icon: Icons.mic_rounded, label: '음성'),
    (icon: Icons.settings_rounded, label: '설정'),
  ];

  final List<String> _navGuides = const [
    '기기 선택 화면입니다. 등록된 기기를 두 번 눌러 제어할 수 있습니다.',
    '기기 연결 화면입니다. QR, 블루투스, NFC로 기기를 추가합니다.',
    '음성 명령 화면입니다. 만두 데워줘처럼 말하면 자동으로 해석합니다.',
    '설정 화면입니다. 음성 안내와 보호자 안내 모드를 조정합니다.',
  ];

  @override
  void initState() {
    super.initState();
    _announceQuickStart();
  }

  Future<void> _announceQuickStart() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('quick_start_seen') ?? false;
    if (seen) return;

    final guardianMode = AccessibilitySettings.instance.guardianModeEnabled;
    final message = guardianMode
        ? '보호자 안내입니다. 연결 탭에서 기기를 등록한 뒤, 홈 탭에서 기기를 선택하세요. 음성 탭에서는 만두 데워줘처럼 말씀하시면 됩니다.'
        : 'Touch Bridge입니다. 홈 탭에서 기기를 선택하고, 음성 탭에서 말씀해 주세요.';

    await _tts.speak(message, source: 'MainNavigationScreen', interrupt: true);
    await prefs.setBool('quick_start_seen', true);
  }

  Future<void> _handleBottomTap(int index) async {
    if (_currentIndex == index) {
      await _tts.speak(_navGuides[index], source: 'MainNavigationScreen');
      return;
    }

    if (_armedNavIndex != index) {
      setState(() => _armedNavIndex = index);
      FeedbackService.instance.vibrateSuccess();
      _navResetTimer?.cancel();
      _navResetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _armedNavIndex = null);
      });
      await _tts.speak(
        '${_navItems[index].label}. ${_navGuides[index]} 이동하려면 한 번 더 누르세요.',
        source: 'MainNavigationScreen',
      );
      return;
    }

    _navResetTimer?.cancel();
    setState(() {
      _currentIndex = index;
      _armedNavIndex = null;
    });
    await _tts.stop();
    FeedbackService.instance.vibrateSuccess();
    await _tts.speak(
      '${_navItems[index].label} 이동. ${_navGuides[index]}',
      source: 'MainNavigationScreen',
    );
  }

  Widget _buildBottomBar(double rs, BuildContext context) {
    return Container(
      height: ResponsiveScale.v(context, 80),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        children: List.generate(_navItems.length, (index) {
          final item = _navItems[index];
          final bool isActive = _currentIndex == index;
          final bool isArmed = _armedNavIndex == index;

          return Expanded(
            child: Semantics(
              label: '${item.label} 탭',
              selected: isActive,
              button: true,
              child: GestureDetector(
                onTap: () => _handleBottomTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.symmetric(
                    horizontal: 6 * rs,
                    vertical: 8 * rs,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFFFEB00)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16 * rs),
                    border: isArmed
                        ? Border.all(color: Colors.white, width: 2.5 * rs)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        color: isActive
                            ? Colors.black
                            : const Color(0xFF888888),
                        size: 24 * rs,
                      ),
                      SizedBox(height: ResponsiveScale.v(context, 4)),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11 * rs,
                          fontWeight: FontWeight.w800,
                          color: isActive
                              ? Colors.black
                              : const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    _navResetTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return GestureDetector(
      onLongPress: () {
        FeedbackService.instance.vibrateSuccess();
        FeedbackService.instance.playDing();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const VoiceListeningScreen(autoStart: true),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: _buildBottomBar(rs, context),
      ),
    );
  }
}
