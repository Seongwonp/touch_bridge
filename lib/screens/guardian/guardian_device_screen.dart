import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/active_device_service.dart';
import '../../services/ble_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/home_device_store.dart';
import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../mapping/manual_mapping_screen.dart';
import '../mapping/mapping_image_source.dart';
import '../mapping/photo_mapping_screen.dart';
import '../settings/widgets/settings_form_widgets.dart';
import 'ble_scanner_sheet.dart';

/// 보호자 설정 · 가전 한 대.
///
/// 이 가전에 관한 설정을 모두 여기서 한다: 버튼 위치 수정(화살표·눌러보기), 사진으로
/// 버튼 다시 찾기, 이름·음성 별명, 연결할 Touch Bridge, 삭제.
/// 사용자(시각장애인) 화면에는 이 기능들이 나오지 않는다.
class GuardianDeviceScreen extends StatefulWidget {
  const GuardianDeviceScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<GuardianDeviceScreen> createState() => _GuardianDeviceScreenState();
}

class _GuardianDeviceScreenState extends State<GuardianDeviceScreen> {
  final TtsService _tts = TtsService();
  Map<String, dynamic>? _device;
  bool _loading = true;

  String get _name => _device?['name'] as String? ?? '기기';
  String? get _bleId => _device?['bleId'] as String?;
  String? get _bleName => _device?['bleName'] as String?;
  String? get _deviceType => _device?['deviceType'] as String?;
  List<String> get _aliases =>
      (_device?['aliases'] as List?)?.whereType<String>().toList() ?? const [];

  @override
  void initState() {
    super.initState();
    _load(announce: true);
  }

  Future<void> _load({bool announce = false}) async {
    final device = await HomeDeviceStore.findById(widget.deviceId);
    if (!mounted) return;
    setState(() {
      _device = device;
      _loading = false;
    });
    if (device == null) return;
    if (announce) {
      _tts.speak(
        '$_name 설정입니다. 버튼 위치 수정, 사진으로 다시 찾기, 이름 변경, 삭제를 할 수 있습니다.',
        source: 'GuardianDeviceScreen',
        priority: TtsPriority.navigation,
      );
    }
  }

  /// 매핑 화면은 활성 기기와 연결된 Touch Bridge로 이동·누름을 보낸다.
  /// 다른 가전이 활성이면 엉뚱한 프로필로 누를 수 있으니 이 가전을 먼저 활성으로 둔다.
  Future<void> _makeActive() async {
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: widget.deviceId,
      deviceName: _name,
      bleId: _bleId,
      bleName: _bleName,
      deviceType: _deviceType,
    );
  }

  Future<void> _openButtonPositions() async {
    HapticFeedback.selectionClick();
    await _makeActive();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ManualMappingScreen(
          deviceId: widget.deviceId,
          deviceName: _name,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openPhotoRemap() async {
    HapticFeedback.selectionClick();
    final picked = await chooseImageForMapping(
      context,
      tts: _tts,
      allowSample: false,
    );
    if (picked == null || picked.path == null || !mounted) return;
    await _makeActive();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoMappingScreen(
          deviceId: widget.deviceId,
          imagePath: picked.path,
          applianceName: _name,
          applianceType: _deviceType,
          bleId: _bleId,
          bleName: _bleName,
        ),
      ),
    );
    await _load();
  }

  Future<String?> _askText({
    required String title,
    required String initial,
    required String hint,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _TextPromptDialog(title: title, initial: initial, hint: hint),
    );
  }

  Future<void> _rename() async {
    final text = await _askText(
      title: '이름 변경',
      initial: _name,
      hint: '예) 전자레인지',
    );
    final name = text?.trim();
    if (name == null || name.isEmpty || name == _name) return;
    await HomeDeviceStore.updateById(widget.deviceId, {'name': name});
    final active = ActiveDeviceService.instance;
    if (active.getActiveDeviceId() == widget.deviceId) {
      await active.setActiveDevice(
        deviceId: widget.deviceId,
        deviceName: name,
        bleId: _bleId,
        bleName: _bleName,
        deviceType: _deviceType,
      );
    }
    active.notifyDeviceListChanged();
    await _load();
    _tts.speak('이름을 $name(으)로 바꿨습니다.', priority: TtsPriority.result);
  }

  /// "우리집 세탁기"처럼 사용자가 실제로 부르는 이름을 등록하면 음성 명령에서
  /// 기기 이름과 같은 수준으로 맞춘다(VoiceDeviceResolver).
  Future<void> _editAliases() async {
    final text = await _askText(
      title: '$_name 음성 별명',
      initial: _aliases.join(', '),
      hint: '예) 우리집 세탁기, 큰 세탁기 (쉼표로 구분)',
    );
    if (text == null) return;
    final aliases = text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await HomeDeviceStore.updateById(widget.deviceId, {'aliases': aliases});
    ActiveDeviceService.instance.notifyDeviceListChanged();
    await _load();
  }

  Future<void> _setHardware(String? bleId, String? bleName) async {
    // 목록을 통째로 저장하지 않고 이 기기만 고친다(다른 화면의 변경을 덮어쓰지 않게).
    await HomeDeviceStore.updateById(
      widget.deviceId,
      {'bleId': bleId, 'bleName': bleName},
    );
    final active = ActiveDeviceService.instance;
    if (active.getActiveDeviceId() == widget.deviceId) {
      await active.setActiveDevice(
        deviceId: widget.deviceId,
        deviceName: _name,
        bleId: bleId,
        bleName: bleName,
        deviceType: _deviceType,
      );
    }
    active.notifyDeviceListChanged();
    await _load();
  }

  void _pickHardware() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BleScannerSheet(
        onSelected: (info) {
          Navigator.pop(ctx);
          _setHardware(info.id, info.name);
        },
      ),
    );
  }

  Future<void> _confirmDelete() async {
    HapticFeedback.heavyImpact();
    _tts.speak(
      '$_name 기기를 삭제할까요? 버튼 위치 설정도 함께 지워집니다.',
      interrupt: true,
      priority: TtsPriority.result,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          '기기 삭제',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$_name 기기를 삭제할까요?\n버튼 위치 설정도 함께 지워집니다.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
            ),
            child: const Text(
              '삭제',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = _name;
    await HomeDeviceStore.removeById(widget.deviceId);
    await DeviceMappingService.instance.delete(widget.deviceId);
    final active = ActiveDeviceService.instance;
    if (active.getActiveDeviceId() == widget.deviceId) {
      // 지운 기기가 활성으로 남으면 음성 명령이 지운 기기의 매핑으로 누를 수 있다.
      await active.clearActiveDevice();
    }
    active.notifyDeviceListChanged();
    _tts.speak(
      '$name 기기를 삭제했습니다.',
      interrupt: true,
      priority: TtsPriority.result,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final gap = ResponsiveScale.v(context, 24);
    final small = ResponsiveScale.v(context, 10);

    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_device == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const TopAppBar(title: '보호자 설정', showBack: true),
        body: Center(
          child: Text(
            '이 기기를 찾을 수 없습니다.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16 * rs),
          ),
        ),
      );
    }

    final connected = _bleId != null &&
        BleService.instance.isConnected &&
        BleService.instance.connectedDeviceId == _bleId;
    final hardwareText = _bleId == null
        ? '연결할 Touch Bridge가 없습니다. 눌러서 고르세요.'
        : '${_bleName ?? 'Touch Bridge'}${connected ? ' · 연결됨' : ''}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: '보호자 설정', showBack: true),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(ResponsiveScale.v(context, 20)),
          children: [
            Semantics(
              header: true,
              child: Text(
                _name,
                style: TextStyle(
                  fontSize: 26 * rs,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: gap),
            const SectionLabel(
              icon: Icons.touch_app_rounded,
              label: '버튼 위치',
            ),
            SizedBox(height: small),
            SettingsCard(
              children: [
                NavRow(
                  icon: Icons.open_with_rounded,
                  title: '버튼 위치 수정',
                  subtitle: '버튼을 고르고 화살표로 옮긴 뒤, 눌러 보고 저장합니다',
                  onTap: _openButtonPositions,
                ),
                const SettingsDivider(),
                NavRow(
                  icon: Icons.photo_camera_rounded,
                  title: '사진으로 버튼 다시 찾기',
                  subtitle: '패널 사진을 새로 찍어 버튼 위치를 다시 정합니다',
                  onTap: _openPhotoRemap,
                ),
              ],
            ),
            SizedBox(height: gap),
            const SectionLabel(icon: Icons.badge_rounded, label: '기기 정보'),
            SizedBox(height: small),
            SettingsCard(
              children: [
                NavRow(
                  icon: Icons.edit_rounded,
                  title: '이름 변경',
                  subtitle: _name,
                  onTap: _rename,
                ),
                const SettingsDivider(),
                NavRow(
                  icon: Icons.record_voice_over_rounded,
                  title: '음성 별명',
                  subtitle: _aliases.isEmpty
                      ? '없음 · 평소 부르는 이름을 등록하세요'
                      : _aliases.join(', '),
                  onTap: _editAliases,
                ),
                const SettingsDivider(),
                NavRow(
                  icon: Icons.bluetooth_searching_rounded,
                  title: '연결할 Touch Bridge',
                  subtitle: hardwareText,
                  onTap: _pickHardware,
                ),
                if (_bleId != null) ...[
                  const SettingsDivider(),
                  NavRow(
                    icon: Icons.link_off_rounded,
                    title: 'Touch Bridge 연결 해제',
                    subtitle: '이 가전에서 장치 연결 정보를 지웁니다',
                    onTap: () => _setHardware(null, null),
                  ),
                ],
              ],
            ),
            SizedBox(height: gap),
            SettingsCard(
              children: [
                NavRow(
                  icon: Icons.delete_forever_rounded,
                  title: '기기 삭제',
                  subtitle: '이 가전과 버튼 위치 설정을 지웁니다',
                  onTap: _confirmDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 글자 하나를 입력받는 대화상자. 컨트롤러를 대화상자가 직접 갖고 있어야 닫히는
/// 애니메이션 도중 이미 버린 컨트롤러를 쓰지 않는다.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
  });

  final String title;
  final String initial;
  final String hint;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: Text(
        widget.title,
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: TextField(
        controller: _controller,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: AppColors.textTertiary),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
