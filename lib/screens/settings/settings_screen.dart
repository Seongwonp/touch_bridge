import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tts_service.dart';
import '../connection/device_connect_screen.dart';
import '../home/home_screen.dart';
import '../voice/voice_listening_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _ttsService = TtsService();

  Timer? _navResetTimer;
  int? _armedNavIndex;

  late double _speed;
  double _volume = 85;
  bool _guardianMode = true;

  @override
  void initState() {
    super.initState();
    _speed = _ttsService.speed;
  }

  Future<void> _announce(String message) async {
    await _ttsService.speak(message);
  }

  Future<void> _handleBottomTap(int index) async {
    const List<String> labels = ['홈', '기기', '음성', '설정'];

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

      await _announce('${labels[index]} 탭입니다. 다시 한 번 누르면 이동합니다.');
      return;
    }

    _navResetTimer?.cancel();
    setState(() {
      _armedNavIndex = null;
    });
    await _ttsService.stop();

    if (!mounted) {
      return;
    }

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        );
        break;
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
        return;
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
      onTap: () {
        _handleBottomTap(index);
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFDE047) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isArmed ? Colors.white : Colors.transparent,
            width: isArmed ? 2.5 : 0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF726300) : const Color(0xFF94A3B8),
              size: 22,
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
                    : const Color(0xFF94A3B8),
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
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      body: SafeArea(
        child: Column(
          children: [
            // TopAppBar: duplicate menu icon removed, only one left icon remains.
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x33FDE047))),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.menu, color: Color(0xFFFDE047)),
                    tooltip: '메뉴',
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Touch Bridge',
                    style: TextStyle(
                      color: Color(0xFFFDE047),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1C32),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.mic, color: Color(0xFFE2C62D)),
                            SizedBox(width: 8),
                            Text(
                              '음성 안내 설정',
                              style: TextStyle(
                                color: Color(0xFFD6E3FF),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF112036),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '속도',
                                    style: TextStyle(
                                      color: Color(0xFFCEC6AD),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_speed.toStringAsFixed(1)}x',
                                    style: const TextStyle(
                                      color: Color(0xFFE2C62D),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _speed,
                                min: 0.5,
                                max: 2.0,
                                divisions: 15,
                                onChanged: (value) {
                                  setState(() {
                                    _speed = value;
                                  });
                                  _ttsService.setSpeed(value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF112036),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '음량',
                                    style: TextStyle(
                                      color: Color(0xFFCEC6AD),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_volume.round()}%',
                                    style: const TextStyle(
                                      color: Color(0xFFE2C62D),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _volume,
                                min: 0,
                                max: 100,
                                divisions: 100,
                                onChanged: (value) {
                                  setState(() {
                                    _volume = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1C32),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.vibration,
                              color: Color(0xFFE2C62D),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '연결된 장치',
                              style: TextStyle(
                                color: Color(0xFFD6E3FF),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _announce('장치 추가 버튼입니다.'),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF27354C),
                                foregroundColor: const Color(0xFFE2C62D),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text(
                                '추가',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF112036),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.watch, color: Color(0xFFB6C6ED)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lumina Band',
                                      style: TextStyle(
                                        color: Color(0xFFD6E3FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '연결됨 • 92%',
                                      style: TextStyle(
                                        color: Color(0xFF38DEBB),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Color(0xFFCEC6AD),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF112036),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.hearing, color: Color(0xFF97917A)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Audio Pro',
                                      style: TextStyle(
                                        color: Color(0xFFD6E3FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '연결 해제됨',
                                      style: TextStyle(
                                        color: Color(0xFF97917A),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.link_off, color: Color(0xFF97917A)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1C2A41), Color(0xFF0D1C32)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x22FDE047)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '가디언 모드',
                                    style: TextStyle(
                                      color: Color(0xFFE2C62D),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const Spacer(),
                                  Switch(
                                    value: _guardianMode,
                                    onChanged: (value) {
                                      setState(() {
                                        _guardianMode = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _guardianMode
                                          ? const Color(0xFF38DEBB)
                                          : const Color(0xFF97917A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _guardianMode ? '활성화 중' : '비활성화',
                                    style: const TextStyle(
                                      color: Color(0xFFD6E3FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x3393000A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x44FFB4AB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.emergency_share,
                                    color: Color(0xFFFFB4AB),
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '비상 연락',
                                    style: TextStyle(
                                      color: Color(0xFFFFB4AB),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D1C32),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundImage: NetworkImage(
                                        'https://lh3.googleusercontent.com/aida-public/AB6AXuAsoHDkv5rqBL3f57DsOPmLGn-YHjeHVMSW3tlUolCm38UFXVDm6C3_lrqCsyggwt6BL7byGpLbUKmY3Md-V0iIiRq10dtmNsPHnfjrI4lzfMLExqHBVoakMw164zBrTL2thf-u2JJSmDBGjoZBlgFz_hsN3SmXNj1jP0kwb1hCZAArJW0wiUwYU7Mfu0hR6HmlpqwXMSOag3ND6HbnK9ubcJ5dK6YOp875zynNzH4SqeCAx6o41ccGoFYVNvbM2wbI0FF4G0TgtL5w',
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '김지수',
                                            style: TextStyle(
                                              color: Color(0xFFD6E3FF),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '+82 10-....',
                                            style: TextStyle(
                                              color: Color(0xFFCEC6AD),
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _announce('긴급 통화 버튼입니다.'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0x55FFB4AB),
                                    ),
                                    foregroundColor: const Color(0xFFFFB4AB),
                                  ),
                                  icon: const Icon(Icons.call, size: 16),
                                  label: const Text(
                                    '긴급통화',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
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
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1C32), Color(0xFF041329)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _bottomItem(
                    index: 0,
                    icon: Icons.home_filled,
                    label: 'HOME',
                    active: false,
                  ),
                  _bottomItem(
                    index: 1,
                    icon: Icons.vibration,
                    label: 'DEVICES',
                    active: false,
                  ),
                  _bottomItem(
                    index: 2,
                    icon: Icons.mic,
                    label: 'VOICE',
                    active: false,
                  ),
                  _bottomItem(
                    index: 3,
                    icon: Icons.settings,
                    label: 'SETTINGS',
                    active: true,
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
