import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Touch Bridge 앱의 모든 텍스트 스타일을 중앙화
/// 설계 원칙:
/// - 시각장애인을 위한 큰 텍스트 (최소 16pt)
/// - 명확한 계층 구조
/// - 44pt 이상의 대형 텍스트는 명도 대비 4.5:1 이상
class AppText {
  AppText._();

  // ✅ Display Styles (매우 큰 텍스트 — 제목/모달)
  /// 초대형 제목 (34pt) — 완료/오류 화면, 모달 타이틀
  static const TextStyle displayLarge = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    height: 1.15,
    letterSpacing: -0.7,
  );

  /// 대형 제목 (28pt) — 버튼/주요 제목
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.4,
  );

  /// 중형 제목 (22pt) — 섹션 타이틀/앱바
  static const TextStyle displaySmall = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.4,
  );

  // ✅ Headline Styles (큰 텍스트 — 화면 제목)
  /// 대형 헤드라인 (32pt)
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// 중형 헤드라인 (26pt)
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// 소형 헤드라인 (20pt)
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.2,
  );

  // ✅ Title Styles (보조 제목)
  /// 대형 타이틀 (22pt)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: -0.2,
  );

  /// 중형 타이틀 (18pt)
  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
    letterSpacing: 0,
  );

  /// 소형 타이틀 (16pt)
  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
    letterSpacing: 0.1,
  );

  // ✅ Body Styles (본문 텍스트)
  /// 대형 본문 (18pt)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
    letterSpacing: 0,
  );

  /// 중형 본문 (16pt) — 기본
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
    letterSpacing: 0,
  );

  /// 소형 본문 (14pt)
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
    letterSpacing: 0.2,
  );

  // ✅ Label Styles (라벨/버튼 텍스트)
  /// 대형 라벨 (18pt) — 버튼 텍스트
  static const TextStyle labelLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: 0.1,
  );

  /// 중형 라벨 (14pt)
  static const TextStyle labelMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.3,
    letterSpacing: 0.2,
  );

  /// 소형 라벨 (10pt) — 하단 네비게이션 라벨
  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: 1.2,
  );

  // ✅ Semantic Styles (상태별)

  /// 비활성 텍스트
  static const TextStyle disabled = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    height: 1.5,
  );

  /// 성공 텍스트
  static const TextStyle success = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.success,
    height: 1.5,
  );

  /// 에러 텍스트
  static const TextStyle error = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.emergency,
    height: 1.5,
  );

  /// 경고 텍스트
  static const TextStyle warning = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.warning,
    height: 1.5,
  );

  /// 정보 텍스트
  static const TextStyle info = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.info,
    height: 1.5,
  );

  // ✅ Flutter Material TextTheme (호환성)
  static const TextTheme textTheme = TextTheme(
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    titleLarge: titleLarge,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
  );

  // ✅ Utility: 상태별 텍스트 스타일 반환
  static TextStyle getStyle({
    required bool isDisabled,
    required bool isSecondary,
    TextStyle baseStyle = bodyMedium,
  }) {
    if (isDisabled) {
      return baseStyle.copyWith(color: AppColors.textTertiary);
    }
    if (isSecondary) {
      return baseStyle.copyWith(color: AppColors.textSecondary);
    }
    return baseStyle;
  }
}
