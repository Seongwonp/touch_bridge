import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/active_device_service.dart';
import '../../services/ble_service.dart';
import '../../services/home_device_store.dart';
import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../connection/device_connect_screen.dart';
import '../settings/widgets/settings_form_widgets.dart';
import 'guardian_device_screen.dart';

/// 보호자 설정. 가전 등록·버튼 위치·장치 점검을 한곳에 모은다.
///
/// 예전에는 "보호자 모드"를 켜야 홈 카드 길게 누르기, 조작 메뉴의 좌표 매핑, 하단
/// "기기 관리" 탭처럼 사용자 화면 여기저기에 보호자 기능이 끼어들었다. 사용자는 쓸 일 없는
/// 메뉴를 지나야 했고, 보호자는 기능을 찾기 어려웠다. 이제 보호자 기능은 이 화면에서만 연다.
class GuardianHubScreen extends StatefulWidget {
  const GuardianHubScreen({super.key});

  @override
  State<GuardianHubScreen> createState() => _GuardianHubScreenState();
}

class _GuardianHubScreenState extends State<GuardianHubScreen> {
  final TtsService _tts = TtsService();
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  bool _homing = false;

  @override
  void initState() {
    super.initState();
    ActiveDeviceService.instance.deviceListUpdateNotifier.addListener(_load);
    _load();
    _tts.speak(
      '보호자 설정입니다. 가전 추가, 버튼 위치 수정, 장치 점검을 여기서 합니다.',
      source: 'GuardianHubScreen',
      priority: TtsPriority.navigation,
    );
  }

  @override
  void dispose() {
    ActiveDeviceService.instance.deviceListUpdateNotifier.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final devices = await HomeDeviceStore.loadDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _loading = false;
    });
  }

  Future<void> _addAppliance() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DeviceConnectScreen()),
    );
    await _load();
  }

  Future<void> _openDevice(String id) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GuardianDeviceScreen(deviceId: id)),
    );
    await _load();
  }

  Future<void> _home() async {
    if (_homing) return;
    final ble = BleService.instance;
    if (!ble.isConnected) {
      _tts.speak(
        'Touch Bridge가 연결되어 있지 않습니다. 가전을 고른 뒤 연결할 Touch Bridge를 확인하세요.',
        interrupt: true,
        priority: TtsPriority.result,
      );
      _snack('Touch Bridge가 연결되어 있지 않습니다.');
      return;
    }
    // 장치가 실제로 움직인다. 패널을 만지며 위치를 맞추는 중에 잘못 눌러 움직이지 않게 묻는다.
    _tts.speak(
      '원점 복귀를 하면 장치가 모서리로 움직입니다. 장치에서 손을 떼고 이동을 누르세요.',
      interrupt: true,
      priority: TtsPriority.result,
    );
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          '원점 복귀',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          '장치가 모서리로 움직입니다.\n장치에서 손을 떼고 진행하세요.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('이동'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _homing = true);
    _tts.speak('원점으로 돌아갑니다.', interrupt: true, priority: TtsPriority.result);
    final ok = await ble.sendHoming(ble.connectedDeviceId);
    if (!mounted) return;
    setState(() => _homing = false);
    final msg = ok ? '원점 복귀 명령을 기기에 전달했습니다.' : '원점 복귀 명령을 보내지 못했습니다.';
    _tts.speak(msg, priority: TtsPriority.result);
    _snack(msg);
  }

  void _snack(String msg) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final gap = ResponsiveScale.v(context, 24);
    final small = ResponsiveScale.v(context, 10);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: '보호자 설정', showBack: true),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : ListView(
                padding: EdgeInsets.all(ResponsiveScale.v(context, 20)),
                children: [
                  Text(
                    '가전 등록과 버튼 위치는 여기서만 바꿉니다. 사용자 화면에는 나오지 않습니다.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14 * rs,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: gap),
                  const SectionLabel(
                    icon: Icons.kitchen_rounded,
                    label: '가전',
                  ),
                  SizedBox(height: small),
                  SettingsCard(
                    children: [
                      for (final d in _devices) ...[
                        _DeviceRow(
                          device: d,
                          onTap: () => _openDevice(d['id'] as String? ?? ''),
                        ),
                        const SettingsDivider(),
                      ],
                      NavRow(
                        icon: Icons.add_circle_outline_rounded,
                        title: '가전 추가',
                        subtitle: 'Touch Bridge를 연결하고 가전과 버튼 위치를 등록합니다',
                        onTap: _addAppliance,
                      ),
                    ],
                  ),
                  SizedBox(height: gap),
                  const SectionLabel(
                    icon: Icons.build_circle_rounded,
                    label: '장치 점검',
                  ),
                  SizedBox(height: small),
                  SettingsCard(
                    children: [
                      StreamBuilder<bool>(
                        stream: BleService.instance.isConnectedStream,
                        initialData: BleService.instance.isConnected,
                        builder: (context, snap) {
                          final on = snap.data ?? false;
                          return NavRow(
                            icon: on
                                ? Icons.bluetooth_connected_rounded
                                : Icons.bluetooth_disabled_rounded,
                            title: _homing ? '원점 복귀 중…' : '원점 복귀',
                            subtitle: on
                                ? '연결됨: ${BleService.instance.connectedDeviceName}. 눌러서 원점으로 보냅니다'
                                : 'Touch Bridge가 연결되어 있지 않습니다',
                            onTap: _home,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.onTap});

  final Map<String, dynamic> device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = device['name'] as String? ?? '알 수 없는 기기';
    final bleName = device['bleName'] as String?;
    return NavRow(
      icon: iconFromCodePoint(device['iconCodePoint']),
      title: name,
      subtitle: bleName == null
          ? '연결할 Touch Bridge 없음 · 눌러서 설정'
          : '$bleName · 눌러서 버튼 위치·이름·삭제',
      onTap: onTap,
    );
  }
}
