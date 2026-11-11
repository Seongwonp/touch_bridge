import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 매핑 화면에서 패널 4점 보정이 끝나기 전에 사진 바로 위에 보여주는 안내.
///
/// 예전에는 사진 한가운데에 반투명 검은 상자로 얹혀 찍어야 할 패널을 가렸다.
/// 지금은 사진 밖(위쪽)에 두므로 사진을 가리지 않는다.
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
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8 * scale),
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 10 * scale,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: AppColors.primary, width: 2 * scale),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '패널 4점 보정',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18 * scale,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4 * scale),
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
    );
  }
}
