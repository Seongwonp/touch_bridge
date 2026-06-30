import 'dart:math';
import 'package:flutter/material.dart';

/// Touch Bridge 앱의 모든 색상을 중앙화
/// 설계 원칙:
/// - 시각장애인을 위한 고대비 다크 테마
/// - WCAG AAA 준수 (명도 대비 7:1 이상)
class AppColors {
  AppColors._();

  // ✅ Primary Colors (핵심)
  /// 순수 검정 — 배경
  static const Color background = Color(0xFF000000);
  
  /// 다크 서피스 — 카드/컨테이너
  static const Color surface = Color(0xFF020617); // 변경: 더 검은색

  /// 한 단계 더 밝은 서피스 — 카드가 배경에서 떠 보이도록 (모달/강조 카드)
  static const Color surfaceElevated = Color(0xFF0B1220);

  /// 주요 색상 — CTA/강조/성공
  static const Color primary = Color(0xFFFFEB00); // 노랑

  /// 보조 강조색 — 정보/상태 아이콘, 음성·연결 등 노랑과 구분이 필요한 강조
  static const Color secondary = Color(0xFF22D3EE); // 청록

  /// 텍스트 — 주요
  static const Color textPrimary = Color(0xFFFFFFFF); // 흰색
  
  /// 텍스트 — 보조
  static const Color textSecondary = Color(0xFFCBD5E1); // 더 밝은 회색
  
  /// 텍스트 — 약화 (비활성)
  static const Color textTertiary = Color(0xFF64748B); // 어두운 회색

  // ✅ Semantic Colors
  /// 성공/완료
  static const Color success = Color(0xFF22C55E); // 초록
  
  /// 경고/주의
  static const Color warning = Color(0xFFFFB020); // 주황
  
  /// 오류/위험/비상정지
  static const Color emergency = Color(0xFFFF3B30); // 빨강
  
  /// 정보/안내
  static const Color info = Color(0xFF3B82F6); // 파랑

  // ✅ Functional Colors
  /// 비활성 상태
  static const Color disabled = Color(0xFF64748B);
  
  /// 포커스 상태 (1탭 확인)
  static const Color focused = Color(0xFFFFFFFF); // 흰색 테두리
  
  /// 호버/터치 상태
  static const Color hover = Color(0x1AFFEB00); // 노랑 + 투명도
  
  /// 구분선
  static const Color divider = Color(0x14FFFFFF); // 흰색 + 투명도
  
  // ✅ Brand Colors
  /// 브랜드 컬러 (로고/헤더)
  static const Color brand = Color(0xFFFFEB00); // 노랑
  
  // ✅ Container/Background
  /// 다크 컨테이너
  static const Color darkContainer = Color(0x0F0F172A);
  
  /// 카드 배경
  static const Color cardHover = Color(0x1A1E293B);
  
  /// 모달 배경
  static const Color modalOverlay = Color(0x99000000);
  
  // ✅ Border & Outline (구버전과 호환)
  static const Color outline = Color(0xFF8A8A8A);
  
  /// 활성 상태 테두리
  static const Color borderActive = Color(0xFFFFFFFF);
  
  /// 일반 테두리
  static const Color borderDefault = Color(0x14FFFFFF);
  
  /// 강조 테두리 (포커스)
  static const Color borderFocus = Color(0x4DFFEB00);
  
  // ✅ Shadow Colors
  /// 주요 그림자 (노랑)
  static const Color shadowPrimary = Color(0x26FFEB00);
  
  /// 보조 그림자 (파랑)
  static const Color shadowSecondary = Color(0x063B82F6);
  
  /// 에러 그림자
  static const Color shadowError = Color(0x26FF3B30);

  /// 보조색 그림자 (청록 글로우)
  static const Color shadowSecondaryGlow = Color(0x2622D3EE);

  // ✅ Gradients
  /// 주요 CTA 버튼용 그라디언트 (노랑 → 진한 골드, 입체감)
  static const List<Color> primaryGradient = [Color(0xFFFFF066), Color(0xFFFFD400)];

  /// 상단 accent 라인 / 보조 강조용 그라디언트 (노랑 → 청록)
  static const List<Color> accentLineGradient = [Color(0xFFFFEB00), Color(0xFF22D3EE)];

  // ✅ Utility Methods
  
  /// 상태에 따른 버튼 색상
  static Color getButtonColor({
    required bool isPressed,
    required bool isDisabled,
    bool isPrimary = true,
  }) {
    if (isDisabled) return disabled;
    if (isPressed && isPrimary) return primary;
    return isPrimary ? primary : textSecondary;
  }
  
  /// 상태에 따른 텍스트 색상
  static Color getTextColor({
    required bool isDisabled,
    required bool isSecondary,
  }) {
    if (isDisabled) return textTertiary;
    return isSecondary ? textSecondary : textPrimary;
  }
  
  /// 상태에 따른 테두리 색상
  static Color getBorderColor({
    required bool isActive,
    required bool isFocused,
  }) {
    if (isFocused) return borderFocus;
    return isActive ? borderActive : borderDefault;
  }
  
  /// 명도 대비 검증 (WCAG AAA)
  static double getContrastRatio(Color foreground, Color background) {
    final fg = _getRelativeLuminance(foreground);
    final bg = _getRelativeLuminance(background);
    final lighter = fg > bg ? fg : bg;
    final darker = fg <= bg ? fg : bg;
    return (lighter + 0.05) / (darker + 0.05);
  }
  
  /// 상대 명도 계산 (W3C 공식)
  static double _getRelativeLuminance(Color color) {
    final r = _linearize((color.r * 255.0).round().clamp(0, 255) / 255);
    final g = _linearize((color.g * 255.0).round().clamp(0, 255) / 255);
    final b = _linearize((color.b * 255.0).round().clamp(0, 255) / 255);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
  
  /// 선형화 (감마 보정)
  static double _linearize(double value) {
    if (value <= 0.03928) {
      return value / 12.92;
    } else {
      return pow((value + 0.055) / 1.055, 2).toDouble();
    }
  }
}
