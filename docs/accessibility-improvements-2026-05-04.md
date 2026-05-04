# Touch Bridge 접근성 개선 작업 정리 (2026-05-04)

## 목표
- 시각장애인/저시력 사용자에게 더 친화적인 사용 경험 제공
- 음성 안내, 글자 가독성, 조작 안정성 중심으로 개선

## 이번 작업 범위
1. 전역 접근성 설정 상태 추가
2. 설정 화면에서 접근성 토글 제어 가능하도록 UI 연결
3. TTS가 접근성 설정(음성 안내 on/off)을 따르도록 연동
4. 전역 텍스트 표시 확장(큰 글씨) 반영
5. 터치 타겟 기본 정책 강화

## 변경 파일
- `lib/services/accessibility_settings.dart` (신규)
- `lib/services/tts_service.dart`
- `lib/main.dart`
- `lib/screens/settings/settings_screen.dart`
- `lib/theme/app_theme.dart`

## 상세 변경 사항

### 1) 전역 접근성 상태 관리 추가
- `AccessibilitySettings` 싱글턴 `ChangeNotifier` 추가
- 관리 항목:
  - `voiceGuidanceEnabled` (음성 안내)
  - `largeTextEnabled` (큰 글씨)
  - `highContrastEnabled` (고대비 모드)

### 2) TTS 음성 안내 토글 연동
- `TtsService.speak()`에서 `voiceGuidanceEnabled == false`면 즉시 return
- 사용자 설정으로 음성 안내를 완전히 끌 수 있도록 반영

### 3) 앱 전역 텍스트 접근성 적용
- `main.dart`에서 `AnimatedBuilder`로 접근성 설정 구독
- `MediaQuery` 재정의:
  - `largeTextEnabled`가 켜지면 `TextScaler.linear(1.18)` 적용
  - `highContrastEnabled` 상태를 `boldText`에 반영

### 4) 설정 화면 접근성 섹션 추가
- 기존 설정 화면에 `접근성` 섹션 신설
- 스위치 3종 추가:
  - 음성 안내
  - 큰 글씨
  - 고대비 모드
- 토글 시 전역 설정에 즉시 반영되고 음성으로 상태 안내

### 5) 터치 타겟 기본 정책 강화
- `AppTheme`에 `materialTapTargetSize: MaterialTapTargetSize.padded` 반영
- 작은 조작부의 탭 난이도 완화

## 검증
- `flutter analyze` 실행 결과: `No issues found`

## 현재 한계 / 다음 작업 권장
- `highContrastEnabled`는 현재 텍스트 볼드 중심 반영이며, 하드코딩 컬러가 많은 화면은 효과가 제한적임
- 다음 단계 권장:
  1. 하드코딩 색상 토큰화 (고대비 팔레트 분기)
  2. 주요 화면 텍스트/버튼 크기 최소 기준 통일
  3. 스크린리더 포커스 순서 및 live region 사용 최소화 점검
  4. 접근성 설정 로컬 저장(shared_preferences)으로 앱 재시작 유지
