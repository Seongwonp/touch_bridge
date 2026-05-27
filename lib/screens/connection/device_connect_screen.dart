import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart';
import '../../services/tts_service.dart';
import '../../services/ble_service.dart';
import '../../services/ai_backend_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/app_logger.dart';
import '../../widgets/responsive_scale.dart';
import 'qr_scan_screen.dart';

int _iconCodePointForType(String type) {
  return switch (type.toLowerCase()) {
    'microwave' => Icons.microwave_rounded.codePoint,
    'washer' || 'laundry' => Icons.local_laundry_service_rounded.codePoint,
    'air' || 'air_purifier' => Icons.air_rounded.codePoint,
    'ac' || 'aircon' || 'air_cond' => Icons.ac_unit_rounded.codePoint,
    'light' || 'lamp' => Icons.light_mode_rounded.codePoint,
    'tv' => Icons.tv_rounded.codePoint,
    'fridge' || 'refrigerator' => Icons.kitchen_rounded.codePoint,
    _ => Icons.devices_rounded.codePoint,
  };
}

class DeviceConnectScreen extends StatefulWidget {
  const DeviceConnectScreen({super.key});

  @override
  State<DeviceConnectScreen> createState() => _DeviceConnectScreenState();
}

class _DeviceConnectScreenState extends State<DeviceConnectScreen> {
  final TtsService _tts = TtsService();
  final Random _random = Random();
  bool _isScanning = false;
  bool _isConnecting = false;
  String _statusText = '연결 가능한 기기 감지됨';
  String _hubName = 'ESP32 Smart Hub';
  bool _connected = false;

  static const _prefKeyDevices = 'home_devices';

  String _newDeviceId([String prefix = 'device']) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final suffix = _random.nextInt(1 << 20).toRadixString(16);
    return '${prefix}_$ts$suffix';
  }

  static const _iconOptions = [
    (label: '전자레인지', icon: Icons.microwave_rounded, type: 'microwave'),
    (label: '세탁기', icon: Icons.local_laundry_service_rounded, type: 'washer'),
    (label: '공기청정기', icon: Icons.air_rounded, type: 'air'),
    (label: '에어컨', icon: Icons.ac_unit_rounded, type: 'ac'),
    (label: '전등', icon: Icons.light_mode_rounded, type: 'light'),
    (label: 'TV', icon: Icons.tv_rounded, type: 'tv'),
    (label: '냉장고', icon: Icons.kitchen_rounded, type: 'fridge'),
    (label: '기타', icon: Icons.devices_rounded, type: ''),
  ];

  Future<void> _registerDevice(
    BuildContext context, {
    required String name,
    required String type,
    String? preferredDeviceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKeyDevices);
    final devices = jsonStr != null
        ? (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    final candidateId = (preferredDeviceId?.trim().isNotEmpty ?? false)
        ? preferredDeviceId!.trim()
        : _newDeviceId(name.replaceAll(' ', '_'));

    if (devices.any((d) => d['id'] == candidateId || d['name'] == name)) {
      if (context.mounted) {
        _tts.speak('$name 기기는 이미 등록되어 있습니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name 기기는 이미 등록되어 있습니다.'),
            backgroundColor: const Color(0xFFFFB020),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    devices.add({
      'id': candidateId,
      'name': name,
      'status': '작동 대기 중',
      'iconCodePoint': _iconCodePointForType(type),
    });
    await prefs.setString(_prefKeyDevices, jsonEncode(devices));

    if (context.mounted) {
      _tts.speak('$name 기기가 홈에 추가되었습니다.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name 기기가 홈에 추가되었습니다.'),
          backgroundColor: const Color(0xFF00FF88),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showRegisterDialog(
    BuildContext context, {
    required String initialName,
    required String initialType,
    String? initialDeviceId,
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    int selectedIconIndex = _iconOptions.indexWhere(
      (o) => o.type == initialType,
    );
    if (selectedIconIndex < 0) {
      selectedIconIndex = _iconOptions.length - 1; // 기타
    }

    _tts.speak('등록된 기기가 없습니다. 기기 이름과 종류를 확인하고 등록 버튼을 눌러주세요.');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '기기 등록',
            style: TextStyle(
              color: Color(0xFFFFEB00),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFB020),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB020)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFFFB020),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '등록된 모델 정보가 없습니다.\n이름과 종류를 직접 입력해 주세요.',
                          style: TextStyle(
                            color: Color(0xFFFFB020),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '기기 이름',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '예: 우리집 전자레인지',
                    hintStyle: const TextStyle(color: Color(0xFF555577)),
                    filled: true,
                    fillColor: const Color(0xFF0D1C32),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF333355)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFFFEB00),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '기기 종류',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_iconOptions.length, (i) {
                    final opt = _iconOptions[i];
                    final selected = i == selectedIconIndex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIconIndex = i),
                      child: Container(
                        width: 68,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0x33FFEB00)
                              : const Color(0xFF0D1C32),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFFFEB00)
                                : const Color(0xFF333355),
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              opt.icon,
                              color: selected
                                  ? const Color(0xFFFFEB00)
                                  : const Color(0xFF888888),
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              opt.label,
                              style: TextStyle(
                                color: selected
                                    ? const Color(0xFFFFEB00)
                                    : const Color(0xFF888888),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
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
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();
                await _registerDevice(
                  context,
                  name: name,
                  type: _iconOptions[selectedIconIndex].type,
                  preferredDeviceId: initialDeviceId,
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
                '등록',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String label) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 기능은 다음 단계에서 연결됩니다.'),
        duration: const Duration(seconds: 1),
      ),
    );
    _tts.speak('$label 기능은 다음 단계에서 연결됩니다.');
  }

  Widget _statusCard() {
    final rs = ResponsiveScale.factor(context);
    final statusColor = _connected
        ? const Color(0xFF00FF88)
        : const Color(0xFFFFB020);
    return Semantics(
      label: '$_hubName, $_statusText',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveScale.v(context, 16),
          vertical: ResponsiveScale.v(context, 14),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10 * rs,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: ResponsiveScale.v(context, 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hubName,
                    style: TextStyle(
                      fontSize: 17 * rs,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: ResponsiveScale.v(context, 2)),
                  Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 13 * rs,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
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

  Widget _optionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool highlighted,
  }) {
    final rs = ResponsiveScale.factor(context);
    return Semantics(
      label: '$title. $subtitle. 버튼',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveScale.v(context, 16),
              vertical: ResponsiveScale.v(context, 16),
            ),
            decoration: BoxDecoration(
              color: highlighted
                  ? const Color(0xFFFFEB00)
                  : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted
                    ? Colors.transparent
                    : const Color(0xFF2A2A2A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48 * rs,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? Colors.black.withValues(alpha: 0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: highlighted
                        ? null
                        : Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Icon(
                    icon,
                    color: highlighted ? Colors.black : const Color(0xFFFFEB00),
                    size: 24 * rs,
                  ),
                ),
                SizedBox(width: ResponsiveScale.v(context, 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18 * rs,
                          fontWeight: FontWeight.w800,
                          color: highlighted ? Colors.black : Colors.white,
                        ),
                      ),
                      SizedBox(height: ResponsiveScale.v(context, 2)),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13 * rs,
                          fontWeight: FontWeight.w500,
                          color: highlighted
                              ? Colors.black.withValues(alpha: 0.6)
                              : const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: highlighted
                      ? Colors.black.withValues(alpha: 0.5)
                      : const Color(0xFF555555),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallAction({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final rs = ResponsiveScale.factor(context);
    return Expanded(
      child: Semantics(
        label: '$title 버튼',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveScale.v(context, 14),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: const Color(0xFF888888), size: 22 * rs),
                  SizedBox(height: ResponsiveScale.v(context, 6)),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13 * rs,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onNfcTagTap() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _tts.speak('이 기기는 NFC 기능을 지원하지 않습니다.');
      return;
    }

    _tts.speak('NFC 태그를 기기 뒷면에 가까이 대주세요.');
    HapticFeedback.mediumImpact();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nfc_rounded, size: 64, color: Color(0xFFFFEB00)),
            const SizedBox(height: 16),
            const Text(
              'NFC 태그 인식 대기 중...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '태그를 폰 뒷면 상단에 밀착시켜 주세요.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  NfcManager.instance.stopSession();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF333333),
                ),
                child: const Text('취소', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null || ndef.cachedMessage == null) {
            _tts.speak('태그 형식이 올바르지 않습니다.');
            return;
          }

          final record = ndef.cachedMessage!.records.first;
          final payload = String.fromCharCodes(record.payload);
          // NFC payload often has language code prefix (e.g. \x02enDeviceId)
          final deviceId = payload.length > 3
              ? payload.substring(3).trim()
              : payload.trim();

          AppLogger.info('nfc.discovered', {'id': deviceId});

          await NfcManager.instance.stopSession();
          if (mounted) Navigator.pop(context); // Close bottom sheet

          await _processCloudDeviceId(deviceId);
        } catch (e) {
          AppLogger.error('nfc.error', {'error': e.toString()});
          await NfcManager.instance.stopSession();
          if (mounted) {
            Navigator.pop(context);
            _tts.speak('태그를 읽는 중 오류가 발생했습니다.');
          }
        }
      },
    );
  }

  Future<void> _onManualInputTap() async {
    final codeCtrl = TextEditingController();
    _tts.speak('기기에 적힌 6자리 코드를 입력해 주세요.');

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '수동 코드 입력',
          style: TextStyle(
            color: Color(0xFFFFEB00),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '기기에 부착된 고유 코드를 입력하면 설정을 자동으로 불러옵니다.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '예: MW-BASE-001',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                filled: true,
                fillColor: const Color(0xFF0D1C32),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeCtrl.text.trim().toUpperCase();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                _processCloudDeviceId(code);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFEB00),
              foregroundColor: Colors.black,
            ),
            child: const Text(
              '확인',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processCloudDeviceId(String deviceId) async {
    _tts.speak('서버에서 기기 정보를 불러오는 중입니다.');

    try {
      final profileData = await AiBackendService.instance.fetchDeviceProfile(
        deviceId,
      );
      final name = profileData['device_type'] ?? '새 기기';
      if (!mounted) return;

      // 1. 기기 목록에 추가
      await _registerDevice(
        context,
        name: name,
        type: name == '전자레인지' ? 'microwave' : (name == '세탁기' ? 'washer' : ''),
        preferredDeviceId: deviceId,
      );

      // 2. 매핑 정보 저장
      final profile = DeviceMappingProfile.fromJson(profileData);
      await DeviceMappingService.instance.save(deviceId, profile);

      _tts.speak('클라우드에서 $name 정보를 성공적으로 가져왔습니다.');
    } catch (e) {
      _tts.speak('기기 정보를 가져오지 못했습니다. $e');
    }
  }

  Future<bool> _ensureBlePermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.bluetooth.request();
      if (!status.isGranted) {
        if (!mounted) return false;
        setState(() => _statusText = '블루투스 권한이 필요합니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('iPhone 설정에서 Bluetooth 권한을 허용해 주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
        _tts.speak('아이폰 설정에서 블루투스 권한을 허용해 주세요.');
        return false;
      }
      return true;
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final granted = statuses.values.every((status) => status.isGranted);
    if (!granted) {
      setState(() => _statusText = '블루투스 권한이 필요합니다.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('블루투스/위치 권한을 허용해 주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      _tts.speak('블루투스 권한이 필요합니다. 설정에서 권한을 허용해 주세요.');
    }
    return granted;
  }

  Future<void> _onBluetoothConnectTap() async {
    if (_isScanning || _isConnecting) return;
    final allowed = await _ensureBlePermissions();
    if (!allowed) return;

    setState(() {
      _isScanning = true;
      _statusText = '주변 BLE 기기를 검색 중...';
      _connected = false;
    });
    _tts.speak('주변 블루투스 기기를 검색합니다.');

    final devices = await BleService.instance.scan(
      timeout: const Duration(seconds: 5),
    );

    if (!mounted) return;
    setState(() => _isScanning = false);

    if (devices.isEmpty) {
      final scanError = BleService.instance.lastScanError;
      if (scanError == 'BLUETOOTH_NOT_READY') {
        setState(() => _statusText = '블루투스를 켜고 다시 시도해 주세요.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth가 아직 준비되지 않았습니다. 설정에서 켠 뒤 다시 시도해 주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
        _tts.speak('블루투스를 켜고 다시 시도해 주세요.');
      } else {
        setState(() => _statusText = '검색된 BLE 기기가 없습니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주변에서 검색된 BLE 기기가 없습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
        _tts.speak('검색된 블루투스 기기가 없습니다.');
      }
      return;
    }

    final selected = await showModalBottomSheet<BleDeviceInfo>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: devices.length,
          separatorBuilder: (context, index) =>
              const Divider(color: Color(0xFF2A2A2A), height: 1),
          itemBuilder: (_, index) {
            final d = devices[index];
            return ListTile(
              title: Text(
                d.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                '${d.id} • RSSI ${d.rssi}',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFFFEB00),
              ),
              onTap: () => Navigator.of(ctx).pop(d),
            );
          },
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _isConnecting = true;
      _statusText = '연결 중: ${selected.name}';
      _hubName = selected.name;
    });
    _tts.speak('${selected.name}에 연결 중입니다.');

    final ok = await BleService.instance.connect(selected.id);
    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _connected = ok;
      _statusText = ok ? 'BLE 연결 완료' : 'BLE 연결 실패';
    });
    _tts.speak(ok ? '블루투스 연결이 완료되었습니다.' : '블루투스 연결에 실패했습니다.');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Container(
              height: ResponsiveScale.v(context, 64),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveScale.v(context, 20),
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Semantics(
                label: 'Touch Bridge 앱',
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFFFFEB00),
                        ),
                      ),
                    Text(
                      'Touch Bridge',
                      style: TextStyle(
                        color: Color(0xFFFFEB00),
                        fontSize: 22 * rs,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    ResponsiveScale.v(context, 20),
                    ResponsiveScale.v(context, 20),
                    ResponsiveScale.v(context, 20),
                    ResponsiveScale.v(context, 20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '기기 연결',
                        style: TextStyle(
                          fontSize: 28 * rs,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: ResponsiveScale.v(context, 4)),
                      Text(
                        '기기를 연결하여 제어를 시작하세요',
                        style: TextStyle(
                          fontSize: 14 * rs,
                          color: Color(0xFF888888),
                        ),
                      ),
                      SizedBox(height: ResponsiveScale.v(context, 20)),
                      _statusCard(),
                      SizedBox(height: ResponsiveScale.v(context, 12)),
                      _optionCard(
                        context: context,
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'QR 코드 스캔',
                        subtitle: '허브의 QR을 촬영하여 즉시 연결',
                        highlighted: true,
                        onTap: () async {
                          _tts.speak('QR 코드 스캔 화면으로 이동합니다.');
                          final result = await Navigator.of(context)
                              .push<Map<String, String>>(
                                MaterialPageRoute(
                                  builder: (_) => const QrScanScreen(),
                                ),
                              );
                          if (result != null && context.mounted) {
                            // QR에서 deviceId 또는 raw 데이터를 읽어옴
                            final deviceId =
                                (result['deviceId'] ?? result['raw'] ?? '')
                                    .trim();
                            if (deviceId.isNotEmpty) {
                              await _processCloudDeviceId(deviceId);
                            } else {
                              _tts.speak('올바른 QR 코드가 아닙니다.');
                            }
                          }
                        },
                      ),
                      SizedBox(height: ResponsiveScale.v(context, 10)),
                      _optionCard(
                        context: context,
                        icon: Icons.bluetooth_rounded,
                        title: '블루투스 연결',
                        subtitle: '주변 기기 자동 검색 및 페어링',
                        highlighted: false,
                        onTap: _onBluetoothConnectTap,
                      ),
                      SizedBox(height: ResponsiveScale.v(context, 10)),
                      Row(
                        children: [
                          _smallAction(
                            context: context,
                            title: 'NFC 태그',
                            icon: Icons.nfc_rounded,
                            onTap: _onNfcTagTap,
                          ),
                          SizedBox(width: ResponsiveScale.v(context, 10)),
                          _smallAction(
                            context: context,
                            title: '수동 입력',
                            icon: Icons.keyboard_rounded,
                            onTap: _onManualInputTap,
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveScale.v(context, 40)),
                      Semantics(
                        label: '연결에 문제가 있나요? 도움말 보기 버튼',
                        button: true,
                        child: Center(
                          child: Text(
                            '연결에 문제가 있나요? 도움말 보기',
                            style: TextStyle(
                              fontSize: 12 * rs,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
