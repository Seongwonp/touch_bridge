# Touch Bridge — AI Context Document

## 프로젝트 개요

**터치 브릿지 (Touch Bridge)** — 시각장애인을 위한 가전 터치패드 자동 입력 시스템

- **팀:** 3팀 멜론머스크 (차아미 · 박성원 · 서예솔)
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
│   ├── main_navigation_screen.dart        # 4-탭 하단 내비게이션 (이중 탭 확인 패턴)
│   ├── home/home_screen.dart              # 기기 카드 스와이프 (PageView) + 동적 기기 관리
│   ├── control/remote_control_screen.dart # 타이머 제어 키패드 (deviceName 파라미터)
│   ├── voice/voice_listening_screen.dart  # STT + Gemini AI 음성 명령 (5초 침묵 감지)
│   ├── safety/
│   │   ├── emergency_stop_screen.dart     # 비상 정지 (3초 홀드 OR "멈춰" 음성)
│   │   └── stop_done_screen.dart          # 정지 완료 확인 화면
│   ├── settings/settings_screen.dart      # TTS 속도/음량, 접근성, 가디언 모드
│   ├── connection/
│   │   ├── device_connect_screen.dart     # 기기 연결 (QR/BLE/NFC)
│   │   └── qr_scan_screen.dart            # QR 코드 실시간 스캔 (mobile_scanner)
│   └── mapping/photo_mapping_screen.dart  # 3x3 그리드 버튼 매핑 (기기별 저장)
├── services/
│   ├── tts_service.dart                   # Singleton TTS (flutter_tts 래퍼)
│   ├── ble_service.dart                   # BLE 스텁 — 하드웨어 연동 대기
│   ├── accessibility_settings.dart        # Singleton ChangeNotifier (설정 영속화)
│   └── timer_service.dart                 # 카운트다운 타이머
├── theme/
│   ├── app_colors.dart                    # 고대비 컬러 시스템
│   ├── app_text.dart                      # 큰 글씨 타이포그래피
│   └── app_theme.dart                     # ThemeData
└── widgets/
    ├── bottom_nav_bar.dart                # 재사용 하단 내비게이션
    ├── emergency_button.dart              # 비상 정지 버튼 위젯
    ├── info_card.dart                     # 정보 카드
    ├── primary_button.dart                # 이중 탭 확인 버튼
    ├── responsive_scale.dart              # 반응형 스케일 (기준: Galaxy S20)
    └── top_app_bar.dart                   # 공통 상단 앱바
```

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
- `DeviceInfo` 클래스: name, status, iconCodePoint → JSON 직렬화
- SharedPreferences 키: `home_devices`
- 상단 "+" 버튼: 이름 + 아이콘 8종 선택 → 추가
- 카드 롱프레스: 수정 / 버튼 매핑 / 삭제 Bottom Sheet
- 기본 기기 3개는 저장된 데이터 없을 때만 표시

### 버튼 매핑 (PhotoMappingScreen)
- `deviceId` / `deviceName` 파라미터로 기기별 독립 저장
- SharedPreferences 키: `mapping_grid_<deviceId>`, `mapping_device_type_<deviceId>`
- 전역(기기 미지정) 키: `mapping_grid_global`
- 홈 화면 롱프레스 → "버튼 매핑" 선택 시 기기명 전달하며 진입

## 음성 명령 (Gemini AI)

`VoiceListeningScreen`에서 STT로 음성을 받아 Gemini API로 파싱:
```json
{
  "action": "EMERGENCY_STOP | NAVIGATE | MICROWAVE_CONTROL | NONE",
  "target": "connection | mapping | settings",
  "seconds": 30,
  "device": "전자레인지",
  "commands": ["start"],
  "message": "사용자에게 전달할 메시지"
}
```
- 5초 침묵 감지: 말 없음 → 재시도 안내 / 말 있었음 → 자동 분석
- Chrome `onStatus: 'done'` 처리 포함

## 환경 설정 (.env)

```
GOOGLE_AI_PRO_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-2.5-flash
```
`.env`는 git에 올리지 말 것 (`.gitignore` 등록됨).

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

### 색상 (고대비 다크 테마)
| 용도 | 색상 | Hex |
|------|------|-----|
| 배경 | 순수 검정 | #000000 |
| 서피스 | 어두운 회색 | #121212 |
| 주요 색상 | 노랑 (고가시성) | #FFEB00 |
| 텍스트 | 흰색 | #FFFFFF |
| 보조 텍스트 | 밝은 회색 | #D1D5DB |
| 비상/위험 | 빨강 | #FF3B30 |
| 성공 | 초록 | #22C55E |
| 경고 | 주황 | #FFB020 |

### UX 원칙
- **Look-free**: 화면 안 봐도 음성+진동으로 파악 가능
- **Error-safe**: 이중 확인 + 즉시 취소 가능 (4초 타임아웃)
- **Multimodal**: 음성 안내(TTS) + 햅틱 진동 + 고대비 큰 글씨

### 접근성 설정 (AccessibilitySettings)
- `voiceGuidanceEnabled`: TTS 켜기/끄기 (기본 true)
- `largeTextEnabled`: 텍스트 1.18배 확대 (기본 false)
- `highContrastEnabled`: boldText 강화 (기본 false)

## 하드웨어 BLE 프로토콜 (연동 대기)

```
ESP32 GATT Server
Service UUID    : 0000FFE0-0000-1000-8000-00805F9B34FB
Characteristic  : 0000FFE1-0000-1000-8000-00805F9B34FB

명령 포맷 (JSON string):
{ "action": "press", "x": 0, "y": 1, "deviceId": "microwave_1" }
```

BLE 연동 준비 파일: `lib/services/ble_service.dart`
- 모든 메서드가 스텁으로 구현됨 (scan, connect, disconnect, sendPress, sendEmergencyStop)
- `flutter_blue_plus` 패키지 추가 후 스텁 채우면 됨
- 연결 지점: `device_connect_screen.dart`, `home_screen.dart`, `photo_mapping_screen.dart`의 `// TODO(hardware):` 주석 참고

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
- [x] 사진 매핑 화면 (Gemini Vision + 3x3 그리드)
- [x] Semantics 접근성 태그 전체 적용
- [x] SharedPreferences 설정·기기목록·버튼매핑 영속화
- [x] 기기 목록 동적 관리 (추가/수정/삭제)
- [x] 기기별 버튼 매핑 독립 저장
- [x] RemoteControlScreen 기기명 파라미터화
- [x] Chrome 웹 지원 (TTS/STT 모두 동작)
- [x] macOS TCC 버그 workaround

### 대기 중 ⏳
- [ ] BLE 실제 연동 — `ble_service.dart` 스텁 채우기 (`flutter_blue_plus` 추가 후)
- [ ] 기기 상태 실시간 모니터링 — 전류/온도 센서 데이터 (하드웨어 연동 후)
- [ ] macOS TTS/STT — macOS 26 정식 출시 후 TCC 재확인
- [ ] 가디언 알림 — Firebase 연동 (공모전 후반)
