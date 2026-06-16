import 'package:flutter/material.dart';
import '../../services/accessibility_settings.dart';
import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import 'ble_log_screen.dart';
import 'developer_console_screen.dart';
import 'device_management_screen.dart';
import '../../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _tts = TtsService();
  late double _speed;
  late double _volume;
  late bool _guardianModeEnabled;
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
    _guardianModeEnabled = s.guardianModeEnabled;
    _contactName = s.contactName;
    _contactPhone = s.contactPhone;
    _tts.speak('설정 화면입니다. 보호자 안내 모드를 조정할 수 있습니다.', source: 'SettingsScreen');
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
              hint: '예) 자녀',
              icon: Icons.person_rounded,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 14),
            _ContactField(
              controller: phoneCtrl,
              label: '전화번호',
              hint: '예) 010-0000-0000',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Color(0xFF888888))),
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
              Navigator.pop(ctx);
              _tts.speak('저장되었습니다.', source: 'SettingsScreen');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFEB00),
              foregroundColor: Colors.black,
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
    final rs = ResponsiveScale.factor(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: 'Touch Bridge'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(ResponsiveScale.v(context, 20)),
          children: [
            Text(
              '설정',
              style: TextStyle(
                fontSize: 28 * rs,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            _SectionLabel(
              icon: Icons.record_voice_over_rounded,
              label: '음성 안내',
            ),
            SizedBox(height: ResponsiveScale.v(context, 10)),
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
                  },
                ),
              ],
            ),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            _SectionLabel(icon: Icons.accessibility_new_rounded, label: '접근성'),
            SizedBox(height: ResponsiveScale.v(context, 10)),
            _SettingsCard(
              children: [
                _SwitchRow(
                  title: '음성 안내',
                  subtitle: '이동/상태 변화를 음성으로 안내',
                  value: _voiceGuidanceEnabled,
                  onChanged: (v) {
                    setState(() => _voiceGuidanceEnabled = v);
                    AccessibilitySettings.instance.setVoiceGuidanceEnabled(v);
                  },
                ),
                const _Divider(),
                _SwitchRow(
                  title: '큰 글씨',
                  subtitle: '가독성 향상',
                  value: _largeTextEnabled,
                  onChanged: (v) {
                    setState(() => _largeTextEnabled = v);
                    AccessibilitySettings.instance.setLargeTextEnabled(v);
                  },
                ),
                const _Divider(),
                _SwitchRow(
                  title: '고대비',
                  subtitle: '텍스트를 더 진하게 표시',
                  value: _highContrastEnabled,
                  onChanged: (v) {
                    setState(() => _highContrastEnabled = v);
                    AccessibilitySettings.instance.setHighContrastEnabled(v);
                  },
                ),
              ],
            ),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            _SectionLabel(icon: Icons.family_restroom_rounded, label: '보호자 설정'),
            SizedBox(height: ResponsiveScale.v(context, 10)),
            _SettingsCard(
              children: [
                _SwitchRow(
                  title: '보호자 안내 모드',
                  subtitle: '초기 세팅과 사용법을 더 자세히 안내',
                  value: _guardianModeEnabled,
                  onChanged: (v) {
                    setState(() => _guardianModeEnabled = v);
                    AccessibilitySettings.instance.setGuardianModeEnabled(v);
                    _tts.speak(
                      v ? '보호자 안내 모드가 켜졌습니다.' : '보호자 안내 모드가 꺼졌습니다.',
                      source: 'SettingsScreen',
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            _SectionLabel(icon: Icons.bug_report_rounded, label: '시스템'),
            SizedBox(height: ResponsiveScale.v(context, 10)),
            _SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.settings_bluetooth_rounded,
                    color: Color(0xFFFFEB00),
                  ),
                  title: Text(
                    '하드웨어(ESP32) 관리',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16 * rs,
                    ),
                  ),
                  subtitle: const Text(
                    '기기별 블루투스 연결 설정',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF555555),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DeviceManagementScreen()),
                  ),
                ),
                const _Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.list_alt_rounded,
                    color: Color(0xFFFFEB00),
                  ),
                  title: Text(
                    '통신 로그 확인',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16 * rs,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF555555),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BleLogScreen()),
                  ),
                ),
                const _Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.terminal_rounded,
                    color: Color(0xFFFFEB00),
                  ),
                  title: Text(
                    '개발자 콘솔',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16 * rs,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF555555),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DeveloperConsoleScreen()),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            _SectionLabel(icon: Icons.emergency_rounded, label: '비상 연락처'),
            SizedBox(height: ResponsiveScale.v(context, 10)),
            _SettingsCard(
              children: [
                Padding(
                  padding: EdgeInsets.all(ResponsiveScale.v(context, 16)),
                  child: _contactName.isEmpty
                      ? _EmptyContactRow(onTap: _showContactEditDialog)
                      : _ContactRow(
                          name: _contactName,
                          phone: _contactPhone,
                          onCall: () =>
                              _tts.speak('연결합니다.', source: 'SettingsScreen'),
                          onEdit: _showContactEditDialog,
                        ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveScale.v(context, 40)),
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
    final rs = ResponsiveScale.factor(context);
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFEB00), size: 18 * rs),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFFFFEB00),
            fontSize: 13 * rs,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16 * rs),
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
    final rs = ResponsiveScale.factor(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16 * rs, 14 * rs, 16 * rs, 6 * rs),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17 * rs,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                display,
                style: TextStyle(
                  color: const Color(0xFFFFEB00),
                  fontWeight: FontWeight.w800,
                  fontSize: 14 * rs,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: const Color(0xFFFFEB00),
            inactiveColor: const Color(0xFF2A2A2A),
          ),
        ],
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
    final rs = ResponsiveScale.factor(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * rs, vertical: 4 * rs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17 * rs,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: const Color(0xFF888888),
                    fontSize: 13 * rs,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFFFEB00),
          ),
        ],
      ),
    );
  }
}

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
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFFFFEB00), size: 20),
            filled: true,
            fillColor: const Color(0xFF111111),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    return InkWell(
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
              ),
            ),
            child: const Icon(Icons.add_rounded, color: Color(0xFFFFEB00)),
          ),
          const SizedBox(width: 14),
          const Column(
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
              Text(
                '보호자를 등록하세요',
                style: TextStyle(color: Color(0xFF888888), fontSize: 13),
              ),
            ],
          ),
        ],
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
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0] : '?',
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
              Text(
                phone,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded, color: Color(0xFF888888)),
        ),
        IconButton(
          onPressed: onCall,
          icon: const Icon(Icons.call_rounded, color: Color(0xFFFF3B30)),
        ),
      ],
    );
  }
}
