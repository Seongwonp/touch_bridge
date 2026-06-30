import 'package:flutter/material.dart';
import '../../../widgets/responsive_scale.dart';
import '../../../theme/app_colors.dart';

class HomeDeviceCard extends StatelessWidget {
  const HomeDeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.managementEnabled = false,
  });

  final Map<String, dynamic> device;
  final VoidCallback onTap;
  final Function(LongPressStartDetails)? onLongPressStart;
  final Function(LongPressEndDetails)? onLongPressEnd;
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
        child: GestureDetector(
          onTap: onTap,
          onLongPressStart: onLongPressStart,
          onLongPressEnd: onLongPressEnd,
          onLongPressCancel: onLongPressEnd == null
              ? null
              : () => onLongPressEnd!(LongPressEndDetails()),
          child: Container(
            padding: EdgeInsets.all(28 * rs),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(24 * rs),
              border: Border.all(color: AppColors.borderDefault),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowSecondaryGlow, blurRadius: 16, spreadRadius: 1),
              ],
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120 * rs,
                      height: 120 * rs,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24 * rs),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowPrimary, blurRadius: 16),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          IconData(
                            device['iconCodePoint'] as int,
                            fontFamily: 'MaterialIcons',
                          ),
                          color: Colors.black,
                          size: 56 * rs,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 24)),
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
                    SizedBox(height: ResponsiveScale.v(context, 28)),
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
        ),
      ),
    );
  }
}
