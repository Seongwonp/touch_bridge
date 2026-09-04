import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

Future<void> showPositionNudgeSheet({
  required BuildContext context,
  required String targetLabel,
  required void Function(Offset delta) onNudge,
}) {
  const step = 0.005;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                '$targetLabel 위치 미세 조정',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '한 번 누를 때 사진 너비 또는 높이의 0.5%만 이동합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _NudgeButton(
              label: '위로 이동',
              icon: Icons.keyboard_arrow_up_rounded,
              onPressed: () => onNudge(const Offset(0, -step)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NudgeButton(
                  label: '왼쪽으로 이동',
                  icon: Icons.keyboard_arrow_left_rounded,
                  onPressed: () => onNudge(const Offset(-step, 0)),
                ),
                const SizedBox(width: 72, height: 64),
                _NudgeButton(
                  label: '오른쪽으로 이동',
                  icon: Icons.keyboard_arrow_right_rounded,
                  onPressed: () => onNudge(const Offset(step, 0)),
                ),
              ],
            ),
            _NudgeButton(
              label: '아래로 이동',
              icon: Icons.keyboard_arrow_down_rounded,
              onPressed: () => onNudge(const Offset(0, step)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('조정 완료'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: IconButton.filled(
      tooltip: label,
      onPressed: onPressed,
      iconSize: 38,
      constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
      ),
      icon: Icon(icon),
    ),
  );
}
