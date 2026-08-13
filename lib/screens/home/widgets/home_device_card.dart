import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../../widgets/responsive_scale.dart';
import '../../../theme/app_colors.dart';

class HomeDeviceCard extends StatelessWidget {
  // 스크린리더 커스텀 액션은 재빌드마다 새로 만들지 않도록 한 번만 생성한다.
  static final CustomSemanticsAction _manageAction = CustomSemanticsAction(
    label: '기기 관리 및 삭제',
  );

  const HomeDeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.onManage,
    this.managementEnabled = false,
  });

  final Map<String, dynamic> device;
  final VoidCallback onTap;
  final Function(LongPressStartDetails)? onLongPressStart;
  final Function(LongPressEndDetails)? onLongPressEnd;

  /// 스크린리더 접근성: 5초 길게 누르기(삭제)의 대안 액션.
  /// VoiceOver 로터 / TalkBack 액션 메뉴에서 바로 실행할 수 있게 한다.
  final VoidCallback? onManage;
  final bool managementEnabled;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * rs),
      child: Semantics(
        label: managementEnabled
            ? '${device['name']}. 현재 상태 ${device['status']}. 선택하려면 두 번 누르세요. 관리하려면 5초간 길게 누르세요.'
            : '${device['name']}. 현재 상태 ${device['status']}. 선택하려면 두 번 누르세요.',
        button: true,
        // onTap을 Semantics에 직접 등록 — ExcludeSemantics가 하위 Tree를
        // 가리기 때문에 GestureDetector의 탭이 Semantics로 올라오지 않는다.
        onTap: onTap,
        customSemanticsActions: (managementEnabled && onManage != null)
            ? {_manageAction: onManage!}
            : null,
        child: ExcludeSemantics(
          child: GestureDetector(
          onTap: onTap,
          onLongPressStart: onLongPressStart,
          onLongPressEnd: onLongPressEnd,
          onLongPressCancel: onLongPressEnd == null
              ? null
              : () => onLongPressEnd!(LongPressEndDetails()),
          child: Container(
            padding: EdgeInsets.all(22 * rs),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(24 * rs),
              border: Border.all(color: AppColors.borderDefault),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowSecondaryGlow,
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100 * rs,
                      height: 100 * rs,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24 * rs),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowPrimary,
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          IconData(
                            device['iconCodePoint'] as int,
                            fontFamily: 'MaterialIcons',
                          ),
                          color: Colors.black,
                          size: 48 * rs,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    Text(
                      device['name'] as String,
                      style: TextStyle(
                        fontSize: 26 * rs,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 10)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8 * rs,
                          height: 8 * rs,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8 * rs),
                        Text(
                          device['status'] as String,
                          style: TextStyle(
                            fontSize: 15 * rs,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 18)),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14 * rs),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12 * rs),
                      ),
                      child: Text(
                        '눌러서 제어하기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15 * rs,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),  // ExcludeSemantics
        ),
      ),
    );
  }
}
