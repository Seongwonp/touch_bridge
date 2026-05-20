import 'package:flutter/material.dart';
import '../../services/accessibility_experiment_service.dart';
import '../../services/accessibility_settings.dart';
import '../../services/tts_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _tts = TtsService();
  late double _speed;
  late double _volume;
  bool _guardianMode = true;
  late bool _voiceGuidanceEnabled;
  late bool _largeTextEnabled;
  late bool _highContrastEnabled;
  late String _contactName;
  late String _contactPhone;

  @override
  void initState() {
    super.initState();
    final s = AccessibilitySettings.instance;
    _speed = s.ttsSpeed;
    _volume = s.ttsVolume;
    _voiceGuidanceEnabled = s.voiceGuidanceEnabled;
    _largeTextEnabled = s.largeTextEnabled;
    _highContrastEnabled = s.highContrastEnabled;
    _contactName = s.contactName;
    _contactPhone = s.contactPhone;
    _tts.speak('설정 화면입니다. 음성 안내 속도, 음량, 접근성, 비상 연락처를 설정할 수 있습니다.');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _showContactEditDialog() {
    final nameCtrl = TextEditingController(text: _contactName);
    final phoneCtrl = TextEditingController(text: _contactPhone);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '비상 연락처 편집',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ContactField(
              controller: nameCtrl,
              label: '이름',
              hint: '예) 김지수 (자녀)',
              icon: Icons.person_rounded,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 14),
            _ContactField(
              controller: phoneCtrl,
              label: '전화번호',
              hint: '예) 010-1234-5678',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '취소',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              AccessibilitySettings.instance.setContact(name, phone);
              setState(() {
                _contactName = name;
                _contactPhone = phone;
              });
              Navigator.of(ctx).pop();
              _tts.speak(
                name.isEmpty
                    ? '비상 연락처가 삭제되었습니다.'
                    : '$name, ${phone.isEmpty ? '전화번호 없음' : phone} 으로 저장되었습니다.',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFEB00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '저장',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
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
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2A2A)),
                ),
              ),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Touch Bridge',
                  style: TextStyle(
                    color: Color(0xFFFFEB00),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Semantics(
                    header: true,
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
                          TtsService().setSpeechRate(v);
                          AccessibilitySettings.instance.setTtsSpeed(v);
                          _tts.speak('음성 안내 속도 ${v.toStringAsFixed(1)}배속');
                        },
                      ),
                      const _Divider(),
                      _SliderRow(
                        label: '음량',
                        value: _volume,
                        min: 0.0,
                        max: 1.0,
                        display: '${(_volume * 100).round()}%',
                        onChanged: (v) {
                          setState(() => _volume = v);
                          TtsService().setVolume(v);
                          AccessibilitySettings.instance.setTtsVolume(v);
                          _tts.speak('음성 안내 음량 ${(v * 100).round()}퍼센트');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 접근성 섹션
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
                          _tts.speak('음성 안내 ${v ? '켜짐' : '꺼짐'}');
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
                          _tts.speak('큰 글씨 ${v ? '켜짐' : '꺼짐'}');
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
                          _tts.speak('고대비 모드 ${v ? '켜짐' : '꺼짐'}');
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
                        child: Semantics(
                          label:
                              '보호자 알림 스위치. 현재 ${_guardianMode ? '켜짐' : '꺼짐'}. 이상 감지 시 보호자에게 알림 전송.',
                          button: true,
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
                                  _tts.speak('보호자 알림 ${v ? '켜짐' : '꺼짐'}');
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

                  _SectionLabel(
                    icon: Icons.analytics_rounded,
                    label: '접근성 실험 지표',
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: AccessibilityExperimentService.instance,
                    builder: (context, child) {
                      final exp = AccessibilityExperimentService.instance;
                      return _SettingsCard(
                        children: [
                          _MetricRow(label: '총 작업 수', value: '${exp.totalTasks}회'),
                          const _Divider(),
                          _MetricRow(label: '완료율', value: '${exp.completionRate.toStringAsFixed(1)}%'),
                          const _Divider(),
                          _MetricRow(label: '평균 완료 시간', value: '${exp.averageCompletionSeconds.toStringAsFixed(1)}초'),
                          const _Divider(),
                          _MetricRow(label: '음성 작업', value: '${exp.voiceTasks}회'),
                          const _Divider(),
                          _MetricRow(label: '수동 작업', value: '${exp.manualTasks}회'),
                          const _Divider(),
                          _MetricRow(label: '비상 정지', value: '${exp.emergencyStops}회'),
                          const _Divider(),
                          _MetricRow(label: '이중탭 타임아웃', value: '${exp.doubleTapTimeouts}회'),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await AccessibilityExperimentService.instance.reset();
                                  _tts.speak('접근성 실험 지표를 초기화했습니다.');
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF555555)),
                                  foregroundColor: const Color(0xFFD1D5DB),
                                ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('지표 초기화'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      );
                    },
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
                        child: _contactName.isEmpty
                            ? _EmptyContactRow(
                                onTap: _showContactEditDialog,
                              )
                            : _ContactRow(
                                name: _contactName,
                                phone: _contactPhone,
                                onCall: () =>
                                    _tts.speak('긴급 전화를 연결합니다.'),
                                onEdit: _showContactEditDialog,
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

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFEB00),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 비상 연락처 UI ───────────────────────────────────────────

class _ContactField extends StatelessWidget {
  const _ContactField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF444444)),
            prefixIcon: Icon(icon, color: const Color(0xFFFFEB00), size: 20),
            filled: true,
            fillColor: const Color(0xFF111111),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFFEB00), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyContactRow extends StatelessWidget {
  const _EmptyContactRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '비상 연락처 없음. 탭하여 추가',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFEB00).withValues(alpha: 0.4),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFFFFEB00),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '연락처 추가',
                    style: TextStyle(
                      color: Color(0xFFFFEB00),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '비상 시 연락할 보호자를 등록하세요',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 13),
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

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.name,
    required this.phone,
    required this.onCall,
    required this.onEdit,
  });

  final String name;
  final String phone;
  final VoidCallback onCall;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0] : '?';
    return Semantics(
      label: '비상 연락처: $name. 전화번호 ${phone.isEmpty ? '없음' : phone}',
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
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Color(0xFFFFEB00),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  phone.isEmpty ? '전화번호 없음' : phone,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // 편집 버튼
          Semantics(
            label: '연락처 편집',
            button: true,
            child: GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF888888),
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 전화 버튼
          Semantics(
            label: '$name에게 전화 걸기',
            button: true,
            child: GestureDetector(
              onTap: onCall,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.call_rounded,
                  color: Color(0xFFFF3B30),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 공통 컴포넌트 ───────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: label,
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
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFF2A2A2A));
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
    return Semantics(
      label: '$label. 현재 값 $display',
      slider: true,
      value: display,
      onIncrease: () => onChanged((value + (max - min) / 10).clamp(min, max)),
      onDecrease: () => onChanged((value - (max - min) / 10).clamp(min, max)),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
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
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 10,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 20,
                ),
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
    return Semantics(
      label: '$title. $subtitle. 현재 ${value ? "켜짐" : "꺼짐"}.',
      button: true,
      child: Padding(
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
            ExcludeSemantics(
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.black,
                activeTrackColor: const Color(0xFFFFEB00),
                inactiveThumbColor: const Color(0xFF555555),
                inactiveTrackColor: const Color(0xFF2A2A2A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
