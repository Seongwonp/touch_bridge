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
import '../../services/active_device_service.dart';
import '../../services/ble_service.dart';
import '../../services/ai_backend_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/app_logger.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
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
        _tts.speak('$name 기기는 이미 등록되어 있습니다.', source: 'DeviceConnectScreen');
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
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: candidateId,
      deviceName: name,
    );

    if (context.mounted) {
      _tts.speak('$name 기기가 홈에 추가되었습니다.', source: 'DeviceConnectScreen');
    }
  }

  Future<void> _processCloudDeviceId(String deviceId) async {
    _tts.speak('기기 정보를 불러오는 중입니다.', source: 'DeviceConnectScreen');

    try {
      final profileData = await AiBackendService.instance.fetchDeviceProfile(deviceId);
      final name = (profileData['device_type'] as String?) ?? '새 기기';
      if (!mounted) return;

      await _registerDevice(
        context,
        name: name,
        type: name == '전자레인지' ? 'microwave' : (name == '세탁기' ? 'washer' : ''),
        preferredDeviceId: deviceId,
      );

      final profile = DeviceMappingProfile.fromJson(profileData);
      await DeviceMappingService.instance.save(deviceId, profile);
      await ActiveDeviceService.instance.setActiveDevice(
        deviceId: deviceId,
        deviceName: name,
      );

      _tts.speak('$name 정보 로드 완료.', source: 'DeviceConnectScreen');
    } catch (e) {
      _tts.speak('정보를 가져오지 못했습니다.', source: 'DeviceConnectScreen');
    }
  }

  Future<bool> _ensureBlePermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.bluetooth.request();
      if (!status.isGranted) {
        _tts.speak('블루투스 권한이 필요합니다.', source: 'DeviceConnectScreen');
        return false;
      }
      return true;
    }

    if (defaultTargetPlatform != TargetPlatform.android) return true;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final granted = statuses.values.every((status) => status.isGranted);
    if (!granted) _tts.speak('블루투스 권한이 필요합니다.', source: 'DeviceConnectScreen');
    return granted;
  }

  Future<void> _onBluetoothConnectTap() async {
    if (_isScanning || _isConnecting) return;
    final allowed = await _ensureBlePermissions();
    if (!allowed) return;

    setState(() {
      _isScanning = true;
      _statusText = '검색 중...';
      _connected = false;
    });
    _tts.speak('주변 기기를 검색합니다.', source: 'DeviceConnectScreen');

    final devices = await BleService.instance.scan(timeout: const Duration(seconds: 5));

    if (!mounted) return;
    setState(() => _isScanning = false);

    if (devices.isEmpty) {
      _tts.speak('검색된 기기가 없습니다.', source: 'DeviceConnectScreen');
      return;
    }

    final selected = await showModalBottomSheet<BleDeviceInfo>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: devices.length,
          separatorBuilder: (_, __) => const Divider(color: Color(0xFF2A2A2A), height: 1),
          itemBuilder: (_, index) {
            final d = devices[index];
            return ListTile(
              title: Text(d.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: Text('${d.id}', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFFFEB00)),
              onTap: () => Navigator.of(ctx).pop(d),
            );
          },
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _isConnecting = true;
      _statusText = '연결 중...';
      _hubName = selected.name;
    });
    _tts.speak('연결 중입니다.', source: 'DeviceConnectScreen');

    final ok = await BleService.instance.connect(selected.id);
    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _connected = ok;
      _statusText = ok ? '연결 완료' : '연결 실패';
    });
    _tts.speak(ok ? '연결되었습니다.' : '연결 실패.', source: 'DeviceConnectScreen');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final statusColor = _connected ? const Color(0xFF00FF88) : const Color(0xFFFFB020);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const TopAppBar(title: 'Touch Bridge'),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(ResponsiveScale.v(context, 20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('기기 연결', style: TextStyle(fontSize: 28 * rs, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(height: ResponsiveScale.v(context, 4)),
                Text('기기를 연결하여 제어를 시작하세요', style: TextStyle(fontSize: 14 * rs, color: const Color(0xFF888888))),
                SizedBox(height: ResponsiveScale.v(context, 20)),
                
                // Status Card
                Container(
                  padding: EdgeInsets.all(ResponsiveScale.v(context, 16)),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16 * rs),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(
                    children: [
                      Container(width: 10 * rs, height: 10 * rs, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      SizedBox(width: ResponsiveScale.v(context, 12)),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_hubName, style: TextStyle(fontSize: 17 * rs, fontWeight: FontWeight.w700, color: Colors.white)),
                          Text(_statusText, style: TextStyle(fontSize: 13 * rs, color: statusColor)),
                        ],
                      )),
                    ],
                  ),
                ),
                
                SizedBox(height: ResponsiveScale.v(context, 12)),
                _OptionCard(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'QR 코드 스캔',
                  subtitle: '허브의 QR을 촬영하여 연결',
                  highlighted: true,
                  onTap: () async {
                    _tts.speak('QR 스캔 시작', source: 'DeviceConnectScreen');
                    final result = await Navigator.push<Map<String, String>>(context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
                    if (result != null && mounted) {
                      final id = (result['deviceId'] ?? result['raw'] ?? '').trim();
                      if (id.isNotEmpty) await _processCloudDeviceId(id);
                    }
                  },
                ),
                SizedBox(height: ResponsiveScale.v(context, 10)),
                _OptionCard(
                  icon: Icons.bluetooth_rounded,
                  title: '블루투스 연결',
                  subtitle: '주변 기기 자동 검색 및 페어링',
                  highlighted: false,
                  onTap: _onBluetoothConnectTap,
                ),
                SizedBox(height: ResponsiveScale.v(context, 10)),
                Row(
                  children: [
                    _SmallAction(title: 'NFC 태그', icon: Icons.nfc_rounded, onTap: () => _tts.speak('NFC 기능', source: 'DeviceConnectScreen')),
                    SizedBox(width: ResponsiveScale.v(context, 10)),
                    _SmallAction(title: '수동 입력', icon: Icons.keyboard_rounded, onTap: () => _tts.speak('수동 입력', source: 'DeviceConnectScreen')),
                  ],
                ),
                SizedBox(height: ResponsiveScale.v(context, 40)),
                Center(child: Text('연결에 문제가 있나요? 도움말 보기', style: TextStyle(fontSize: 12 * rs, color: Colors.white30))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.icon, required this.title, required this.subtitle, required this.onTap, required this.highlighted});
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap; final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16 * rs),
      child: Container(
        padding: EdgeInsets.all(ResponsiveScale.v(context, 16)),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFFFEB00) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16 * rs),
          border: Border.all(color: highlighted ? Colors.transparent : const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Container(
              width: 48 * rs, height: 48 * rs,
              decoration: BoxDecoration(color: highlighted ? Colors.black12 : const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12 * rs)),
              child: Icon(icon, color: highlighted ? Colors.black : const Color(0xFFFFEB00), size: 24 * rs),
            ),
            SizedBox(width: ResponsiveScale.v(context, 14)),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 18 * rs, fontWeight: FontWeight.w800, color: highlighted ? Colors.black : Colors.white)),
                Text(subtitle, style: TextStyle(fontSize: 13 * rs, color: highlighted ? Colors.black54 : const Color(0xFF888888))),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: highlighted ? Colors.black38 : const Color(0xFF555555)),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.title, required this.icon, required this.onTap});
  final String title; final IconData icon; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Expanded(child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * rs),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: ResponsiveScale.v(context, 14)),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(14 * rs), border: Border.all(color: const Color(0xFF2A2A2A))),
        child: Column(children: [
          Icon(icon, color: const Color(0xFF888888), size: 22 * rs),
          SizedBox(height: ResponsiveScale.v(context, 6)),
          Text(title, style: TextStyle(fontSize: 13 * rs, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    ));
  }
}
