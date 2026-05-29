import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../control/remote_control_screen.dart';
import '../voice/voice_listening_screen.dart';
import 'appliance_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts _tts = FlutterTts();
  final PageController _pageController = PageController(viewportFraction: 0.9);

  int _currentDeviceIndex = 0;

  final List<({String name, String status, IconData icon})> _devices = const [
    (name: '스마트 전자레인지', status: '작동 대기 중', icon: Icons.microwave_rounded),
    (name: '스마트 공기청정기', status: '공기 질 분석 중', icon: Icons.air_rounded),
    (name: '스마트 전등 허브', status: '원격 제어 가능', icon: Icons.light_mode_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _announceScreen();
  }

  Future<void> _announceScreen() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45);
    await _tts.speak('홈 화면입니다. 기기를 선택하여 제어하세요.');
  }

  @override
  void dispose() {
    _tts.stop();
    _pageController.dispose();
    super.dispose();
  }

  void _openDeviceControl(int index) {
    HapticFeedback.lightImpact();
    final device = _devices[index];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ControlModeSheet(
        deviceName: device.name,
        deviceIcon: device.icon,
        onVoice: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const VoiceListeningScreen(),
            ),
          );
        },
        onManual: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RemoteControlScreen(),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const TopAppBar(title: 'Touch Bridge'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveScale.v(context, 20),
                  ResponsiveScale.v(context, 20),
                  ResponsiveScale.v(context, 20),
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '내 기기',
                          style: TextStyle(
                            fontSize: 28 * rs,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 4)),
                        Text(
                          '기기를 눌러 제어하세요',
                          style: TextStyle(
                            fontSize: 14 * rs,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    // 페이지 인디케이터
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_devices.length + 1, (index) {
                        final bool active = index == _currentDeviceIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: EdgeInsets.symmetric(horizontal: 4 * rs),
                          width: active ? 32 * rs : 8 * rs,
                          height: 4 * rs,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFFFEB00)
                                : const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(2 * rs),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentDeviceIndex = index;
                          });
                          HapticFeedback.selectionClick();
                          if (index < _devices.length) {
                            _tts.speak('${_devices[index].name}. ${_devices[index].status}. 선택하려면 누르세요.');
                          } else {
                            _tts.speak('새 기기 추가하기. 버튼을 눌러 새로운 기기를 등록하세요.');
                          }
                        },
                        itemCount: _devices.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _devices.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6 * rs),
                              child: Semantics(
                                label: '새 기기 추가하기. 터치 브리지를 새로운 가전에 연결합니다.',
                                button: true,
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.mediumImpact();
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const ApplianceSelectionScreen()),
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(28 * rs),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1A),
                                      borderRadius: BorderRadius.circular(24 * rs),
                                      border: Border.all(color: const Color(0xFFFFEB00), width: 2 * rs),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 100 * rs,
                                          height: 100 * rs,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2A2A2A),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.add_rounded,
                                              color: const Color(0xFFFFEB00),
                                              size: 64 * rs,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: ResponsiveScale.v(context, 32)),
                                        Text(
                                          '새 기기 추가하기',
                                          style: TextStyle(
                                            fontSize: 24 * rs,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFFFEB00),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: ResponsiveScale.v(context, 12)),
                                        Text(
                                          '터치 브리지를 새로운 가전에\n연결하고 매핑을 시작합니다',
                                          style: TextStyle(
                                            fontSize: 14 * rs,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF888888),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final device = _devices[index];
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6 * rs),
                            child: Semantics(
                              label: '${device.name}. 현재 상태 ${device.status}. 선택하려면 두 번 누르세요.',
                              button: true,
                              child: GestureDetector(
                                onTap: () => _openDeviceControl(index),
                                child: Container(
                                  padding: EdgeInsets.all(28 * rs),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111111),
                                    borderRadius: BorderRadius.circular(24 * rs),
                                    border: Border.all(color: const Color(0xFF2A2A2A)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 120 * rs,
                                        height: 120 * rs,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A1A1A),
                                          borderRadius: BorderRadius.circular(24 * rs),
                                          border: Border.all(color: const Color(0xFF333333)),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            device.icon,
                                            color: const Color(0xFFFFEB00),
                                            size: 56 * rs,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: ResponsiveScale.v(context, 24)),
                                      Text(
                                        device.name,
                                        style: TextStyle(
                                          fontSize: 26 * rs,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: ResponsiveScale.v(context, 10)),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 8 * rs,
                                            height: 8 * rs,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF00FF88),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 8 * rs),
                                          Text(
                                            device.status,
                                            style: TextStyle(
                                              fontSize: 15 * rs,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFAAAAAA),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: ResponsiveScale.v(context, 28)),
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(vertical: 14 * rs),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEB00),
                                          borderRadius: BorderRadius.circular(12 * rs),
                                        ),
                                        child: Text(
                                          '눌러서 제어하기',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15 * rs,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // 하단 스와이프 안내
                    Padding(
                      padding: EdgeInsets.only(
                        top: ResponsiveScale.v(context, 12),
                        bottom: ResponsiveScale.v(context, 8),
                      ),
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
                            icon: Icon(
                              Icons.chevron_left_rounded,
                              color: const Color(0xFF555555),
                              size: 28 * rs,
                            ),
                          ),
                          Text(
                            '좌우로 밀어서 기기 전환',
                            style: TextStyle(
                              fontSize: 12 * rs,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: const Color(0xFF555555),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              );
                            },
                            icon: Icon(
                              Icons.chevron_right_rounded,
                              color: const Color(0xFF555555),
                              size: 28 * rs,
                            ),
                          ),
                        ],
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

class _ControlModeSheet extends StatelessWidget {
  const _ControlModeSheet({
    required this.deviceName,
    required this.deviceIcon,
    required this.onVoice,
    required this.onManual,
  });

  final String deviceName;
  final IconData deviceIcon;
  final VoidCallback onVoice;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28 * rs)),
        border: const Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      padding: EdgeInsets.fromLTRB(24 * rs, 16 * rs, 24 * rs, 40 * rs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40 * rs,
            height: 4 * rs,
            decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2 * rs),
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(deviceIcon, color: const Color(0xFFFFEB00), size: 32 * rs),
              SizedBox(width: 12 * rs),
              Text(
                deviceName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22 * rs,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveScale.v(context, 8)),
          Text(
            '제어 방식을 선택하세요',
            style: TextStyle(
              color: const Color(0xFF888888),
              fontSize: 14 * rs,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 24)),
          SizedBox(
            width: double.infinity,
            height: 72 * rs,
            child: ElevatedButton.icon(
              onPressed: onVoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFEB00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16 * rs),
                ),
                elevation: 0,
              ),
              icon: Icon(Icons.mic_rounded, size: 28 * rs),
              label: Text(
                '음성으로 제어',
                style: TextStyle(fontSize: 20 * rs, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 12)),
          SizedBox(
            width: double.infinity,
            height: 72 * rs,
            child: ElevatedButton.icon(
              onPressed: onManual,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xFFFFEB00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16 * rs),
                  side: BorderSide(color: const Color(0xFFFFEB00), width: 2 * rs),
                ),
                elevation: 0,
              ),
              icon: Icon(Icons.touch_app_rounded, size: 28 * rs),
              label: Text(
                '수동으로 조작',
                style: TextStyle(fontSize: 20 * rs, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
