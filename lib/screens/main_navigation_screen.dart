import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
          guide: '홈 화면입니다. 말하기 버튼으로 음성 제어를 시작합니다.',
          screen: HomeScreen(),
        ),
        _NavDestination(
          icon: Icons.manage_search_rounded,
          label: '기기 관리',
          guide: '기기 관리 화면입니다. 기기를 등록합니다.',
          screen: DeviceManagementScreen(),
        ),
        _NavDestination(
          icon: Icons.emergency_rounded,
          label: '비상',
          guide: '비상 정지입니다. 버튼을 눌러 기기를 중단합니다.',
          screen: EmergencyAccessScreen(),
        ),
        _NavDestination(
          icon: Icons.settings_rounded,
          label: '설정',
          guide: '설정 화면입니다. 음성 속도와 접근성을 조정합니다.',
          screen: SettingsScreen(),
        ),
      ];
    }

    return const [
      _NavDestination(
        icon: Icons.home_rounded,
        label: '홈',
        guide: '홈 화면입니다. 말하기 버튼으로 음성 제어를 시작합니다.',
        screen: HomeScreen(),
      ),
      _NavDestination(
        icon: Icons.emergency_rounded,
        label: '비상',
        guide: '비상 정지입니다. 버튼을 눌러 기기를 중단합니다.',
        screen: EmergencyAccessScreen(),
      ),
      _NavDestination(
        icon: Icons.settings_rounded,
        label: '설정',
        guide: '설정 화면입니다. 음성 속도와 접근성을 조정합니다.',
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
    // 첫 실행 1회뿐인 핵심 온보딩 안내 — result 우선순위로 재생해
    // (a) 스크린리더 활성 시에도 들리고, (b) 홈 화면의 navigation 안내가
    // 큐에서 이 안내를 대체(navigation 최신 1건 유지 규칙)하지 못하게 한다.
    if (guardianMode) {
      await _tts.speak(
        '보호자 안내입니다. 기기 관리에서 기기를 등록하세요.',
        source: 'MainNavigationScreen',
        interrupt: true,
        priority: TtsPriority.result,
      );
      await _tts.speak(
        '등록 후 홈에서 기기를 선택하고 말하기 버튼으로 제어합니다.',
        source: 'MainNavigationScreen',
        priority: TtsPriority.result,
      );
    } else {
      await _tts.speak(
        'Touch Bridge입니다. 보호자가 기기를 먼저 등록해야 합니다.',
        source: 'MainNavigationScreen',
        interrupt: true,
        priority: TtsPriority.result,
      );
      await _tts.speak(
        '설정에서 보호자 모드를 켜고 기기를 등록한 뒤, 홈에서 말하기를 누르세요.',
        source: 'MainNavigationScreen',
        priority: TtsPriority.result,
      );
    }
    await prefs.setBool('quick_start_seen', true);

    // 사용자 모드 첫 실행 시 시각적 온보딩 다이얼로그도 노출한다.
    // TalkBack이 AlertDialog content를 자동으로 낭독 → TTS와 이중 보장.
    if (!guardianMode && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderDefault),
            ),
            title: const Text(
              '처음 오셨나요?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              '보호자가 아래 순서로 먼저 설정해야 합니다.\n\n'
              '1. 설정 → 보호자 모드 켜기\n'
              '2. 기기 관리 → 기기 등록\n'
              '3. 보호자 모드 끄기\n\n'
              '이후 홈 화면에서 음성으로 기기를 제어할 수 있습니다.',
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '확인했습니다',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      });
    }
  }

  Future<void> _handleBottomTap(int index) async {
    final destinations = _destinations(
      AccessibilitySettings.instance.guardianModeEnabled,
    );
    if (_currentIndex == index) {
      // 다른 탭이 armed 상태로 남아 있으면 여기서 해제한다. 그렇지 않으면
      // "현재 탭 → 다른 탭"으로 되돌아왔을 때 armed가 유지되어, 그 다른 탭을
      // 한 번만 눌러도 확인 없이 바로 이동해버리는 문제가 있었다.
      if (_armedNavIndex != null) {
        _navResetTimer?.cancel();
        setState(() => _armedNavIndex = null);
      }
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
      _navResetTimer = Timer(kDoubleTapArmTimeout, () {
        if (mounted) setState(() => _armedNavIndex = null);
      });
      // 탭 arm은 스크린리더가 자동으로 다시 읽어주지 않는 "확인 필요" 상태이므로
      // result 우선순위를 명시해 스크린리더 활성 시에도 반드시 들리게 한다
      // (interrupt만으로는 억제됨 — TtsService 억제 계약 참조).
      await _tts.speak(
        '${destinations[index].label}. ${destinations[index].guide} 이동하려면 한 번 더 누르세요.',
        source: 'MainNavigationScreen',
        interrupt: true,
        priority: TtsPriority.result,
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
    // 탭 전환 확정도 스크린리더가 자동 안내하지 않으므로 result로 들려준다.
    await _tts.speak(
      '${destinations[index].label} 이동. ${destinations[index].guide}',
      source: 'MainNavigationScreen',
      priority: TtsPriority.result,
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
              // PrimaryButton과 같은 패턴: armed 상태를 value/hint/liveRegion으로
              // 노출해 TTS 외에 스크린리더 자체 채널로도 "확인 대기"가 전달되게 한다.
              value: isArmed ? '이동 대기 중' : null,
              hint: isArmed ? '한 번 더 누르면 이동합니다' : null,
              liveRegion: isArmed,
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
    // TtsService는 앱 전역 싱글톤 큐다. 여기서 stop()을 부르면 이 화면이
    // dispose되는 순간(보통 다음 화면 initState 직후) 다음 화면이 막 넣은
    // 안내까지 통째로 지워버려 안내가 잘리는 문제가 있었다.
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

    void openVoice() {
      FeedbackService.instance.vibrateSuccess();
      FeedbackService.instance.playDing();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const VoiceListeningScreen(autoStart: true),
        ),
      );
    }

    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: '음성 명령 시작'): openVoice,
      },
      child: GestureDetector(
        onLongPress: openVoice,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: IndexedStack(
            index: _currentIndex,
            children: destinations.map((d) => d.screen).toList(growable: false),
          ),
          bottomNavigationBar: _buildBottomBar(rs, context, destinations),
        ),
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
