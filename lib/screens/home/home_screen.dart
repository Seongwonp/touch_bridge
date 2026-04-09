import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../connection/device_connect_screen.dart';
import '../control/remote_control_screen.dart';
import '../settings/settings_screen.dart';
import '../voice/voice_listening_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts _tts = FlutterTts();
  final PageController _pageController = PageController(viewportFraction: 0.94);

  Timer? _navResetTimer;
  int? _armedNavIndex;
  int _currentDeviceIndex = 0;

  final List<({String name, String status, IconData icon})> _devices = const [
    (name: '스마트 전자레인지', status: '작동 대기 중', icon: Icons.microwave_rounded),
    (name: '스마트 공기청정기', status: '공기 질 분석 중', icon: Icons.air_rounded),
    (name: '스마트 전등 허브', status: '원격 제어 가능', icon: Icons.light_mode_rounded),
  ];

  Future<void> _handleBottomTap(int index) async {
    const List<String> labels = ['상태', '기기', '음성', '설정'];

    if (_armedNavIndex != index) {
      setState(() {
        _armedNavIndex = index;
      });
      HapticFeedback.mediumImpact();

      _navResetTimer?.cancel();
      _navResetTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _armedNavIndex = null;
        });
      });

      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.stop();
      await _tts.speak('${labels[index]} 탭입니다. 다시 한 번 누르면 이동합니다.');
      return;
    }

    _navResetTimer?.cancel();
    setState(() {
      _armedNavIndex = null;
    });
    await _tts.stop();

    if (!mounted) {
      return;
    }

    switch (index) {
      case 0:
        return;
      case 1:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const DeviceConnectScreen()),
        );
        break;
      case 2:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const VoiceListeningScreen()),
        );
        break;
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        );
        break;
    }
  }

  Widget _bottomTab({
    required int index,
    required IconData icon,
    required String label,
    required bool active,
  }) {
    final bool isArmed = _armedNavIndex == index;

    return InkWell(
      onTap: () {
        _handleBottomTap(index);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        height: 64,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFDE047) : Colors.transparent,
          borderRadius: BorderRadius.circular(active ? 14 : 12),
          border: Border.all(
            color: isArmed ? Colors.white : Colors.transparent,
            width: isArmed ? 2.5 : 0,
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x40FDE047),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: active ? const Color(0xFF726300) : const Color(0x80FFFFFF),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: active
                    ? const Color(0xFF726300)
                    : const Color(0x80FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _navResetTimer?.cancel();
    _tts.stop();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFDE047),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RemoteControlScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu, color: Color(0xFFFDE047)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Touch Bridge',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Color(0xFFFDE047),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0x4D1C2A41),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.settings,
                        color: Color(0xFFFDE047),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    const Text(
                      '홈 - 기기 전환',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1400B8FF),
                        border: Border.all(color: const Color(0x22FDE047)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swipe, size: 16, color: Color(0xFFFDE047)),
                          SizedBox(width: 6),
                          Text(
                            '좌우로 스와이프하여 전환하세요',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Color(0xFFFDE047),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_devices.length, (index) {
                        final bool active = index == _currentDeviceIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 38 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFFDE047)
                                : const Color(0xFF27354D),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentDeviceIndex = index;
                          });
                        },
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onLongPress: () {
                                HapticFeedback.heavyImpact();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const VoiceListeningScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  20,
                                  22,
                                  20,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x4027354D),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: const Color(0x22FDE047),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x26000000),
                                      blurRadius: 28,
                                      offset: Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    width: 380,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 140,
                                          height: 140,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF27354D),
                                                Color(0xFF1C2A41),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              34,
                                            ),
                                            border: Border.all(
                                              color: const Color(0x26FFFFFF),
                                            ),
                                          ),
                                          child: Icon(
                                            device.icon,
                                            color: const Color(0xFFFDE047),
                                            size: 74,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          device.name,
                                          style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            height: 1.1,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 9,
                                              height: 9,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF3BF7FF),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              device.status,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0x99D6E3FF),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        const Text(
                                          '기기를 3초간 길게 누르면\n음성 명령이 시작됩니다',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.2,
                                            color: Color(0x99CEC6AD),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              );
                            },
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Color(0x88D6E3FF),
                            ),
                          ),
                          const Text(
                            'SWIPE TO SWITCH',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: Color(0x80D6E3FF),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              );
                            },
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Color(0x88D6E3FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 98,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 18),
              decoration: const BoxDecoration(
                color: Color(0xE6041329),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _bottomTab(
                        index: 0,
                        icon: Icons.dashboard_rounded,
                        label: 'STATUS',
                        active: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _bottomTab(
                        index: 1,
                        icon: Icons.router_rounded,
                        label: 'DEVICES',
                        active: false,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _bottomTab(
                        index: 2,
                        icon: Icons.mic_rounded,
                        label: 'VOICE',
                        active: false,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _bottomTab(
                        index: 3,
                        icon: Icons.settings_suggest_rounded,
                        label: 'SETUP',
                        active: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
