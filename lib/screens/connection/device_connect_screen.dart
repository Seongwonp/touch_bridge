import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/tts_service.dart';
import '../../services/ble_service.dart';
import '../../services/active_device_service.dart';
import '../../services/ai_backend_service.dart';
import '../../services/device_mapping_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../home/appliance_selection_screen.dart';
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
  bool _scanning = false;
  bool _connected = false;
  String _statusMessage = '주변 기기를 검색합니다.';
  static const _prefKeyDevices = 'home_devices';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.camera,
      ].request();
    }
  }

  Future<void> _onBluetoothConnectTap() async {
    setState(() {
      _scanning = true;
      _statusMessage = '주변 기기를 검색 중입니다...';
    });

    final devices = await BleService.instance.scan(timeout: const Duration(seconds: 5));
    
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _statusMessage = devices.isEmpty ? '검색된 기기가 없습니다.' : '기기를 선택하세요.';
    });

    if (devices.isEmpty) {
      _tts.speak('주변에 연결 가능한 기기가 없습니다.', source: 'DeviceConnectScreen');
      return;
    }

    final selected = await showModalBottomSheet<BleDeviceInfo>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('주변 기기 목록', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ...devices.map((d) => ListTile(
              leading: const Icon(Icons.bluetooth, color: Color(0xFFFFEB00)),
              title: Text(d.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text('RSSI: ${d.rssi} dBm', style: const TextStyle(color: Colors.white54)),
              onTap: () => Navigator.pop(ctx, d),
            )),
          ],
        ),
      ),
    );

    if (selected != null) {
      _tts.speak('기기 연결을 시도합니다.', source: 'DeviceConnectScreen');
      final ok = await BleService.instance.connect(selected.id);
      
      if (mounted) {
        if (ok) {
          setState(() {
            _connected = true;
            _statusMessage = 'BLE 연결 완료';
          });
          
          _tts.speak('연결에 성공했습니다. 이제 이 하드웨어에 등록할 가전 기기를 선택해 주세요.', source: 'DeviceConnectScreen');
          
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ApplianceSelectionScreen(
                bleId: selected.id,
                bleName: selected.name,
              ),
            ),
          );
        } else {
          _tts.speak('연결에 실패했습니다. 다시 시도해 주세요.', source: 'DeviceConnectScreen');
        }
      }
    }
  }

  Future<void> _onQrScanTap() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );

    if (result != null && result.isNotEmpty) {
      if (result.startsWith('http')) {
        _tts.speak('지원되지 않는 QR 형식입니다.');
        return;
      }
      await _processCloudDeviceId(result);
    }
  }

  Future<void> _onManualInputTap() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('기기 코드 입력', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '6자리 기기 코드 (예: MW001A)',
            hintStyle: TextStyle(color: Colors.white30),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('확인')),
        ],
      ),
    );

    if (code != null && code.isNotEmpty) {
      await _processCloudDeviceId(code);
    }
  }

  Future<void> _onNfcTagTap() async {
    _tts.speak('NFC 태그를 휴대폰 뒷면에 가까이 대주세요.');
    // NFC 연동 로직 (NfcManager 등을 사용)
    await Future.delayed(const Duration(seconds: 3));
    _tts.speak('NFC 태그를 찾을 수 없습니다.');
  }

  String _newDeviceId(String prefix) {
    final safe = prefix.replaceAll(RegExp(r'\s+'), '_');
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${safe}_$ts';
  }

  Future<void> _registerDevice(
    BuildContext context, {
    required String name,
    required String type,
    String? preferredDeviceId,
    String? bleId,
    String? bleName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKeyDevices);
    final devices = jsonStr != null
        ? (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    final candidateId = (preferredDeviceId?.trim().isNotEmpty ?? false)
        ? preferredDeviceId!.trim()
        : _newDeviceId(name.replaceAll(' ', '_'));

    // Check if device with same ID or BLE ID already exists
    if (devices.any((d) => d['id'] == candidateId)) {
      if (context.mounted) {
        _tts.speak('$name 기기는 이미 등록되어 있습니다.', source: 'DeviceConnectScreen');
      }
      return;
    }

    final newDevice = {
      'id': candidateId,
      'name': name,
      'status': '작동 대기 중',
      'iconCodePoint': _iconCodePointForType(type),
      'bleId': bleId,
      'bleName': bleName,
    };

    devices.add(newDevice);
    await prefs.setString(_prefKeyDevices, jsonEncode(devices));
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: candidateId,
      deviceName: name,
      bleId: bleId,
      bleName: bleName,
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

      _tts.speak('$name 정보 로드 완료.', source: 'DeviceConnectScreen');
    } catch (e) {
      _tts.speak('정보를 가져오지 못했습니다.', source: 'DeviceConnectScreen');
    }
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
                    borderRadius: BorderRadius.circular(20 * rs),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12 * rs),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(_scanning ? Icons.sync : (_connected ? Icons.bluetooth_connected : Icons.bluetooth_searching), color: statusColor, size: 24 * rs),
                      ),
                      SizedBox(width: 16 * rs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_connected ? 'Touch Bridge 허브 연결됨' : '허브를 찾는 중', style: TextStyle(color: Colors.white, fontSize: 16 * rs, fontWeight: FontWeight.bold)),
                            Text(_statusMessage, style: TextStyle(color: Colors.white54, fontSize: 13 * rs)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ResponsiveScale.v(context, 24)),
                
                _buildConnectOption(
                  icon: Icons.bluetooth,
                  title: 'Touch Bridge 허브 연결',
                  desc: '주변의 ESP32 하드웨어를 검색하여 연결합니다.',
                  onTap: _onBluetoothConnectTap,
                  rs: rs,
                  isPrimary: true,
                ),
                SizedBox(height: ResponsiveScale.v(context, 12)),
                _buildConnectOption(
                  icon: Icons.qr_code_scanner_rounded,
                  title: '기기 QR 스캔',
                  desc: '가전제품에 부착된 QR 코드를 인식합니다.',
                  onTap: _onQrScanTap,
                  rs: rs,
                ),
                SizedBox(height: ResponsiveScale.v(context, 12)),
                _buildConnectOption(
                  icon: Icons.nfc_rounded,
                  title: 'NFC 태그 접촉',
                  desc: 'NFC 칩에 가까이 대어 정보를 읽습니다.',
                  onTap: _onNfcTagTap,
                  rs: rs,
                ),
                SizedBox(height: ResponsiveScale.v(context, 12)),
                _buildConnectOption(
                  icon: Icons.keyboard_rounded,
                  title: '기기 코드 직접 입력',
                  desc: '기기에 적힌 6자리 코드를 입력합니다.',
                  onTap: _onManualInputTap,
                  rs: rs,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectOption({
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
    required double rs,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16 * rs),
        child: Container(
          padding: EdgeInsets.all(20 * rs),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFF1A1A1A) : const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16 * rs),
            border: Border.all(color: isPrimary ? const Color(0xFFFFEB00).withValues(alpha: 0.5) : const Color(0xFF222222)),
          ),
          child: Row(
            children: [
              Icon(icon, color: isPrimary ? const Color(0xFFFFEB00) : Colors.white, size: 28 * rs),
              SizedBox(width: 20 * rs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: Colors.white, fontSize: 17 * rs, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4 * rs),
                    Text(desc, style: TextStyle(color: const Color(0xFF888888), fontSize: 13 * rs)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: const Color(0xFF333333), size: 16 * rs),
            ],
          ),
        ),
      ),
    );
  }
}
