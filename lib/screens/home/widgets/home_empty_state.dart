import 'package:flutter/material.dart';
import '../../../widgets/responsive_scale.dart';
import '../../../theme/app_colors.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key, required this.guardianModeEnabled});

  final bool guardianModeEnabled;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Container(
      padding: EdgeInsets.all(ResponsiveScale.v(context, 16)),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20 * rs),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '초기 설정 안내',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16 * rs,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 10)),
          Text(
            guardianModeEnabled
                ? '1. 기기 관리에서 기기를 등록하세요\n2. 홈에서 기기를 선택하세요\n3. 말하기 버튼으로 음성 제어를 시작하세요'
                : '등록된 기기가 없습니다.\n보호자에게 기기 추가를 요청하세요.\n설정에서 보호자 모드를 켜면 기기를 등록할 수 있습니다.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14 * rs,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
