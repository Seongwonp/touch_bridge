import 'package:flutter/material.dart';

import '../../services/ble_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/responsive_scale.dart';

/// 주변 Touch Bridge 하드웨어를 검색해 하나를 고르는 시트.
/// 보호자 설정에서 가전에 연결할 장치를 바꿀 때 쓴다.
class BleScannerSheet extends StatefulWidget {
  final Function(BleDeviceInfo) onSelected;
  const BleScannerSheet({super.key, required this.onSelected});

  @override
  State<BleScannerSheet> createState() => _BleScannerSheetState();
}

class _BleScannerSheetState extends State<BleScannerSheet> {
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
