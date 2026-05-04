import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/accessibility_settings.dart';
import '../../services/tts_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _tts = TtsService();
  double _speed = 1.2;
  double _volume = 85;
  bool _guardianMode = true;
  late bool _voiceGuidanceEnabled;
  late bool _largeTextEnabled;
  late bool _highContrastEnabled;

  @override
  void initState() {
    super.initState();
    final settings = AccessibilitySettings.instance;
    _voiceGuidanceEnabled = settings.voiceGuidanceEnabled;
    _largeTextEnabled = settings.largeTextEnabled;
    _highContrastEnabled = settings.highContrastEnabled;
    _announce('설정 화면입니다. 음성 안내 속도, 음량, 가디언 모드 및 비상 연락처를 설정할 수 있습니다.');
  }

  Future<void> _announce(String message) async {
    await _tts.speak(message);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
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
              child: Semantics( // 앱 타이틀 Semantics 추가
                label: 'Touch Bridge 앱',
                child: const Row(
                  children: [
                    Text(
                      'Touch Bridge',
                      style: TextStyle(
                        color: Color(0xFFFFEB00),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Semantics( // 화면 타이틀 Semantics 추가
                    label: '설정',
                    header: true, // 헤더로 인식되도록 설정
                    child: const Text(
                      '설정',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 음성 안내 섹션
                  _SectionLabel(
                    icon: Icons.record_voice_over_rounded,
                    label: '음성 안내',
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      _SliderRow(
                        label: '속도',
                        value: _speed,
                        min: 0.5,
                        max: 2.0,
                        display: '${_speed.toStringAsFixed(1)}x',
                        onChanged: (v) {
                          setState(() => _speed = v);
                          _announce('음성 안내 속도 ${_speed.toStringAsFixed(1)}배속');
                        },
                      ),
                      const _Divider(),
                      _SliderRow(
                        label: '음량',
                        value: _volume,
                        min: 0,
                        max: 100,
                        display: '${_volume.round()}%',
                        onChanged: (v) {
                          setState(() => _volume = v);
                          _announce('음성 안내 음량 ${_volume.round()}%');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _SectionLabel(
                    icon: Icons.accessibility_new_rounded,
                    label: '접근성',
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      _SwitchRow(
                        title: '음성 안내',
                        subtitle: '화면 이동/상태 변화를 음성으로 안내',
                        value: _voiceGuidanceEnabled,
                        onChanged: (v) {
                          setState(() => _voiceGuidanceEnabled = v);
                          AccessibilitySettings.instance.setVoiceGuidanceEnabled(v);
                          _announce('음성 안내 ${v ? '켜짐' : '꺼짐'}');
                        },
                      ),
                      const _Divider(),
                      _SwitchRow(
                        title: '큰 글씨',
                        subtitle: '텍스트를 크게 표시하여 가독성 향상',
                        value: _largeTextEnabled,
                        onChanged: (v) {
                          setState(() => _largeTextEnabled = v);
                          AccessibilitySettings.instance.setLargeTextEnabled(v);
                          _announce('큰 글씨 ${v ? '켜짐' : '꺼짐'}');
                        },
                      ),
                      const _Divider(),
                      _SwitchRow(
                        title: '고대비 모드',
                        subtitle: '텍스트 대비를 높여 인지성 향상',
                        value: _highContrastEnabled,
                        onChanged: (v) {
                          setState(() => _highContrastEnabled = v);
                          AccessibilitySettings.instance.setHighContrastEnabled(v);
                          _announce('고대비 모드 ${v ? '켜짐' : '꺼짐'}');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 가디언 모드 섹션
                  _SectionLabel(
                    icon: Icons.shield_rounded,
                    label: '가디언 모드',
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Semantics( // 가디언 모드 스위치 Semantics 추가
                          label: '보호자 알림 스위치. 현재 ${_guardianMode ? '켜짐' : '꺼짐'}. 이상 감지 시 보호자에게 알림 전송.',
                          button: true, // 스위치도 버튼처럼 동작하므로
                          child: Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '보호자 알림',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '이상 감지 시 보호자에게 알림 전송',
                                      style: TextStyle(
                                        color: Color(0xFF888888),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _guardianMode,
                                onChanged: (v) {
                                  setState(() => _guardianMode = v);
                                  _announce('보호자 알림 ${_guardianMode ? '켜짐' : '꺼짐'}');
                                },
                                activeThumbColor: Colors.black,
                                activeTrackColor: const Color(0xFFFFEB00),
                                inactiveThumbColor: const Color(0xFF555555),
                                inactiveTrackColor: const Color(0xFF2A2A2A),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 비상 연락처 섹션
                  _SectionLabel(
                    icon: Icons.emergency_rounded,
                    label: '비상 연락처',
                  ),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Semantics( // 비상 연락처 정보 Semantics 추가
                          label: '비상 연락처: 김지수, 자녀. 전화번호 010-1234-5678',
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF333333)),
                                ),
                                child: const Center(
                                  child: Text(
                                    '김',
                                    style: TextStyle(
                                      color: Color(0xFFFFEB00),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '김지수 (자녀)',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '010-1234-5678',
                                      style: TextStyle(
                                        color: Color(0xFF888888),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Semantics( // 전화 걸기 버튼 Semantics 추가
                                label: '김지수에게 전화 걸기 버튼',
                                button: true,
                                child: GestureDetector(
                                  onTap: () => _announce('긴급 전화를 연결합니다.'),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.call_rounded,
                                      color: Color(0xFFFF3B30),
                                      size: 22,
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

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics( // 섹션 라벨 Semantics 추가
      label: label,
      header: true,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFEB00), size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFEB00),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFF2A2A2A));
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics( // 슬라이더 행 Semantics 추가
      label: '$label. 현재 값 $display',
      slider: true,
      value: display,
      onIncrease: () => onChanged((value + (max - min) / 10).clamp(min, max)), // 10%씩 증가
      onDecrease: () => onChanged((value - (max - min) / 10).clamp(min, max)), // 10%씩 감소
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Text(
                    display,
                    style: const TextStyle(
                      color: Color(0xFFFFEB00),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
                activeColor: const Color(0xFFFFEB00),
                inactiveColor: const Color(0xFF2A2A2A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.black,
            activeTrackColor: const Color(0xFFFFEB00),
            inactiveThumbColor: const Color(0xFF555555),
            inactiveTrackColor: const Color(0xFF2A2A2A),
          ),
        ],
      ),
    );
  }
}
