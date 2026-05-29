import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tts_service.dart';

enum MainTab { home, control, voice, settings }

extension MainTabX on MainTab {
  int get index {
    switch (this) {
      case MainTab.home:
        return 0;
      case MainTab.control:
        return 1;
      case MainTab.voice:
        return 2;
      case MainTab.settings:
        return 3;
    }
  }

  static MainTab fromIndex(int index) {
    switch (index) {
      case 0:
        return MainTab.home;
      case 1:
        return MainTab.control;
      case 2:
        return MainTab.voice;
      case 3:
        return MainTab.settings;
      default:
        return MainTab.home;
    }
  }
}

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  final MainTab currentTab;
  final ValueChanged<MainTab> onTabSelected;

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  final TtsService _tts = TtsService();
  Timer? _confirmResetTimer;
  int? _armedIndex;

  String _tabLabel(MainTab tab) {
    switch (tab) {
      case MainTab.home:
        return '홈';
      case MainTab.control:
        return '원격 조작';
      case MainTab.voice:
        return '음성 도움';
      case MainTab.settings:
        return '설정';
    }
  }

  Future<void> _handleDestinationTap(int index) async {
    final MainTab selectedTab = MainTabX.fromIndex(index);

    if (_armedIndex != index) {
      setState(() {
        _armedIndex = index;
      });
      HapticFeedback.mediumImpact();

      _confirmResetTimer?.cancel();
      _confirmResetTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _armedIndex = null;
        });
      });

      await _tts.speak(
        '${_tabLabel(selectedTab)} 탭입니다. 한 번 더 누르면 이동합니다.',
        source: 'BottomNavBar',
      );
      return;
    }

    _confirmResetTimer?.cancel();
    setState(() {
      _armedIndex = null;
    });
    await _tts.stop();
    widget.onTabSelected(selectedTab);
  }

  NavigationDestination _buildDestination({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isArmed = _armedIndex == index;

    return NavigationDestination(
      label: label,
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isArmed ? Colors.white : Colors.transparent,
            width: isArmed ? 2.5 : 0,
          ),
        ),
        child: Icon(icon),
      ),
    );
  }

  @override
  void dispose() {
    _confirmResetTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      height: 72,
      selectedIndex: widget.currentTab.index,
      onDestinationSelected: (index) {
        _handleDestinationTap(index);
      },
      destinations: [
        _buildDestination(index: 0, icon: Icons.home_outlined, label: '홈'),
        _buildDestination(
          index: 1,
          icon: Icons.settings_remote_outlined,
          label: '조작',
        ),
        _buildDestination(index: 2, icon: Icons.mic_none_outlined, label: '음성'),
        _buildDestination(index: 3, icon: Icons.settings_outlined, label: '설정'),
      ],
    );
  }
}
