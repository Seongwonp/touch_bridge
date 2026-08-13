import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../services/home_device_store.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import '../connection/device_connect_screen.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    _devices = await HomeDeviceStore.loadDevices();
    setState(() => _isLoading = false);
  }

  Future<void> _updateBleId(int index, String? bleId, String? bleName) async {
    setState(() {
      _devices[index]['bleId'] = bleId;
      _devices[index]['bleName'] = bleName;
    });
    await HomeDeviceStore.saveDevices(_devices);
  }

  Future<void> _showPairDialog(int index) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BleScannerSheet(
        onSelected: (info) {
          _updateBleId(index, info.id, info.name);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _openDeviceConnect() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DeviceConnectScreen()),
    );
    if (mounted) {
      await _loadDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: TopAppBar(
        title: '기기 및 ESP32 관리',
        showBack: true,
        actions: [
          IconButton(
            tooltip: '새 기기 추가',
            onPressed: _openDeviceConnect,
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _devices.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24 * rs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.devices_other_rounded,
                      color: AppColors.primary,
                      size: 56,
                    ),
                    SizedBox(height: 16 * rs),
                    Text(
                      '등록된 기기가 없습니다',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20 * rs,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8 * rs),
                    Text(
                      '새 기기 추가 버튼을 눌러\nQR, 블루투스, NFC로 등록하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14 * rs,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 24 * rs),
                    ElevatedButton.icon(
                      onPressed: _openDeviceConnect,
                      icon: const Icon(Icons.add_link_rounded),
                      label: const Text('새 기기 추가'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.all(16 * rs),
              itemCount: _devices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final device = _devices[index];
                final bleId = device['bleId'] as String?;
                final bleName = device['bleName'] as String?;
                final isConnected =
                    BleService.instance.isConnected &&
                    BleService.instance.connectedDeviceId == bleId;

                return Container(
                  padding: EdgeInsets.all(16 * rs),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16 * rs),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            IconData(
                              device['iconCodePoint'] as int,
                              fontFamily: 'MaterialIcons',
                            ),
                            color: AppColors.primary,
                            size: 24 * rs,
                          ),
                          SizedBox(width: 12 * rs),
                          Expanded(
                            child: Text(
                              device['name'] ?? '알 수 없는 기기',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18 * rs,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isConnected)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8 * rs,
                                vertical: 4 * rs,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4 * rs),
                              ),
                              child: Text(
                                '연결됨',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11 * rs,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 16 * rs),
                      Text(
                        '연결된 ESP32 하드웨어:',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13 * rs,
                        ),
                      ),
                      SizedBox(height: 4 * rs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bleId != null
                                  ? '$bleName ($bleId)'
                                  : '등록된 하드웨어 없음',
                              style: TextStyle(
                                color: bleId != null
                                    ? Colors.white
                                    : Colors.redAccent.withValues(alpha: 0.7),
                                fontSize: 14 * rs,
                                fontFamily: bleId != null ? 'monospace' : null,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showPairDialog(index),
                            icon: const Icon(
                              Icons.bluetooth_searching_rounded,
                              size: 16,
                            ),
                            label: Text(bleId != null ? '변경' : '등록'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                          if (bleId != null)
                            IconButton(
                              tooltip: 'BLE 연결 해제',
                              onPressed: () => _updateBleId(index, null, null),
                              icon: const Icon(
                                Icons.link_off_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _BleScannerSheet extends StatefulWidget {
  final Function(BleDeviceInfo) onSelected;
  const _BleScannerSheet({required this.onSelected});

  @override
  State<_BleScannerSheet> createState() => _BleScannerSheetState();
}

class _BleScannerSheetState extends State<_BleScannerSheet> {
  List<BleDeviceInfo> _foundDevices = [];
  bool _isScanning = false;
  final FocusNode _titleFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _startScan();
    // BottomSheet 열릴 때 제목 영역으로 포커스 이동 → 스크린리더가 "주변 하드웨어 검색" 부터 탐색
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _foundDevices = [];
    });
    final results = await BleService.instance.scan(
      timeout: const Duration(seconds: 5),
    );
    if (mounted) {
      setState(() {
        _foundDevices = results;
        _isScanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.all(16 * rs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Focus(
                  focusNode: _titleFocus,
                  child: Semantics(
                    header: true,
                    child: Text(
                      '주변 하드웨어 검색',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18 * rs,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                else
                  IconButton(
                    tooltip: '기기 재검색',
                    onPressed: _startScan,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: AppColors.borderDefault, height: 1),
          if (!_isScanning && _foundDevices.isEmpty)
            Padding(
              padding: EdgeInsets.all(32 * rs),
              child: const Text(
                '검색된 기기가 없습니다.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _foundDevices.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.borderDefault, height: 1),
              itemBuilder: (_, index) {
                final d = _foundDevices[index];
                return ListTile(
                  title: Text(
                    d.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    d.id,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.add_link_rounded,
                    color: AppColors.primary,
                  ),
                  onTap: () => widget.onSelected(d),
                );
              },
            ),
          ),
          SizedBox(height: 20 * rs),
        ],
      ),
    );
  }
}
