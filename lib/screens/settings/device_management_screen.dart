import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ble_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('home_devices');
    if (jsonStr != null) {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      _devices = decoded.cast<Map<String, dynamic>>();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateBleId(int index, String? bleId, String? bleName) async {
    setState(() {
      _devices[index]['bleId'] = bleId;
      _devices[index]['bleName'] = bleName;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_devices', jsonEncode(_devices));
  }

  Future<void> _showPairDialog(int index) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _BleScannerSheet(
        onSelected: (info) {
          _updateBleId(index, info.id, info.name);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const TopAppBar(title: '기기 및 ESP32 관리', showBack: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFEB00)))
          : ListView.separated(
              padding: EdgeInsets.all(16 * rs),
              itemCount: _devices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final device = _devices[index];
                final bleId = device['bleId'] as String?;
                final bleName = device['bleName'] as String?;
                final isConnected = BleService.instance.isConnected && 
                                    BleService.instance.connectedDeviceId == bleId;

                return Container(
                  padding: EdgeInsets.all(16 * rs),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16 * rs),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            IconData(device['iconCodePoint'] as int, fontFamily: 'MaterialIcons'),
                            color: const Color(0xFFFFEB00),
                            size: 24 * rs,
                          ),
                          SizedBox(width: 12 * rs),
                          Expanded(
                            child: Text(
                              device['name'] ?? '알 수 없는 기기',
                              style: TextStyle(color: Colors.white, fontSize: 18 * rs, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isConnected)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8 * rs, vertical: 4 * rs),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4 * rs)),
                              child: Text('연결됨', style: TextStyle(color: Colors.greenAccent, fontSize: 11 * rs, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      SizedBox(height: 16 * rs),
                      Text('연결된 ESP32 하드웨어:', style: TextStyle(color: Colors.white54, fontSize: 13 * rs)),
                      SizedBox(height: 4 * rs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bleId != null ? '$bleName ($bleId)' : '등록된 하드웨어 없음',
                              style: TextStyle(
                                color: bleId != null ? Colors.white : Colors.redAccent.withValues(alpha: 0.7),
                                fontSize: 14 * rs,
                                fontFamily: bleId != null ? 'monospace' : null,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showPairDialog(index),
                            icon: const Icon(Icons.bluetooth_searching_rounded, size: 16),
                            label: Text(bleId != null ? '변경' : '등록'),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFEB00)),
                          ),
                          if (bleId != null)
                            IconButton(
                              onPressed: () => _updateBleId(index, null, null),
                              icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 20),
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

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _foundDevices = [];
    });
    final results = await BleService.instance.scan(timeout: const Duration(seconds: 5));
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
                Text('주변 하드웨어 검색', style: TextStyle(color: Colors.white, fontSize: 18 * rs, fontWeight: FontWeight.bold)),
                if (_isScanning)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFEB00)))
                else
                  IconButton(onPressed: _startScan, icon: const Icon(Icons.refresh_rounded, color: Color(0xFFFFEB00))),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          if (!_isScanning && _foundDevices.isEmpty)
            Padding(
              padding: EdgeInsets.all(32 * rs),
              child: const Text('검색된 기기가 없습니다.', style: TextStyle(color: Colors.white54)),
            ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _foundDevices.length,
              separatorBuilder: (_, _) => const Divider(color: Color(0xFF2A2A2A), height: 1),
              itemBuilder: (_, index) {
                final d = _foundDevices[index];
                return ListTile(
                  title: Text(d.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(d.id, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: const Icon(Icons.add_link_rounded, color: Color(0xFFFFEB00)),
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
