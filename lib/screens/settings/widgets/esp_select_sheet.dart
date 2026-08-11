import 'package:flutter/material.dart';
import '../../../services/ble_service.dart';
import '../../../theme/app_colors.dart';

/// 스캔된 ESP 목록에서 테스트할 기기를 고르는 바텀시트.
Future<BleDeviceInfo?> showEspSelectSheet({
  required BuildContext context,
  required List<BleDeviceInfo> devices,
}) {
  return showModalBottomSheet<BleDeviceInfo>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '테스트할 ESP 선택',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...devices.map(
              (d) => ListTile(
                leading: const Icon(
                  Icons.bluetooth_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  d.name,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  '${d.id}\nRSSI: ${d.rssi} dBm',
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
                isThreeLine: true,
                onTap: () => Navigator.pop(ctx, d),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
