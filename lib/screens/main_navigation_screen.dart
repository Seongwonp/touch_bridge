import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home/home_screen.dart';
import 'connection/device_connect_screen.dart';
import 'voice/voice_listening_screen.dart';
import 'settings/settings_screen.dart';
import '../services/tts_service.dart';

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

  final List<Widget> _screens = [
    const HomeScreen(),
    const DeviceConnectScreen(),
    const VoiceListeningScreen(),
    const SettingsScreen(),
  ];

  final List<({IconData icon, String label})> _navItems = const [
    (icon: Icons.home_rounded, label: '홈'),
    (icon: Icons.devices_rounded, label: '기기'),
    (icon: Icons.mic_rounded, label: '음성'),
    (icon: Icons.settings_rounded, label: '설정'),
  ];

  Future<void> _handleBottomTap(int index) async {
    if (_currentIndex == index) return;

    if (_armedNavIndex != index) {
      setState(() {
        _armedNavIndex = index;
      });
      HapticFeedback.mediumImpact();

      _navResetTimer?.cancel();
      _navResetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _armedNavIndex = null;
          });
        }
      });

      await _tts.speak('${_navItems[index].label} 탭입니다. 한 번 더 누르면 이동합니다.');
      return;
    }

    _navResetTimer?.cancel();
    setState(() {
      _currentIndex = index;
      _armedNavIndex = null;
    });
    await _tts.stop();
    HapticFeedback.lightImpact();
  }

  Widget _buildBottomBar() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
      ),
      child: Row(
        children: List.generate(_navItems.length, (index) {
          final item = _navItems[index];
          final bool isActive = _currentIndex == index;
          final bool isArmed = _armedNavIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => _handleBottomTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFFFEB00) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isArmed
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      color: isActive ? Colors.black : const Color(0xFF888888),
                      size: 24,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.black : const Color(0xFF888888),
                      ),
                    ),
                  ],
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
}
