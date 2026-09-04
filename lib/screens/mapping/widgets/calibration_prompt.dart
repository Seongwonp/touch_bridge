import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 매핑 화면에서 기준점(원점)이 아직 지정되지 않았을 때 보여주는 안내 오버레이.
class CalibrationPrompt extends StatelessWidget {
  const CalibrationPrompt({
    super.key,
    required this.scale,
    required this.selectedCount,
    required this.needsDimensions,
  });

  final double scale;
  final int selectedCount;
  final bool needsDimensions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(24 * scale),
        padding: EdgeInsets.all(20 * scale),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16 * scale),
          border: Border.all(color: AppColors.primary, width: 2 * scale),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12 * scale)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.gps_fixed_rounded,
              color: AppColors.primary,
              size: 40 * scale,
            ),
            SizedBox(height: 16 * scale),
            Text(
              '패널 4점 보정',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18 * scale,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8 * scale),
            Text(
              needsDimensions
                  ? '모서리 4개를 지정했습니다.\n아래에서 실제 패널 크기를 입력하세요.'
                  : '좌상단 → 우상단 → 우하단 → 좌하단 순서로\n모서리를 터치하세요. ($selectedCount/4)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14 * scale,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
