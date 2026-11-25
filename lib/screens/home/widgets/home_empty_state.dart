import 'package:flutter/material.dart';
import '../../../widgets/responsive_scale.dart';
import '../../../theme/app_colors.dart';

/// 기기가 하나도 없을 때 보여주는 안내.
///
/// 가전 등록은 보호자 설정에서만 한다. 처음 설치할 때 보호자가 바로 들어갈 수 있도록
/// [onOpenGuardianSettings]로 보호자 설정을 여는 버튼을 둔다.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key, required this.onOpenGuardianSettings});

  final VoidCallback onOpenGuardianSettings;

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
            '등록된 가전이 없습니다.\n보호자가 아래 보호자 설정에서 가전을 등록하면 말하기로 쓸 수 있습니다.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14 * rs,
              height: 1.5,
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 16)),
          SizedBox(
            width: double.infinity,
            height: 52 * rs,
            child: Semantics(
              label: '보호자 설정 열기. 가전을 등록하고 버튼 위치를 설정합니다.',
              button: true,
              child: ElevatedButton(
                onPressed: onOpenGuardianSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14 * rs),
                  ),
                ),
                child: Text(
                  '보호자 설정 열기',
                  style: TextStyle(
                    fontSize: 16 * rs,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
