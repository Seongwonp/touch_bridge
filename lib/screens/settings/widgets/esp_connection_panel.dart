import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 개발자 콘솔 상단의 ESP32 연결 상태 표시 + "ESP 선택" 버튼.
class EspConnectionPanel extends StatelessWidget {
  const EspConnectionPanel({
    super.key,
    required this.connected,
    required this.connectedName,
    required this.connectedId,
    required this.isScanning,
    required this.scale,
    required this.onScanTap,
  });

  final bool connected;
  final String connectedName;
  final String connectedId;
  final bool isScanning;
  final double scale;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final rs = scale;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14 * rs),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded,
            color: connected ? Colors.greenAccent : AppColors.primary,
            size: 24 * rs,
          ),
          SizedBox(width: 10 * rs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? connectedName : 'ESP 미연결',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15 * rs,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  connected ? connectedId : '다른 ESP를 테스트하려면 선택하세요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11 * rs),
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * rs),
          ElevatedButton.icon(
            onPressed: isScanning ? null : onScanTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 12 * rs, vertical: 10 * rs),
              minimumSize: Size(80 * rs, 40 * rs),
            ),
            icon: isScanning
                ? SizedBox(
                    width: 16 * rs,
                    height: 16 * rs,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Icon(Icons.search_rounded, size: 18 * rs),
            label: Text(
              isScanning ? '검색 중' : 'ESP 선택',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13 * rs),
            ),
          ),
        ],
      ),
    );
  }
}
