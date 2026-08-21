import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/tts_service.dart';
import '../../services/ble_service.dart';
import '../../services/active_device_service.dart';
import '../../services/ai_backend_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/home_device_store.dart';
import '../../theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _tts.speak(
      '기기 연결 화면입니다. 네 가지 연결 방법이 있습니다. 화면 위쪽의 블루투스 허브 연결이 '
      '음성 안내로 가장 쉽게 진행할 수 있는 방법입니다. QR 스캔과 기기 코드 입력은 화면이나 '
      '기기에 적힌 글자를 확인해야 할 수 있습니다.',
      source: 'DeviceConnectScreen',
      interrupt: true,
    );
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
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

    final devices = await BleService.instance.scan(
      timeout: const Duration(seconds: 5),
    );

    if (!mounted) return;
    setState(() {
      _scanning = false;
      _statusMessage = devices.isEmpty ? '검색된 기기가 없습니다.' : '기기를 선택하세요.';
    });

    if (devices.isEmpty) {
      _tts.speak(
        '주변에 연결 가능한 기기가 없습니다.',
        source: 'DeviceConnectScreen',
        priority: TtsPriority.result,
      );
      return;
    }

    // 기기를 찾은 경우에도 안내한다 — 이전에는 목록 시트가 무음으로 열려
    // 전맹 사용자가 검색 후 침묵 상태에 놓였다.
    _tts.speak(
      '기기 ${devices.length}개를 찾았습니다. 목록에서 선택하세요.',
      source: 'DeviceConnectScreen',
      priority: TtsPriority.result,
    );

    final selected = await showModalBottomSheet<BleDeviceInfo>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '주변 기기 목록',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...devices.map(
              (d) => ListTile(
                leading: const Icon(Icons.bluetooth, color: AppColors.primary),
                title: Text(
                  d.name,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'RSSI: ${d.rssi} dBm',
                  style: const TextStyle(color: Colors.white54),
                ),
                onTap: () => Navigator.pop(ctx, d),
              ),
            ),
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

          _tts.speak(
            '연결에 성공했습니다. 이제 이 하드웨어에 등록할 가전 기기를 선택해 주세요.',
            source: 'DeviceConnectScreen',
          );

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
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));

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
        backgroundColor: AppColors.surfaceElevated,
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (code != null && code.isNotEmpty) {
      await _processCloudDeviceId(code);
    }
  }

  // NFC 세션 상태 — 중복 시작 방지 및 타임아웃 정리에 사용한다.
  bool _nfcSessionActive = false;
  Timer? _nfcTimeoutTimer;

  /// NFC 태그에서 기기 코드를 읽어 등록한다.
  ///
  /// 이전 구현은 3초 기다렸다가 무조건 "찾을 수 없습니다"를 말하는 가짜였다.
  /// 시각장애인 사용자에게 NFC는 카메라 조준이 필요한 QR보다 훨씬 적합한
  /// 방식이므로(갖다 대면 끝) 실제 nfc_manager 세션으로 교체했다.
  /// 태그 페이로드는 QR/코드 입력과 동일하게 기기 코드 문자열로 취급한다.
  Future<void> _onNfcTagTap() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      _tts.speak(
        '이 기기에서는 NFC를 사용할 수 없습니다. 블루투스 허브 연결이나 기기 코드 입력을 이용해 주세요.',
        source: 'DeviceConnectScreen',
        priority: TtsPriority.result,
      );
      return;
    }

    var available = false;
    try {
      available = await NfcManager.instance.isAvailable();
    } catch (_) {
      available = false;
    }
    if (!available) {
      _tts.speak(
        '이 휴대폰에서 NFC가 꺼져 있거나 지원되지 않습니다. 블루투스 허브 연결이나 기기 코드 입력을 이용해 주세요.',
        source: 'DeviceConnectScreen',
        priority: TtsPriority.result,
      );
      return;
    }

    if (_nfcSessionActive) return;
    _nfcSessionActive = true;
    setState(() => _statusMessage = 'NFC 태그를 기다리는 중...');
    _tts.speak(
      'NFC 태그를 휴대폰 뒷면에 가까이 대주세요.',
      source: 'DeviceConnectScreen',
      priority: TtsPriority.result,
    );

    // 태그가 끝내 안 닿으면 세션을 정리하고 정직하게 안내한다.
    _nfcTimeoutTimer?.cancel();
    _nfcTimeoutTimer = Timer(const Duration(seconds: 15), () async {
      if (!_nfcSessionActive) return;
      await _stopNfcSession();
      if (!mounted) return;
      setState(() => _statusMessage = 'NFC 태그를 찾지 못했습니다.');
      _tts.speak(
        '태그를 찾지 못했습니다. 태그 위치를 확인하고 다시 시도해 주세요.',
        source: 'DeviceConnectScreen',
        priority: TtsPriority.result,
      );
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          _nfcTimeoutTimer?.cancel();
          final text = _readNfcText(tag);
          await _stopNfcSession();
          if (!mounted) return;
          if (text == null || text.trim().isEmpty) {
            setState(() => _statusMessage = '태그에 기기 정보가 없습니다.');
            _tts.speak(
              '태그를 읽었지만 기기 정보가 없습니다. 태그가 맞는지 확인해 주세요.',
              source: 'DeviceConnectScreen',
              priority: TtsPriority.result,
            );
            return;
          }
          setState(() => _statusMessage = '태그 인식 완료');
          await _processCloudDeviceId(text.trim());
        },
      );
    } catch (_) {
      _nfcTimeoutTimer?.cancel();
      await _stopNfcSession();
      if (!mounted) return;
      _tts.speak(
        'NFC 읽기에 실패했습니다. 다시 시도해 주세요.',
        source: 'DeviceConnectScreen',
        priority: TtsPriority.result,
      );
    }
  }

  Future<void> _stopNfcSession() async {
    _nfcSessionActive = false;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // 세션이 이미 닫혔거나 플랫폼이 지원하지 않는 경우 — 무시.
    }
  }

  /// NDEF 텍스트 레코드에서 기기 코드 문자열을 추출한다.
  /// 텍스트 레코드가 없으면 첫 레코드 페이로드를 UTF-8로 시도한다.
  String? _readNfcText(NfcTag tag) {
    final ndef = Ndef.from(tag);
    final records = ndef?.cachedMessage?.records ?? const [];
    for (final r in records) {
      final isWellKnownText =
          r.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
          r.type.length == 1 &&
          r.type.first == 0x54; // 'T'
      if (!isWellKnownText) continue;
      final payload = r.payload;
      if (payload.isEmpty) continue;
      // 텍스트 레코드 규격: [상태 바이트(하위 6비트=언어코드 길이)][언어코드][본문]
      final langLen = payload.first & 0x3F;
      if (payload.length <= 1 + langLen) continue;
      return utf8.decode(payload.sublist(1 + langLen), allowMalformed: true);
    }
    if (records.isNotEmpty) {
      try {
        return utf8.decode(records.first.payload, allowMalformed: true);
      } catch (_) {
        return null;
      }
    }
    return null;
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
    final devices = await HomeDeviceStore.loadDevices();

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
    await HomeDeviceStore.saveDevices(devices);
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
      final profileData = await AiBackendService.instance.fetchDeviceProfile(
        deviceId,
      );
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
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지워버린다(화면 전환 시 안내가 잘리는 문제).
    _nfcTimeoutTimer?.cancel();
    if (_nfcSessionActive) {
      _stopNfcSession();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final statusColor = _connected ? AppColors.success : AppColors.warning;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: 'Touch Bridge'),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(ResponsiveScale.v(context, 20)),
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
                    color: AppColors.textTertiary,
                  ),
                ),
                SizedBox(height: ResponsiveScale.v(context, 20)),

                // Status Card
                Container(
                  padding: EdgeInsets.all(ResponsiveScale.v(context, 16)),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20 * rs),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12 * rs),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _scanning
                              ? Icons.sync
                              : (_connected
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth_searching),
                          color: statusColor,
                          size: 24 * rs,
                        ),
                      ),
                      SizedBox(width: 16 * rs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _connected ? 'Touch Bridge 허브 연결됨' : '허브를 찾는 중',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16 * rs,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _statusMessage,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13 * rs,
                              ),
                            ),
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
    return Semantics(
      button: true,
      label: '$title. $desc',
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16 * rs),
        child: Container(
          padding: EdgeInsets.all(20 * rs),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppColors.surfaceElevated
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16 * rs),
            border: Border.all(
              color: isPrimary
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : const Color(0xFF222222),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isPrimary ? AppColors.primary : Colors.white,
                size: 28 * rs,
              ),
              SizedBox(width: 20 * rs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17 * rs,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4 * rs),
                    Text(
                      desc,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13 * rs,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: const Color(0xFF333333),
                size: 16 * rs,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
