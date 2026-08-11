import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 매핑 화면에서 기준점(원점)이 아직 지정되지 않았을 때 보여주는 안내 오버레이.
class CalibrationPrompt extends StatelessWidget {
  const CalibrationPrompt({super.key, required this.scale});

  final double scale;

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
              '초기 위치 설정 (Calibration)',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18 * scale,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8 * scale),
            Text(
              '가전기기의 기준점(0,0) 위치를\n이미지 위에서 터치해 주세요.',
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
