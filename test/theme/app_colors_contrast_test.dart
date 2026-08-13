import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/theme/app_colors.dart';

double _contrast(Color fg, Color bg) => AppColors.getContrastRatio(fg, bg);

/// WCAG 2.2 기준
/// - AA 일반 텍스트: 4.5:1
/// - AA 큰 텍스트/아이콘: 3.0:1
/// - AAA 일반 텍스트: 7.0:1
const double kAA = 4.5;
const double kAALarge = 3.0;
const double kAAA = 7.0;

// CTA 버튼 배경(그라디언트)
const Color _gradientLight = Color(0xFFFFF066);
const Color _gradientDark = Color(0xFFFFD400);

void main() {
  group('AppColors WCAG 2.2 색상 대비 검증', () {
    // ── AA (4.5:1): 일반 텍스트 on 배경 ──────────────────────────────────
    group('텍스트 AA (≥4.5:1) on background', () {
      test('textPrimary(흰색)', () {
        expect(_contrast(AppColors.textPrimary, AppColors.background), greaterThanOrEqualTo(kAA));
      });
      test('textSecondary(밝은 회색)', () {
        expect(_contrast(AppColors.textSecondary, AppColors.background), greaterThanOrEqualTo(kAA));
      });
      test('textTertiary(중간 회색)', () {
        expect(_contrast(AppColors.textTertiary, AppColors.background), greaterThanOrEqualTo(kAA));
      });
    });

    group('텍스트 AA (≥4.5:1) on surface', () {
      test('textPrimary on surface', () {
        expect(_contrast(AppColors.textPrimary, AppColors.surface), greaterThanOrEqualTo(kAA));
      });
      test('textSecondary on surface', () {
        expect(_contrast(AppColors.textSecondary, AppColors.surface), greaterThanOrEqualTo(kAA));
      });
      test('textTertiary on surface', () {
        expect(_contrast(AppColors.textTertiary, AppColors.surface), greaterThanOrEqualTo(kAA));
      });
    });

    group('텍스트 AA (≥4.5:1) on surfaceElevated', () {
      test('textPrimary on surfaceElevated', () {
        expect(_contrast(AppColors.textPrimary, AppColors.surfaceElevated), greaterThanOrEqualTo(kAA));
      });
      test('textSecondary on surfaceElevated', () {
        expect(_contrast(AppColors.textSecondary, AppColors.surfaceElevated), greaterThanOrEqualTo(kAA));
      });
      test('textTertiary on surfaceElevated', () {
        expect(_contrast(AppColors.textTertiary, AppColors.surfaceElevated), greaterThanOrEqualTo(kAA));
      });
    });

    // ── AA (4.5:1): 상태/강조 색상 ───────────────────────────────────────
    group('상태 색상 AA (≥4.5:1) on background', () {
      test('primary(노랑) — CTA·강조', () {
        expect(_contrast(AppColors.primary, AppColors.background), greaterThanOrEqualTo(kAA));
      });
      test('secondary(청록) — 정보·연결', () {
        expect(_contrast(AppColors.secondary, AppColors.background), greaterThanOrEqualTo(kAA));
      });
      test('success(초록) — 완료', () {
        expect(_contrast(AppColors.success, AppColors.background), greaterThanOrEqualTo(kAA));
      });
      test('warning(주황) — 경고', () {
        expect(_contrast(AppColors.warning, AppColors.background), greaterThanOrEqualTo(kAA));
      });
      // emergency: 붉은색 계열은 AA(4.5:1)는 충족, AAA(7:1)는 해당 없음
      test('emergency(빨강) — 비상정지', () {
        expect(_contrast(AppColors.emergency, AppColors.background), greaterThanOrEqualTo(kAA));
      });
    });

    // ── AA 큰 텍스트/아이콘 (3:1): CTA 버튼 ────────────────────────────
    group('CTA 버튼 AA-large (≥3:1) — 검정 텍스트 on 노랑 배경', () {
      test('black on primary(#FFEB00)', () {
        expect(_contrast(Colors.black, AppColors.primary), greaterThanOrEqualTo(kAALarge));
      });
      test('black on gradientLight(#FFF066)', () {
        expect(_contrast(Colors.black, _gradientLight), greaterThanOrEqualTo(kAALarge));
      });
      test('black on gradientDark(#FFD400)', () {
        expect(_contrast(Colors.black, _gradientDark), greaterThanOrEqualTo(kAALarge));
      });
    });

    // ── AAA (7:1): 주요 텍스트 + 핵심 강조색 ───────────────────────────
    group('주요 텍스트 AAA (≥7:1) on background', () {
      test('textPrimary', () {
        expect(_contrast(AppColors.textPrimary, AppColors.background), greaterThanOrEqualTo(kAAA));
      });
      test('textSecondary', () {
        expect(_contrast(AppColors.textSecondary, AppColors.background), greaterThanOrEqualTo(kAAA));
      });
      test('textTertiary', () {
        expect(_contrast(AppColors.textTertiary, AppColors.background), greaterThanOrEqualTo(kAAA));
      });
      test('primary(노랑)', () {
        expect(_contrast(AppColors.primary, AppColors.background), greaterThanOrEqualTo(kAAA));
      });
      test('secondary(청록)', () {
        expect(_contrast(AppColors.secondary, AppColors.background), greaterThanOrEqualTo(kAAA));
      });
      test('success(초록)', () {
        expect(_contrast(AppColors.success, AppColors.background), greaterThanOrEqualTo(kAAA));
      });
      test('warning(주황)', () {
        expect(_contrast(AppColors.warning, AppColors.background), greaterThanOrEqualTo(kAAA));
      });
      test('black on primary — CTA 버튼 텍스트', () {
        expect(_contrast(Colors.black, AppColors.primary), greaterThanOrEqualTo(kAAA));
      });
    });

    // ── disabled: WCAG 1.4.3 예외 ────────────────────────────────────────
    group('disabled 색상 — WCAG 1.4.3 비활성 예외', () {
      test('disabled는 의도적으로 AA 미만 (비활성 상태는 기준 제외)', () {
        final ratio = _contrast(AppColors.disabled, AppColors.background);
        // WCAG 1.4.3: 비활성(disabled) UI 컴포넌트는 색상 대비 기준 적용 제외.
        // disabled가 AA 미만인 것이 의도된 설계임을 테스트로 명시한다.
        expect(ratio, lessThan(kAA),
            reason: 'disabled는 비활성 의미 전달을 위해 의도적으로 저대비 (WCAG 1.4.3 예외)');
      });
    });

    // ── 대비 비율 계산 정밀도 검증 ──────────────────────────────────────
    group('getContrastRatio 수치 정밀도', () {
      test('검정-흰색 최대 대비 21:1', () {
        final ratio = _contrast(Colors.white, Colors.black);
        expect(ratio, closeTo(21.0, 0.1));
      });
      test('동일 색상 대비 1:1', () {
        final ratio = _contrast(Colors.black, Colors.black);
        expect(ratio, closeTo(1.0, 0.01));
      });
    });
  });
}
