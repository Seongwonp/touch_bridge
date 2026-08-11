import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'responsive_scale.dart';

/// BLE 업로드 진행률을 표시하는 로딩 인디케이터
/// 시각장애인을 위한 음성 피드백 포함
class BleLoadingOverlay extends StatelessWidget {
  final double progress; // 0.0 ~ 1.0
  final String message;
  final bool isCompleted;
  final VoidCallback? onDismiss;

  const BleLoadingOverlay({
    super.key,
    required this.progress,
    required this.message,
    this.isCompleted = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final percentage = (progress * 100).toStringAsFixed(0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: ResponsiveScale.v(context, 280),
          padding: EdgeInsets.all(ResponsiveScale.v(context, 24)),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderFocus, width: 2),
            boxShadow: [
              BoxShadow(
                color: isCompleted
                    ? AppColors.shadowPrimary
                    : AppColors.shadowSecondary,
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 진행 원형 표시
              SizedBox(
                width: ResponsiveScale.v(context, 120),
                height: ResponsiveScale.v(context, 120),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 배경 원
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.borderDefault,
                      ),
                    ),
                    // 진행 원
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCompleted ? AppColors.success : AppColors.primary,
                      ),
                    ),
                    // 중앙 텍스트 (백분율)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          label: '진행률 $percentage 퍼센트',
                          child: Text(
                            '$percentage%',
                            style: AppText.displayMedium.copyWith(
                              fontSize: 28 * rs,
                              color: isCompleted
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        if (isCompleted)
                          Semantics(
                            label: '완료됨',
                            child: Text(
                              '완료',
                              style: AppText.labelMedium.copyWith(
                                color: AppColors.success,
                                fontSize: 12 * rs,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveScale.v(context, 20)),

              // 메시지
              Semantics(
                label: message,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppText.bodyMedium.copyWith(
                    fontSize: 16 * rs,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: ResponsiveScale.v(context, 20)),

              // 세부 진행 정보 (모바일 사용성)
              if (!isCompleted)
                Container(
                  padding: EdgeInsets.all(ResponsiveScale.v(context, 12)),
                  decoration: BoxDecoration(
                    color: AppColors.darkContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Semantics(
                    label: '업로드 진행 중. 잠시만 기다려주세요.',
                    child: Text(
                      '업로드 진행 중...\n잠시만 기다려주세요.',
                      textAlign: TextAlign.center,
                      style: AppText.labelSmall.copyWith(
                        fontSize: 11 * rs,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

              if (isCompleted) ...[
                SizedBox(height: ResponsiveScale.v(context, 16)),
                Semantics(
                  label: '확인 버튼',
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    height: ResponsiveScale.v(context, 56),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onDismiss,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              '확인',
                              style: AppText.displaySmall.copyWith(
                                fontSize: 18 * rs,
                                color: AppColors.background,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 모달 BLE 로딩 표시 헬퍼
class BleLoadingHelper {
  static Future<void> showProgress(
    BuildContext context, {
    required String message,
    required Future<void> Function(Function(double) onProgress) onExecute,
  }) async {
    double progress = 0.0;
    bool completed = false;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (_, setState) {
          // 작업 실행
          onExecute((newProgress) {
            setState(() => progress = newProgress.clamp(0.0, 1.0));
          }).then((_) {
            setState(() => completed = true);
          });

          return BleLoadingOverlay(
            progress: progress,
            message: message,
            isCompleted: completed,
            onDismiss: completed ? () => Navigator.pop(context) : null,
          );
        },
      ),
    );
  }
}
