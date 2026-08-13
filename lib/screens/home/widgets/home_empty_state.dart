import 'package:flutter/material.dart';
import '../../../widgets/responsive_scale.dart';
import '../../../theme/app_colors.dart';

/// 기기가 하나도 없을 때 보여주는 안내.
///
/// 보호자 모드가 꺼져 있어도(=혼자 쓰는 시각장애인 사용자) "보호자에게
/// 요청하세요"만 말하고 끝내는 대신, [onAddDevicePressed]로 직접 기기
/// 연결 화면에 들어갈 수 있는 자기주도 경로를 항상 제공한다.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.guardianModeEnabled,
    required this.onAddDevicePressed,
  });

  final bool guardianModeEnabled;
  final VoidCallback onAddDevicePressed;

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
                : '등록된 기기가 없습니다.\n아래 버튼으로 직접 기기를 추가하거나, 보호자에게 요청할 수 있습니다.',
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
              label: '기기 추가하기. 블루투스로 기기를 연결하고 버튼 위치를 설정합니다.',
              button: true,
              child: ElevatedButton(
                onPressed: onAddDevicePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14 * rs),
                  ),
                ),
                child: Text(
                  '기기 추가하기',
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
