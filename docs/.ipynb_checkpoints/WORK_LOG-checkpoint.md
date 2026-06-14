# Touch Bridge 작업 로그

> 담당: 박성원 | AI 협업: Claude Sonnet 4.6  
> 프로젝트: 2026 한이음 드림업 — 시각장애인용 가전 터치패드 자동 입력 시스템  
> 팀: 3팀 멜론머스크 (차아미 · 박성원 · 서예솔)  
> 기간: 2026.03 ~ 2026.10

---

## 2026-03 초중순 — 아이디어 구상 및 팀 결성

- 시각장애인의 터치패드 가전 접근성 문제 발굴
- 팀 멜론머스크 결성 (차아미 · 박성원 · 서예솔)
- 핵심 컨셉 확정: 가전 위에 **부착하는 IoT 장치**가 물리적으로 버튼을 대신 눌러주는 방식
- 하드웨어 3단계 로드맵 초안 작성
  - 1단계: 초슬림 키캡 (정전용량 센싱)
  - 2단계: SG90 랙&피니언 X/Y 레일
  - 3단계: CoreXY + 솔레노이드 정밀 제어
- 핵심 부품 선정: ESP32 (BLE 5.0), SG90/NEMA14 모터

---

## 2026-03 중후반 — 계획서 작성 및 제출

- 한이음 드림업 공모전 계획서 작성
  - 문제 정의, 해결 방안, 기대 효과 정리
  - 시스템 구성도 설계 (앱 ↔ BLE ↔ ESP32 ↔ 물리 장치)
  - 개발 일정 및 역할 분담 확정
    - 차아미: PM / 하드웨어 설계
    - 박성원: 앱 개발 (Flutter)
    - 서예솔: 하드웨어 제작 보조
- 계획서 제출 완료

---

## 2026-04 초중반 — 개발 환경 세팅 및 앱 기초 구조

- 계획서 선정 통보
- Flutter 프로젝트 초기화 (`touch_bridge`)
- 개발 환경 구성
  - Flutter 3.x / Dart 3.x
  - `flutter_tts`, `speech_to_text`, `google_generative_ai`, `flutter_dotenv` 패키지 추가
  - `.env` 기반 Gemini API 키 관리 구조 설계
- 고대비 다크 테마 구성 (`app_colors.dart`, `app_theme.dart`)
- 4탭 하단 내비게이션 구현 (`MainNavigationScreen`)
  - 홈 / 기기 / 음성 / 설정
  - **이중 탭 확인 패턴** 적용 (1탭: 안내, 2탭: 실행, 4초 타임아웃)
- 공통 위젯 작성 (`PrimaryButton`, `TopAppBar`, `EmergencyButton`)

---

## 2026-04 중후반 — 핵심 기능 구현

### 접근성 기반 서비스 구축

- **TTS 서비스** (`tts_service.dart`) — Singleton, 한국어, 속도·음량 설정
- **비상 정지 화면** (`emergency_stop_screen.dart`)
  - 3초 홀드 → AnimationController 진행바 → `StopDoneScreen`
  - 음성 "멈춰"/"정지"/"그만"/"중단"/"stop" 감지
  - 카운트다운 5초 이하 → 매초 TTS 안내
- **홈 화면** (`home_screen.dart`) — 기기 카드 PageView 스와이프
- **기기 제어 화면** (`remote_control_screen.dart`) — 숫자 키패드 타이머

### 음성 명령 (STT + Gemini AI)

- **음성 인식 화면** (`voice_listening_screen.dart`)
  - `speech_to_text` 7.x로 STT 수집
  - Gemini 2.5 Flash로 의도 파싱
  - 지원 액션: `MICROWAVE_CONTROL`, `EMERGENCY_STOP`, `NAVIGATE`, `NONE`
  - 시간 파싱: "5초" → 5s / "1분" → 60s / "2분 30초" → 150s
- macOS TCC 권한 분기 처리 (1차)

### 설정 화면

- **설정 화면** (`settings_screen.dart`)
  - TTS 속도·음량 슬라이더
  - 음성 안내 ON/OFF, 큰 글씨, 고대비 토글
  - 비상 연락처 추가·편집·전화

### 기기 연결 화면

- **기기 연결 화면** (`device_connect_screen.dart`) — QR/BLE/NFC 진입점 UI
- **QR 스캔 화면** (`qr_scan_screen.dart`) — 애니메이션 프레임 (플레이스홀더)

---

## 2026-04 말 ~ 05 초 — 기능 고도화

### Gemini Vision 버튼 자동 매핑
- **파일**: `lib/screens/mapping/photo_mapping_screen.dart`
- 카메라 촬영 → Gemini Vision API → 3×3 그리드 자동 채움
- 각 셀 탭 → 라벨 수정/삭제 다이얼로그
- macOS: 카메라 미지원 → 갤러리 폴백

### SharedPreferences 설정 영속화
- **파일**: `lib/services/accessibility_settings.dart` 전면 재작성
- 저장 항목: 음성안내, 큰 글씨, 고대비, TTS 속도·음량, 비상연락처
- `main.dart`에서 앱 시작 전 `await AccessibilitySettings.instance.load()`

### 비상 연락처 편집
- 연락처 없을 때 추가 UI, 있을 때 편집·전화 버튼
- 다이얼로그: 이름 + 전화번호 → 저장 시 SharedPreferences 반영

### 플랫폼 권한 설정
- Android: RECORD_AUDIO, INTERNET, CAMERA, READ_MEDIA_IMAGES, BLE 권한
- iOS: 마이크, 음성인식, 카메라, 사진 라이브러리 권한
- macOS: Info.plist + Entitlements 전체 설정

---

## 2026-05-14 (세션 1) — 버그 수정 집중

### 버그 수정

#### TTS 첫 발화 무음 버그
- **파일**: `lib/services/tts_service.dart`
- **원인**: `_initTts()` Future 미저장 → `speak()` 첫 호출 시 초기화 전 실행
- **수정**: `late final Future<void> _init = _initTts()` 저장, `speak()`에서 `await _init`

#### speech_to_text v7 API 호환
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
- **원인**: v7에서 `listen()`이 `Future<void>` 반환 — `bool` 할당 오류
- **수정**: `await _speech.listen(...)` + `_speech.isListening`으로 상태 확인

#### dotenv 크래시 방지
- **파일**: `lib/main.dart`
- **수정**: `dotenv.load()` try-catch 처리 — `.env` 없어도 앱 실행

#### 설정 슬라이더 미연결
- **파일**: `lib/screens/settings/settings_screen.dart`
- **수정**: `onChanged`에서 `TtsService().setSpeechRate()`, `setVolume()` 호출

#### 외부 이미지 URL 제거
- **파일**: `lib/screens/mapping/photo_mapping_screen.dart`
- **수정**: 하드코딩 Google 이미지 URL → 로컬 플레이스홀더 컨테이너로 교체

---

## 2026-05-14 (세션 2) — macOS 대응 및 Chrome 지원

### 버그 수정

#### macOS 26 (Tahoe beta) TCC 크래시 — TTS / STT
- **파일**: `tts_service.dart`, `voice_listening_screen.dart`, `emergency_stop_screen.dart`
- **원인**: macOS 26 beta에서 `AVSpeechSynthesisVoice`, `SFSpeechRecognizer` 초기화 시 권한 다이얼로그 대신 `SIGABRT` abort 발생. OS 버그
- **수정**: `!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS` 가드로 TTS/STT 스킵
- **비고**: macOS 26 정식 출시 후 재확인 필요

#### macOS 엔타이틀먼트 — network.client 누락
- **파일**: `macos/Runner/DebugProfile.entitlements`, `Release.entitlements`
- **수정**: `com.apple.security.network.client` 추가 (Gemini API HTTPS 차단 해제)

#### flutter_tts getVoices API 오류
- **원인**: `_tts.getVoices()` — getter라 괄호 불가
- **수정**: `await _tts.getVoices;` (괄호 없이)

### 기능 추가

#### 웹(Chrome) 플랫폼 지원
- `kIsWeb` 체크로 macOS 가드를 네이티브 앱에만 적용, 웹은 TTS/STT 활성화
- Chrome TTS: 첫 사용자 상호작용 이후 정상 (자동재생 정책)
- Chrome 음성 로드: `await Future.delayed(500ms)` + `await _tts.getVoices;` 후 `setLanguage('ko-KR')`

#### 음성 화면 5초 침묵 감지
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
- 5초 침묵 + 말 없음 → 재시도 안내 TTS
- 5초 침묵 + 말 있었음 → 자동 Gemini 분석
- Chrome `onStatus: 'done'` 감지 → 즉시 분석 or 재시도

#### BLE 하드웨어 연동 TODO 스텁
- **파일**: `lib/services/ble_service.dart` (신규)
- ESP32 GATT UUID·명령 포맷 문서화, scan/connect/sendPress 스텁 메서드
- `device_connect_screen.dart`, `home_screen.dart`, `photo_mapping_screen.dart`에 연결 지점 TODO 마킹

---

## 2026-05-14 (세션 3) — 데이터 영속화 및 기능 완성

### 기능 추가

#### 버튼 매핑 영속화 (기기별)
- **파일**: `lib/screens/mapping/photo_mapping_screen.dart`
- `deviceId` / `deviceName` 파라미터 추가
- 저장 키 분리: `mapping_grid_<deviceId>` (기기별 독립)
- 화면 열 때 자동 복원 + TTS 안내, "매핑 완료" 탭 시 저장

#### 기기 목록 동적 관리
- **파일**: `lib/screens/home/home_screen.dart`
- 하드코딩 const 리스트 → `DeviceInfo` 클래스 + SharedPreferences 영속화
- 상단 "+" 버튼: 이름 입력 + 아이콘 8종 선택 → 추가
- 롱프레스 → 수정 / 버튼 매핑 / 삭제 옵션 Bottom Sheet
- 빈 상태 UI: 기기 없을 때 "기기 추가" 버튼 표시

#### RemoteControlScreen 기기명 연결
- **파일**: `lib/screens/control/remote_control_screen.dart`
- `deviceName` 파라미터 추가 (기본값: '스마트 기기')
- 하드코딩 "스마트 전자레인지" → `${widget.deviceName}` 동적 표시

#### QR 스캔 실제 구현
- **패키지**: `mobile_scanner: ^6.0.0`
- **파일**: `lib/screens/connection/qr_scan_screen.dart` 전면 재작성
- 실제 카메라 라이브 스캔, 인식 시 확인 다이얼로그, 플래시 토글
- QR 포맷: `{"deviceId":"esp32_001","name":"전자레인지"}` 또는 plain text

---

## 플랫폼별 지원 현황

| 기능 | Android | iOS | macOS 앱 | Chrome (웹) |
|------|:-------:|:---:|:--------:|:-----------:|
| TTS 음성 안내 | ✅ | ✅ | ❌ OS 버그 | ✅ |
| STT 음성 명령 | ✅ | ✅ | ❌ OS 버그 | ✅ |
| Gemini AI | ✅ | ✅ | ✅ | ✅ |
| 사진 매핑 | ✅ | ✅ | ✅ 갤러리 | ✅ |
| QR 스캔 | ✅ | ✅ | ❌ | ❌ |
| 설정 영속화 | ✅ | ✅ | ✅ | ✅ |
| 기기 목록 저장 | ✅ | ✅ | ✅ | ✅ |
| 버튼 매핑 저장 | ✅ | ✅ | ✅ | ✅ |

---

## 환경 설정

```
# .env 파일 (프로젝트 루트, git 제외)
GOOGLE_AI_PRO_API_KEY=실제_키_입력
GEMINI_MODEL=gemini-3-flash-preview
```

---

## 남은 작업

| 항목 | 상태 | 비고 |
|------|------|------|
| BLE 실제 연동 | ⏳ 대기 | 하드웨어 완성 후 `flutter_blue_plus` 연결 |
| QR → 기기 자동 추가 | 🔧 부분 구현 | 현재 스낵바 안내만, 홈 목록 자동 추가 미연결 |
| macOS TTS/STT | ⏳ 대기 | macOS 26 정식 출시 후 TCC 재확인 |
| 기기 상태 실시간 모니터링 | ⏳ 대기 | 전류/온도 센서 데이터 (하드웨어 연동 후) |
| 가디언 알림 | ⏳ 미정 | Firebase 연동 (공모전 후반) |
