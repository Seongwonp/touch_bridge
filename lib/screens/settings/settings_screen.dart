import 'package:flutter/material.dart';
import '../../services/accessibility_settings.dart';
import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import 'ble_log_screen.dart';
import 'developer_console_screen.dart';
import 'device_management_screen.dart';
import '../connection/device_connect_screen.dart';
import '../voice/voice_listening_screen.dart';
import '../../theme/app_colors.dart';
import 'widgets/settings_form_widgets.dart';

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
  late bool _developerModeEnabled;
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
    _developerModeEnabled = s.developerModeEnabled;
    _contactName = s.contactName;
    _contactPhone = s.contactPhone;
    _tts.speak(
      '설정입니다. 음성 속도, 보호자 모드, 개발자 모드를 변경할 수 있습니다.',
      source: 'SettingsScreen',
    );
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
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '비상 연락처 편집',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ContactField(
              controller: nameCtrl,
              label: '이름',
              hint: '예) 자녀',
              icon: Icons.person_rounded,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 14),
            ContactField(
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
            child: const Text('취소', style: TextStyle(color: AppColors.textTertiary)),
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
              backgroundColor: AppColors.primary,
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
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            SectionLabel(
              icon: Icons.record_voice_over_rounded,
              label: '음성 안내',
            ),
            SizedBox(height: ResponsiveScale.v(context, 10)),
            SettingsCard(
              children: [
                SliderRow(
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
                const SettingsDivider(),
                SliderRow(
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
            SectionLabel(icon: Icons.accessibility_new_rounded, label: '접근성'),
            SizedBox(height: ResponsiveScale.v(context, 10)),
            SettingsCard(
              children: [
                SwitchRow(
                  title: '음성 안내',
                  subtitle: '이동/상태 변화를 음성으로 안내',
                  value: _voiceGuidanceEnabled,
                  onChanged: (v) {
                    setState(() => _voiceGuidanceEnabled = v);
                    AccessibilitySettings.instance.setVoiceGuidanceEnabled(v);
                  },
                ),
                const SettingsDivider(),
                SwitchRow(
                  title: '큰 글씨',
                  subtitle: '가독성 향상',
                  value: _largeTextEnabled,
                  onChanged: (v) {
                    setState(() => _largeTextEnabled = v);
                    AccessibilitySettings.instance.setLargeTextEnabled(v);
                  },
                ),
                const SettingsDivider(),
                SwitchRow(
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
            SectionLabel(icon: Icons.family_restroom_rounded, label: '보호자 설정'),
            SizedBox(height: ResponsiveScale.v(context, 10)),
            SettingsCard(
              children: [
                SwitchRow(
                  title: '보호자 안내 모드',
                  subtitle: '초기 세팅과 사용법을 더 자세히 안내',
                  value: _guardianModeEnabled,
                  onChanged: (v) {
                    setState(() => _guardianModeEnabled = v);
                    AccessibilitySettings.instance.setGuardianModeEnabled(v);
                    _tts.speak(
                      v
                          ? '보호자 모드를 켰습니다. 기기 관리와 매핑에 접근할 수 있습니다.'
                          : '보호자 모드를 껐습니다. 기기 추가와 매핑은 숨겨집니다.',
                      source: 'SettingsScreen',
                    );
                  },
                ),
                if (_guardianModeEnabled) ...[
                  const SettingsDivider(),
                  NavRow(
                    icon: Icons.add_link_rounded,
                    title: '기기 추가 및 연결',
                    subtitle: 'QR, 블루투스, NFC로 새 기기 등록',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeviceConnectScreen(),
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  NavRow(
                    icon: Icons.settings_bluetooth_rounded,
                    title: '기기 및 하드웨어 관리',
                    subtitle: '등록된 기기와 ESP32 연결 설정',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeviceManagementScreen(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            SectionLabel(icon: Icons.developer_mode_rounded, label: '개발자 설정'),
            SizedBox(height: ResponsiveScale.v(context, 10)),
            SettingsCard(
              children: [
                SwitchRow(
                  title: '개발자 모드',
                  subtitle: 'ESP 선택, 조이스틱, raw 명령, 통신 로그 표시',
                  value: _developerModeEnabled,
                  onChanged: (v) {
                    setState(() => _developerModeEnabled = v);
                    AccessibilitySettings.instance.setDeveloperModeEnabled(v);
                    _tts.speak(
                      v
                          ? '개발자 모드를 켰습니다. 콘솔과 로그 도구를 사용할 수 있습니다.'
                          : '개발자 모드를 껐습니다. 개발자 도구가 숨겨집니다.',
                      source: 'SettingsScreen',
                    );
                  },
                ),
              ],
            ),
            if (_developerModeEnabled) ...[
              SizedBox(height: ResponsiveScale.v(context, 24)),
              SectionLabel(icon: Icons.bug_report_rounded, label: '개발자/시연 도구'),
              SizedBox(height: ResponsiveScale.v(context, 10)),
              SettingsCard(
                children: [
                  NavRow(
                    icon: Icons.mic_external_on_rounded,
                    title: '음성 테스트 화면',
                    subtitle: '음성 명령 인식과 AI 파싱 확인',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VoiceListeningScreen(),
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  NavRow(
                    icon: Icons.list_alt_rounded,
                    title: '통신 로그 확인',
                    subtitle: 'BLE 송수신 로그 확인',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BleLogScreen()),
                    ),
                  ),
                  const SettingsDivider(),
                  NavRow(
                    icon: Icons.terminal_rounded,
                    title: '개발자 콘솔',
                    subtitle: '조이스틱과 raw 명령 전송',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DeveloperConsoleScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: ResponsiveScale.v(context, 24)),
            SectionLabel(icon: Icons.emergency_rounded, label: '비상 연락처'),
            SizedBox(height: ResponsiveScale.v(context, 10)),
            SettingsCard(
              children: [
                Padding(
                  padding: EdgeInsets.all(ResponsiveScale.v(context, 16)),
                  child: _contactName.isEmpty
                      ? EmptyContactRow(onTap: _showContactEditDialog)
                      : ContactRow(
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
