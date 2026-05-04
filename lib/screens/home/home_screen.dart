import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/tts_service.dart';

import '../control/remote_control_screen.dart';
import '../voice/voice_listening_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TtsService _tts = TtsService();
  final PageController _pageController = PageController(viewportFraction: 0.92);

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
    // 초기 화면 진입 시 첫 번째 기기 정보와 함께 화면 안내
    await _tts.speak('홈 화면입니다. 현재 ${_devices[_currentDeviceIndex].name}, 상태: ${_devices[_currentDeviceIndex].status}. 좌우로 밀어서 기기를 전환하고, 기기를 눌러 제어하세요.');
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: const Row(
                children: [
                  Text(
                    'Touch Bridge',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: Color(0xFFFFEB00),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '내 기기',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '기기를 눌러 제어하세요',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 페이지 인디케이터
                    Semantics( // 페이지 인디케이터 Semantics 추가
                      label: '현재 ${_currentDeviceIndex + 1}번째 기기, 총 ${_devices.length}개 기기',
                      liveRegion: true, // 내용 변경 시 스크린 리더가 자동으로 읽도록 설정
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_devices.length, (index) {
                          final bool active = index == _currentDeviceIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 32 : 8,
                            height: 4,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFFFFEB00)
                                  : const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentDeviceIndex = index;
                          });
                          HapticFeedback.selectionClick();
                          _tts.speak('${_devices[index].name}, 상태: ${_devices[index].status}'); // 기기 전환 시 상세 안내
                        },
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Semantics( // 기기 카드 Semantics 추가
                              label: '${device.name}, 상태: ${device.status}. 눌러서 제어 모드 선택.',
                              button: true,
                              child: GestureDetector(
                                onTap: () => _openDeviceControl(index),
                                child: Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111111),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: const Color(0xFF2A2A2A)),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 120,
                                                height: 120,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1A1A1A),
                                                  borderRadius: BorderRadius.circular(24),
                                                  border: Border.all(color: const Color(0xFF333333)),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    device.icon,
                                                    color: const Color(0xFFFFEB00),
                                                    size: 56,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              Text(
                                                device.name,
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                  height: 1.2,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF00FF88),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    device.status,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFFAAAAAA),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 28),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFEB00),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  '눌러서 제어하기',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
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
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Semantics( // 이전 기기 버튼 Semantics 추가
                            label: '이전 기기',
                            button: true,
                            child: IconButton(
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                );
                              },
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                color: Color(0xFF555555),
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8), // 아이콘 버튼 사이 간격 조정
                          const Text(
                            '좌우로 밀어서 기기 전환',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: Color(0xFF555555),
                            ),
                          ),
                          const SizedBox(width: 8), // 아이콘 버튼 사이 간격 조정
                          Semantics( // 다음 기기 버튼 Semantics 추가
                            label: '다음 기기',
                            button: true,
                            child: IconButton(
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                );
                              },
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF555555),
                                size: 28,
                              ),
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

class _ControlModeSheet extends StatefulWidget {
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
  State<_ControlModeSheet> createState() => _ControlModeSheetState();
}

class _ControlModeSheetState extends State<_ControlModeSheet> {
  final TtsService _tts = TtsService();
  Timer? _actionResetTimer;
  String? _armedAction;

  @override
  void initState() {
    super.initState();
    _tts.speak('${widget.deviceName} 제어 방식 선택 화면입니다. 원하는 버튼을 한 번 누르면 선택되고, 한 번 더 누르면 실행됩니다.');
  }

  @override
  void dispose() {
    _actionResetTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _armAndRun({
    required String id,
    required String guide,
    required VoidCallback onConfirmed,
  }) {
    if (_armedAction != id) {
      setState(() {
        _armedAction = id;
      });
      HapticFeedback.mediumImpact();
      _actionResetTimer?.cancel();
      _actionResetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _armedAction = null;
          });
        }
      });
      _tts.speak(guide);
      return;
    }

    _actionResetTimer?.cancel();
    setState(() {
      _armedAction = null;
    });
    onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Semantics( // 기기 이름 및 제어 방식 선택 안내 Semantics 추가
            label: '${widget.deviceName} 제어 방식을 선택하세요.',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.deviceIcon, color: const Color(0xFFFFEB00), size: 32),
                const SizedBox(width: 12),
                Text(
                  widget.deviceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const ExcludeSemantics( // 상위 Semantics에서 이미 안내하므로 중복 방지
            child: Text(
              '제어 방식을 선택하세요',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 72,
            child: Semantics( // 음성으로 제어 버튼 Semantics 추가
              label: '${widget.deviceName}을 음성으로 제어. ${_armedAction == 'voice' ? '선택됨. 한 번 더 탭하면 실행됩니다.' : ''}',
              button: true,
              child: ElevatedButton.icon(
                onPressed: () {
                  _armAndRun(
                    id: 'voice',
                    guide: '음성으로 제어 버튼입니다. 한 번 더 누르면 음성 인식 화면으로 이동합니다.',
                    onConfirmed: widget.onVoice,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEB00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _armedAction == 'voice' ? Colors.white : Colors.transparent,
                      width: _armedAction == 'voice' ? 2.5 : 0,
                    ),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.mic_rounded, size: 28),
                label: const Text(
                  '음성으로 제어',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 72,
            child: Semantics( // 수동으로 조작 버튼 Semantics 추가
              label: '${widget.deviceName}을 수동으로 조작. ${_armedAction == 'manual' ? '선택됨. 한 번 더 탭하면 실행됩니다.' : ''}',
              button: true,
              child: ElevatedButton.icon(
                onPressed: () {
                  _armAndRun(
                    id: 'manual',
                    guide: '수동으로 조작 버튼입니다. 한 번 더 누르면 수동 조작 화면으로 이동합니다.',
                    onConfirmed: widget.onManual,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: const Color(0xFFFFEB00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _armedAction == 'manual' ? Colors.white : const Color(0xFFFFEB00),
                      width: _armedAction == 'manual' ? 3 : 2,
                    ),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.touch_app_rounded, size: 28),
                label: const Text(
                  '수동으로 조작',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
