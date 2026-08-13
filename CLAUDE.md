# Touch Bridge — AI Context Document

## 프로젝트 개요

**터치 브릿지 (Touch Bridge)** — 시각장애인을 위한 가전 터치패드 자동 입력 시스템

- **팀:** 3팀 멜론머스크 (박성원 · 서예솔)
- **공모전:** 2026 한이음 드림업
- **기간:** 2026.4.1 ~ 2026.10.30
- **앱 담당:** 박성원 (단독 개발)
- **작업 브랜치:** `Touch_bridge_b`

## 문제 정의

전자레인지·세탁기·키오스크 등 터치패널 기반 가전이 확산되면서 시각장애인의 접근성 문제가 심화됨.
- 버튼 위치 파악이 어려워 탐색 중 오작동 발생
- 점자 스티커/음성 안내는 여전히 사용자가 정확한 위치를 직접 터치해야 함
- 스마트홈 시스템은 비용이 높고 일부 기기만 호환

## 해결책

가전 터치패드 위에 **부착하는 IoT 장치**가 스마트폰 앱/음성 명령을 받아 **물리적으로 버튼을 대신 눌러주는** 시스템

## 하드웨어 (연동 대기 중)

3단계 전략:
1. **초슬림 키캡 (5.1mm)** — 정전용량 센싱 + 음성 안내, 오프라인 동작
2. **범용 SG90** — 랙&피니언 X/Y 레일로 버튼 위치 이동 후 물리 터치
3. **CoreXY 레일** — 솔레노이드 + CoreXY 구조로 전 영역 정밀 제어

**핵심 부품:** ESP32 (BLE 5.0 GATT), SG90/NEMA14 모터, 솔레노이드, 전류·온도 센서

## Flutter 앱 — 기술 스택

```
Flutter 3.x / Dart 3.x
flutter_tts 4.x        — TTS 음성 안내 (시각장애인 피드백 핵심)
speech_to_text 7.x     — 음성 명령 인식 (STT)
google_generative_ai   — Gemini AI 음성 명령 파싱 + Vision 버튼 매핑
flutter_dotenv         — API 키 환경 변수 관리
shared_preferences     — 설정·기기목록·버튼매핑 영속화
image_picker           — 카메라/갤러리 이미지 선택
mobile_scanner 6.x     — QR 코드 실시간 스캔 (Android/iOS)
http                   — HTTP 통신 (추후 사용)
path_provider          — 파일 경로 (추후 사용)
```

## 앱 아키텍처

```
lib/
├── main.dart                              # 앱 진입점, dotenv 로드, AccessibilitySettings 바인딩
├── screens/
│   ├── main_navigation_screen.dart        # 모드별(사용자/보호자) 하단 내비게이션 (이중 탭 확인 패턴)
│   ├── home/
│   │   ├── home_screen.dart               # 기기 카드 스와이프 (PageView) + 동적 기기 관리
│   │   ├── appliance_selection_screen.dart
│   │   └── widgets/                       # home_header, home_voice_action_button, device_page_indicator,
│   │                                       # home_footer_nav_hint, home_device_card, home_add_device_card,
│   │                                       # home_empty_state, control_mode_sheet
│   ├── control/remote_control_screen.dart, image_control_screen.dart, course_control_screen.dart
│   ├── voice/
│   │   ├── voice_listening_screen.dart    # STT + Gemini AI 음성 명령 (5초 침묵 감지)
│   │   └── widgets/                       # voice_wave_visualizer, voice_action_buttons, voice_example_commands
│   ├── safety/
│   │   ├── emergency_stop_screen.dart     # 비상 정지 (3초 홀드 OR "멈춰" 음성)
│   │   └── stop_done_screen.dart          # 정지 완료 확인 화면 (단일 "홈으로" 버튼만, 가짜 탭 없음)
│   ├── settings/
│   │   ├── settings_screen.dart, device_management_screen.dart, developer_console_screen.dart
│   │   └── widgets/                       # settings_form_widgets, esp_connection_panel, esp_select_sheet,
│   │                                       # jog_control_panel
│   ├── connection/
│   │   ├── device_connect_screen.dart     # 기기 연결 (QR/BLE/NFC)
│   │   └── qr_scan_screen.dart            # QR 코드 실시간 스캔 (mobile_scanner)
│   └── mapping/
│       ├── photo_mapping_screen.dart      # 유동 rows×cols 버튼 매핑 (기기별 저장)
│       ├── manual_mapping_screen.dart
│       ├── photo_mapping_view_model.dart  # ChangeNotifier — AI매핑/저장/BLE업로드 상태 (분리 안 함, 전담 테스트 없어서 보존)
│       └── widgets/                       # calibration_prompt, mapping_image_view, mapping_markers_layer,
│                                           # point_actions_sheet, mapping_form_controls 등
├── services/
│   ├── tts_service.dart                   # Singleton TTS (flutter_tts 래퍼)
│   ├── ble_service.dart                   # BLE 스캔/연결/명령 전송 (인증은 ble_security_session.dart에 위임)
│   ├── ble_security_session.dart          # HMAC challenge-response 인증 세션
│   ├── home_device_store.dart             # `home_devices` SharedPreferences 단일 접근 지점
│   ├── voice_text_matcher.dart            # 긍정/부정 응답 판별 순수 함수
│   ├── accessibility_settings.dart        # Singleton ChangeNotifier (설정 영속화)
│   └── timer_service.dart                 # 카운트다운 타이머
├── theme/
│   ├── app_colors.dart                    # 고대비 컬러 시스템 + 그라디언트 토큰
│   ├── app_text.dart                      # 큰 글씨 타이포그래피
│   └── app_theme.dart                     # ThemeData
└── widgets/
    ├── emergency_button.dart              # 비상 정지 버튼 위젯
    ├── info_card.dart                     # 정보 카드
    ├── primary_button.dart                # 이중 탭 확인 버튼
    ├── responsive_scale.dart              # 반응형 스케일 (기준: Galaxy S20)
    └── top_app_bar.dart                   # 공통 상단 앱바
```

> 화면별 `widgets/` 하위 디렉토리는 해당 화면 전용 컴포넌트만 모아두는 패턴 (2026-06-30 구조 리팩토링에서 도입). 새 화면을 200줄 이상으로 키우게 되면 같은 패턴으로 쪼개는 것을 우선 검토할 것.

## 핵심 UX 패턴

### 이중 탭 확인 (Double-tap Confirmation)
모든 중요한 액션은 두 번 탭해야 실행됨. 4초 내 두 번째 탭이 없으면 자동 취소.
```
1탭: "XXX 버튼입니다. 한 번 더 누르면 실행합니다." + 햅틱 medium
4초 타임아웃 → 자동 취소
2탭: 실행 + 햅틱 light
```

### 비상 정지
- 버튼 3초 홀드 OR 음성 "멈춰"/"정지"/"그만"/"중단"/"stop"
- AnimationController로 진행바 표시 (3초)
- 완료 → StopDoneScreen

### 스와이프 뒤로가기
오른쪽 스와이프 (velocity > 450) → 이전 화면
TTS: "이전 화면으로 돌아갑니다."

### TTS 피드백 패턴
- 화면 진입: 화면 이름 + 조작 방법 안내
- 버튼 첫 탭: `"[버튼명] 버튼입니다. 한 번 더 누르면 실행합니다."`
- 버튼 실행: `"[동작] 실행합니다."`
- 완료: `"완료되었습니다."` or `"작동이 안전하게 중단되었습니다."`

### 기기 목록 관리 (HomeScreen)
- `DeviceInfo` 클래스: id(immutable), name, status, iconCodePoint → JSON 직렬화
- SharedPreferences 키: `home_devices`
- 상단 "+" 버튼: 이름 + 아이콘 8종 선택 → 추가
- 카드 롱프레스: 수정 / 버튼 매핑 / 삭제 Bottom Sheet
- 기본 기기 3개는 저장된 데이터 없을 때만 표시

### 버튼 매핑 (PhotoMappingScreen)
- `deviceId` / `deviceName` 파라미터로 기기별 독립 저장
- SharedPreferences 키: `mapping_grid_<deviceId>`, `mapping_device_type_<deviceId>`
- 전역(기기 미지정) 키: `mapping_grid_global`
- 홈 화면 롱프레스 → "버튼 매핑" 선택 시 기기명 전달하며 진입
- 기존 `mapping_grid_<deviceName>` 데이터는 홈 로드시 `deviceId` 키로 자동 마이그레이션

## 음성 명령 (Gemini AI)

`VoiceListeningScreen`에서 STT로 음성을 받아 처리:

**1단계 — 간단한 규칙 체크 (`_checkSimpleRules`)**
"30초 시작", "1분 시작", "취소/정지/그만" 등 자주 쓰는 명령은 Gemini 호출 없이 즉시 처리.

**2단계 — 백엔드 AI 파싱 API 호출 (버튼 ID 시퀀스 방식)**
```json
{
  "action": "EMERGENCY_STOP | NAVIGATE | MICROWAVE_CONTROL | NONE",
  "commands": ["BT-02", "BT-05"],
  "target": "connection | mapping | settings | null",
  "message": "사용자에게 전달할 메시지"
}
```

**전자레인지 버튼 규격 (논리 버튼 ID, 그리드 크기와 분리)**
| 버튼 | 동작 | 시간(초) |
|------|------|----------|
| BT-01 | 10초 추가 | 10 |
| BT-02 | 30초 추가 | 30 |
| BT-03 | 1분 추가 | 60 |
| BT-04 | 5분 추가 | 300 |
| BT-05 | 시작 | — |
| BT-06 | 취소/정지 | — |
| BT-07 | 해동 | — |
| BT-08 | 우유 | — |
| BT-09 | 자동조리 | — |

`_calculateSeconds(commands)` — 버튼 시퀀스에서 총 초를 계산해 `EmergencyStopScreen`에 전달.
버튼 ID 시퀀스는 기기별 매핑(rows×cols)에 따라 좌표로 변환되어 `BleService.sendPress()`로 전송됨.

- 5초 침묵 감지: 말 없음 → 재시도 안내 / 말 있었음 → 자동 분석
- Chrome `onStatus: 'done'` 처리 포함

## 환경 설정 (.env)

```
AI_BACKEND_URL=http://127.0.0.1:8000
```
앱은 API 키를 직접 보관하지 않고 백엔드 경유로 AI 기능을 사용.

## 플랫폼별 TTS/STT 주의사항

| 플랫폼 | TTS | STT | 비고 |
|--------|-----|-----|------|
| Android | ✅ | ✅ | |
| iOS | ✅ | ✅ | |
| macOS 앱 | ❌ | ❌ | macOS 26 beta TCC 버그 — OS 정식 출시 후 재확인 |
| Chrome (웹) | ✅ | ✅ | 첫 사용자 탭 이후 TTS 활성화 (자동재생 정책) |

**macOS 가드 패턴** (tts_service.dart, voice/emergency_stop 화면):
```dart
if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) return;
```

## 디자인 원칙 (접근성 우선)

### 색상 (고대비 다크 테마, `lib/theme/app_colors.dart` 기준 — 2026-06-30 갱신)
| 용도 | 색상 | Hex |
|------|------|-----|
| 배경 | 순수 검정 | #000000 |
| 서피스 | 다크 서피스 | #020617 |
| 서피스(카드 강조용, 한 단계 밝음) | `surfaceElevated` | #0B1220 |
| 주요 색상 | 노랑 (고가시성) | #FFEB00 |
| 보조 강조색 | 청록 (`secondary`) | #22D3EE |
| 텍스트 | 흰색 | #FFFFFF |
| 보조 텍스트 | 밝은 회색 | #CBD5E1 |
| 비상/위험 | 빨강 | #FF3B30 |
| 성공 | 초록 | #22C55E |
| 경고 | 주황 | #FFB020 |

그라디언트(`primaryGradient`/`accentLineGradient`)는 CTA 버튼·아이콘 컨테이너·상단 accent 라인에 사용. 새 색상이 필요하면 항상 `AppColors`에 토큰을 추가하고, 화면에 직접 `Color(0xFF...)`를 하드코딩하지 않는다 — 토큰화 일괄 작업 중 불투명 색이 투명 토큰으로 잘못 매핑된 사고가 있었으므로 (`borderDefault`는 8% 불투명도 테두리 전용, 버튼 배경 등 솔리드 채움에는 절대 쓰지 않음).

### UX 원칙
- **Look-free**: 화면 안 봐도 음성+진동으로 파악 가능
- **Error-safe**: 이중 확인 + 즉시 취소 가능 (15초 타임아웃, WCAG 2.2.1)
- **Multimodal**: 음성 안내(TTS) + 햅틱 진동 + 고대비 큰 글씨

### 접근성 설정 (AccessibilitySettings)
- `voiceGuidanceEnabled`: TTS 켜기/끄기 (기본 true)
- `largeTextEnabled`: 텍스트 1.18배 확대 (기본 false)
- `highContrastEnabled`: boldText 강화 (기본 false)

## 접근성 구현 상세 (2026-08 고도화)

### 준수 표준
| 표준 | 등급 | 비고 |
|------|------|------|
| WCAG 2.2 AA | 준수 | 텍스트 4.5:1, 큰 텍스트 3:1, 타임아웃 15초 |
| WCAG 2.2 AAA | 핵심 색상 준수 | textPrimary/secondary/tertiary, primary, secondary, success, warning ≥ 7:1 |
| KS X 3253 | 준수 | 한국 모바일 앱 접근성 18개 항목 |

### 스크린리더 (TalkBack/VoiceOver) 지원 패턴

| 패턴 | 구현 위치 | 설명 |
|------|-----------|------|
| TTS 이중 발화 방지 | `tts_service.dart` | 스크린리더 활성 시 navigation 우선순위 TTS 억제 (interrupt:true는 result로 승격해 예외 허용) |
| 스크린리더 감지 | `accessibility_settings.dart` | `isScreenReaderActive` — PlatformDispatcher 비반응형 게터 |
| 최소 터치 영역 | `button_marker.dart`, `mapping_markers_layer.dart` | `.clamp(48.0, double.infinity)` + `HitTestBehavior.opaque` |
| CustomSemanticsAction | `button_marker.dart`, `main_navigation_screen.dart`, `home_device_card.dart` | 롱프레스·숨겨진 제스처를 스크린리더 액션 메뉴로 노출 |
| ExcludeSemantics | `home_device_card.dart`, `home_add_device_card.dart`, `emergency_stop_screen.dart`, `top_app_bar.dart` | 카드 하위 Text 중복 낭독 방지 — 부모 Semantics(onTap) 명시 필수 |
| Live Region | `voice_listening_screen.dart`, `primary_button.dart` | `Semantics(liveRegion: true)` — 상태 변화 자동 낭독 |
| Semantics value | `emergency_stop_screen.dart` | `Semantics(label:'남은 시간', value: 'MM:SS')` — 포커스 시 타이머 값 읽기 |
| heading 마킹 | `top_app_bar.dart` | `Semantics(header: true)` — 화면 제목을 heading으로 등록 |
| 카운트다운 구간 TTS | `emergency_stop_screen.dart` | 5분·2분·1분·30초·10초·5초·3초 구간에서 자동 음성 알림 |
| 이중 탭 타임아웃 | 전체 화면 | 15초 통일 (WCAG 2.2.1: 최소 20초, 앱 특성상 15초 적용) |
| 200% 폰트 대응 | `emergency_button.dart`, `primary_button.dart` | `ConstrainedBox(minHeight:)` — 고정 height 제거 |

### 색상 대비 검증 (`test/theme/app_colors_contrast_test.dart`)
`AppColors.getContrastRatio()` (IEC 61966-2-1 sRGB 공식, 지수 2.4)로 자동 검증.
- **AA (≥4.5:1)**: 모든 텍스트 색상 × background/surface/surfaceElevated, 모든 상태 색상(emergency 포함)
- **AAA (≥7:1)**: textPrimary, textSecondary, textTertiary, primary, secondary, success, warning, black-on-primary
- **disabled**: WCAG 1.4.3 예외 — 의도적 저대비 (4.42:1) 테스트로 명시

### 참고문헌
- WCAG 2.2: https://www.w3.org/TR/WCAG22/
- 한국형 웹 콘텐츠 접근성 지침 2.2 (KWCAG 2.2)
- KS X 3253:2022 모바일 애플리케이션 접근성 지침
- Flutter Semantics API: https://api.flutter.dev/flutter/widgets/Semantics-class.html
- Android TalkBack 개발자 가이드: https://developer.android.com/guide/topics/ui/accessibility
- iOS VoiceOver 개발자 가이드: https://developer.apple.com/accessibility/

## 하드웨어 BLE 프로토콜

```
ESP32 GATT Server
Service UUID    : 0000FFE0-0000-1000-8000-00805F9B34FB
Characteristic  : 0000FFE1-0000-1000-8000-00805F9B34FB

명령 포맷 (JSON string):
{ "action": "press", "x": 0, "y": 1, "deviceId": "microwave_1" }
```

BLE 연동 구현 파일: `lib/services/ble_service.dart`
- 구현 메서드: `scan`, `connect`, `disconnect`, `sendPress`, `sendEmergencyStop`
- 패키지: `flutter_blue_plus`
- 연결 지점: `device_connect_screen.dart`(스캔/연결), `voice_listening_screen.dart`(명령 전송)

## QR 코드 포맷 (하드웨어 QR 출력 시 참고)

```json
{"deviceId": "esp32_001", "name": "전자레인지", "type": "microwave"}
```
- `name` 필수, `deviceId`·`type` 선택
- plain text도 허용 (기기명으로 사용)

## 개발 현황

### 완료 ✅
- [x] 앱 기본 구조 및 4탭 네비게이션
- [x] 이중 탭 확인 패턴 (모든 화면)
- [x] TTS 서비스 (Singleton, 한국어, 설정 영속화)
- [x] STT + Gemini AI 음성 명령 (5초 침묵 감지 포함)
- [x] 비상 정지 화면 (3초 홀드 + 음성)
- [x] 설정 화면 (접근성, 음성 안내, 가디언 모드)
- [x] 기기 연결 화면 (QR/BLE/NFC UI)
- [x] QR 스캔 실제 구현 (mobile_scanner, Android/iOS)
- [x] 사진 매핑 화면 (Gemini Vision + 유동 rows×cols 그리드)
- [x] Semantics 접근성 태그 전체 적용 (WCAG 2.2 AA/AAA, KS X 3253 준수)
- [x] SharedPreferences 설정·기기목록·버튼매핑 영속화
- [x] 기기 목록 동적 관리 (추가/수정/삭제)
- [x] 기기별 버튼 매핑 독립 저장
- [x] RemoteControlScreen 기기명 파라미터화
- [x] Chrome 웹 지원 (TTS/STT 모두 동작)
- [x] macOS TCC 버그 workaround

### 대기 중 ⏳
- [x] BLE 실제 연동 1차 — `ble_service.dart` 구현 + 연결 화면/음성 명령 전송 연동
- [x] 데이터 무결성 1차 — `deviceId` 도입 + name 기반 매핑 키 자동 마이그레이션
- [x] 보안/운영성 1차 — AI 키 클라이언트 분리 (백엔드 프록시 API)
- [x] 테스트 체계 확장 1차 — 명령 규칙/시간 계산/좌표 매핑 단위 테스트 추가
- [x] 테스트 체계 확장 2차 — BLE 연결 흐름 위젯 테스트 추가
- [x] 접근성 실험 지표화 1차 — 작업/완료/정지/타임아웃 지표 수집 및 설정 화면 노출
- [x] 심사용 패키징 — 심사 요약서/데모 스크립트/재현 런북 문서화
- [x] 스크린리더 고도화 — ExcludeSemantics, CustomSemanticsAction, liveRegion, heading, Semantics value
- [x] 색상 대비 자동 검증 — WCAG AA/AAA 단위 테스트 (`test/theme/app_colors_contrast_test.dart`)
- [x] 카운트다운 구간 TTS — 비상정지 화면 5분/2분/1분/30초/10초/5초/3초 자동 알림
- [x] BLE 자동 재연결 — 지수 백오프 (2→4→8초), 최대 3회, `BleReconnectState` 스트림
- [x] BleStatusBanner 위젯 — `Semantics(liveRegion: true)`, 재연결 중 스피닝 아이콘, TTS 안내
- [x] 가전 음성 명령 확장 — `WashingMachineCommandService`, `AcCommandService`, `ApplianceCommandRouter`
- [x] 기기 타입별 라우팅 — `ActiveDeviceService.getActiveDeviceType()`, 기기 등록 시 `deviceType` 저장
- [x] BottomSheet 포커스 관리 — `FocusNode.requestFocus()` in `addPostFrameCallback`, TalkBack 첫 요소 자동 포커스
- [x] 단위 테스트 160개 자동화 (BLE 재연결 16개 + 가전 명령 라우터 25개 추가)

## 하드웨어 연동 후 해야 할 일 (TODO)

> 이 섹션은 하드웨어가 완성되면 순서대로 테스트·구현할 항목 목록이다.

### 최우선 (하드웨어 연결 즉시)
- [ ] **BLE 실기기 E2E 검증** — 실제 ESP32에 연결해 `sendPress()` / `sendEmergencyStop()` 동작 확인
  - 확인 항목: ACK 수신, 타임아웃 처리, 재연결 후 명령 재전송
  - 파일: `lib/services/ble_service.dart`, `lib/services/mapping_execution_service.dart`
- [ ] **GRBL G-code 응답 번역** — Arduino가 보내는 `ok` / `error:N` / `<Idle|...>` 메시지를 한국어 TTS로 변환
  - 파일: `lib/services/ble_service.dart`의 notification 핸들러 (`_notifySub`)
- [ ] **자동 재연결 타이머 통합 테스트** — 실기기에서 전원을 껐다 켰을 때 2→4→8초 백오프 정상 동작 확인
  - 파일: `lib/services/ble_service.dart:_maybeScheduleReconnect()`
- [ ] **버튼 매핑 물리 좌표 보정** — 기기마다 달라지는 X/Y offset 값을 보정할 수 있는 캘리브레이션 UI
  - 파일: `lib/screens/mapping/manual_mapping_screen.dart`

### 중요 (하드웨어 1차 검증 후)
- [ ] **기기 상태 실시간 모니터링** — ESP32에서 전류·온도 센서 데이터를 BLE notify로 수신해 화면에 표시
  - 추가할 파일: `lib/services/hardware_sensor_service.dart`
  - UI: `lib/screens/settings/developer_console_screen.dart`에 센서 패널 추가
- [ ] **세탁기·에어컨 버튼 매핑 프리셋** — `WashingMachineCommandService.BT-W01~09` / `AcCommandService.BT-A01~09` 논리 ID를 기기별 그리드 좌표로 변환하는 매핑 프리셋 파일 (`assets/presets/`)
- [ ] **음성 명령 → 실제 BLE 시퀀스 연결** — 세탁기·에어컨 `WASHER_CONTROL` / `AC_CONTROL` 액션을 `VoiceListeningScreen._handleCommand`에서 BLE 전송으로 연결
  - 파일: `lib/screens/voice/voice_listening_screen.dart:_handleCommand()`
  - 현재: `MICROWAVE_CONTROL`만 BLE 전송 구현됨

### 선택 (공모전 후반)
- [ ] **가디언 알림 (Firebase)** — 비상 정지 이벤트 발생 시 보호자 스마트폰에 Push 알림
- [ ] **macOS TTS/STT** — macOS 26 정식 출시 후 TCC 권한 재확인
- [ ] **기기 상태 자동 저장** — 기기 사용 시간, 총 누른 횟수 집계 → 접근성 실험 지표 고도화
- [ ] **멀티 ESP32 지원** — 여러 가전에 각각 ESP32를 붙이고 하나의 앱에서 전환
- [ ] **오프라인 음성 명령** — STT 대신 온디바이스 음성 인식 (speech_to_text → Whisper/Picovoice)

## 가전 명령 서비스 현황

| 서비스 | 버튼 논리 ID | 음성 규칙 | BLE 연결 |
|--------|-------------|-----------|---------|
| `MicrowaveCommandService` | BT-01~09 | ✅ 구현 | ✅ 연결 |
| `WashingMachineCommandService` | BT-W01~09 | ✅ 구현 | ❌ 미연결 (하드웨어 후) |
| `AcCommandService` | BT-A01~09 | ✅ 구현 | ❌ 미연결 (하드웨어 후) |

`ApplianceCommandRouter`가 `deviceType` 또는 `deviceName`을 보고 자동 라우팅.
