import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home/home_screen.dart';
import 'voice/voice_listening_screen.dart';
import 'safety/emergency_access_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/device_management_screen.dart';
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

  List<_NavDestination> _destinations(bool guardianMode) {
    if (guardianMode) {
      return const [
        _NavDestination(
          icon: Icons.home_rounded,
          label: '홈',
          guide: '홈 화면입니다. 등록된 기기를 선택하고, 말하기 버튼으로 음성 제어를 시작합니다.',
          screen: HomeScreen(),
        ),
        _NavDestination(
          icon: Icons.manage_search_rounded,
          label: '기기 관리',
          guide: '보호자용 기기 관리 화면입니다. 기기 연결과 하드웨어 등록을 관리합니다.',
          screen: DeviceManagementScreen(),
        ),
        _NavDestination(
          icon: Icons.emergency_rounded,
          label: '비상',
          guide: '비상 정지 화면입니다. 큰 빨간 버튼을 두 번 눌러 현재 기기를 중단합니다.',
          screen: EmergencyAccessScreen(),
        ),
        _NavDestination(
          icon: Icons.settings_rounded,
          label: '설정',
          guide: '설정 화면입니다. 음성 안내, 접근성, 보호자 설정을 조정합니다.',
          screen: SettingsScreen(),
        ),
      ];
    }

    return const [
      _NavDestination(
        icon: Icons.home_rounded,
        label: '홈',
        guide: '홈 화면입니다. 등록된 기기를 선택하고, 말하기 버튼으로 음성 제어를 시작합니다.',
        screen: HomeScreen(),
      ),
      _NavDestination(
        icon: Icons.emergency_rounded,
        label: '비상',
        guide: '비상 정지 화면입니다. 큰 빨간 버튼을 두 번 눌러 현재 기기를 중단합니다.',
        screen: EmergencyAccessScreen(),
      ),
      _NavDestination(
        icon: Icons.settings_rounded,
        label: '설정',
        guide: '설정 화면입니다. 음성 안내와 접근성 설정을 조정합니다.',
        screen: SettingsScreen(),
      ),
    ];
  }

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
        ? '보호자 안내입니다. 기기 관리에서 기기를 등록한 뒤, 홈에서 기기를 선택하세요. 홈의 말하기 버튼으로 음성 제어를 시작할 수 있습니다.'
        : 'Touch Bridge입니다. 홈에서 기기를 선택하고 말하기 버튼을 누르세요. 위급할 때는 비상 탭을 사용하세요.';

    await _tts.speak(message, source: 'MainNavigationScreen', interrupt: true);
    await prefs.setBool('quick_start_seen', true);
  }

  Future<void> _handleBottomTap(int index) async {
    final destinations = _destinations(
      AccessibilitySettings.instance.guardianModeEnabled,
    );
    if (_currentIndex == index) {
      await _tts.speak(
        destinations[index].guide,
        source: 'MainNavigationScreen',
      );
      return;
    }

    if (_armedNavIndex != index) {
      setState(() => _armedNavIndex = index);
      FeedbackService.instance.vibrateSuccess();
      _navResetTimer?.cancel();
      _navResetTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) setState(() => _armedNavIndex = null);
      });
      await _tts.speak(
        '${destinations[index].label}. ${destinations[index].guide} 이동하려면 한 번 더 누르세요.',
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
      '${destinations[index].label} 이동. ${destinations[index].guide}',
      source: 'MainNavigationScreen',
    );
  }

  Widget _buildBottomBar(
    double rs,
    BuildContext context,
    List<_NavDestination> destinations,
  ) {
    return Container(
      height: ResponsiveScale.v(context, 80),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: List.generate(destinations.length, (index) {
          final item = destinations[index];
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
                    gradient: isActive
                        ? const LinearGradient(
                            colors: AppColors.primaryGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isActive ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(16 * rs),
                    border: isArmed
                        ? Border.all(color: Colors.white, width: 2.5 * rs)
                        : null,
                    boxShadow: isActive
                        ? const [
                            BoxShadow(
                              color: AppColors.shadowPrimary,
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        color: isActive ? Colors.black : AppColors.textTertiary,
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
                              : AppColors.textTertiary,
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
    final destinations = _destinations(
      AccessibilitySettings.instance.guardianModeEnabled,
    );
    final currentIndex = _currentIndex.clamp(0, destinations.length - 1);
    if (currentIndex != _currentIndex) {
      _currentIndex = currentIndex;
      _armedNavIndex = null;
    }

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
        body: IndexedStack(
          index: _currentIndex,
          children: destinations.map((d) => d.screen).toList(growable: false),
        ),
        bottomNavigationBar: _buildBottomBar(rs, context, destinations),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.label,
    required this.guide,
    required this.screen,
  });

  final IconData icon;
  final String label;
  final String guide;
  final Widget screen;
}
