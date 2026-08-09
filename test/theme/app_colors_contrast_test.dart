import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/theme/app_colors.dart';

void main() {
  group('AppColors 대비 (저시력 접근성)', () {
    test('보조 텍스트(textTertiary)는 배경 대비 AA(4.5:1) 이상이다', () {
      final onBackground = AppColors.getContrastRatio(
        AppColors.textTertiary,
        AppColors.background,
      );
      final onSurface = AppColors.getContrastRatio(
        AppColors.textTertiary,
        AppColors.surface,
      );
      expect(onBackground, greaterThanOrEqualTo(4.5));
      expect(onSurface, greaterThanOrEqualTo(4.5));
    });

    test('주요/보조 텍스트는 배경 대비 AAA(7:1) 이상이다', () {
      expect(
        AppColors.getContrastRatio(
          AppColors.textPrimary,
          AppColors.background,
        ),
        greaterThanOrEqualTo(7.0),
      );
      expect(
        AppColors.getContrastRatio(
          AppColors.textSecondary,
          AppColors.background,
        ),
        greaterThanOrEqualTo(7.0),
      );
    });
  });
}
