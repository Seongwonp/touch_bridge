import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 매핑된 버튼 마커를 탭했을 때 뜨는 액션 시트 (테스트 터치 / 이름 변경 / 삭제).
Future<void> showPointActionsSheet({
  required BuildContext context,
  required String label,
  required double scale,
  required VoidCallback onTestTouch,
  required VoidCallback onRename,
  required VoidCallback onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20 * scale)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20 * scale,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 16 * scale),
            _PointActionTile(
              icon: Icons.touch_app_rounded,
              label: '테스트 터치',
              scale: scale,
              onTap: () {
                Navigator.pop(ctx);
                onTestTouch();
              },
            ),
            _PointActionTile(
              icon: Icons.edit_rounded,
              label: '이름 변경',
              scale: scale,
              onTap: () {
                Navigator.pop(ctx);
                onRename();
              },
            ),
            _PointActionTile(
              icon: Icons.delete_outline_rounded,
              label: '삭제',
              scale: scale,
              isDestructive: true,
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _PointActionTile extends StatelessWidget {
  const _PointActionTile({
    required this.icon,
    required this.label,
    required this.scale,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final double scale;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : AppColors.primary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 26 * scale),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : AppColors.textPrimary,
          fontSize: 17 * scale,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
