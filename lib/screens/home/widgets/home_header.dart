import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/responsive_scale.dart';

/// 홈 화면 상단 헤더 (아이콘 + 제목 + 부제목).
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final rs = scale;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40 * rs,
          height: 40 * rs,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12 * rs),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowPrimary, blurRadius: 10),
            ],
          ),
          child: Icon(Icons.devices_rounded, color: Colors.black, size: 22 * rs),
        ),
        SizedBox(width: 12 * rs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '내 기기',
                style: TextStyle(
                  fontSize: 24 * rs,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: ResponsiveScale.v(context, 2)),
              Text(
                '기기를 선택하고 말하기 버튼을 누르세요',
                style: TextStyle(
                  fontSize: 13 * rs,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
