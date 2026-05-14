# Touch Bridge 작업 로그

> 담당: 박성원 | AI 협업: Claude Sonnet 4.6  
> 프로젝트: 2026 한이음 드림업 — 시각장애인용 가전 터치패드 자동 입력 시스템

---

## 2026-05-14 (세션 1)

### 버그 수정

#### TTS 첫 발화 무음 버그
- **파일**: `lib/services/tts_service.dart`
- **원인**: `_initTts()`가 async인데 Future를 저장하지 않아, `speak()` 첫 호출 시 초기화가 완료되기 전에 실행됨
- **수정**: `late final Future<void> _init = _initTts()` 저장, `speak()`에서 `await _init` 대기

#### macOS STT 크래시
- **파일**: `lib/screens/safety/emergency_stop_screen.dart`
- **원인**: `VoiceListeningScreen`에는 macOS 플랫폼 체크가 있었으나 `EmergencyStopScreen`에는 누락됨
- **수정**: `_initSpeech()` 시작 시 `defaultTargetPlatform == TargetPlatform.macOS` 체크 추가

#### speech_to_text v7 API 호환
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
- **원인**: `bool available = await _speech.listen(...)` — v7에서 `listen()`은 `Future<void>` 반환
- **수정**: `await _speech.listen(...)` + `_speech.isListening`으로 상태 확인

#### dotenv 크래시 방지
- **파일**: `lib/main.dart`
- **수정**: `dotenv.load()` try-catch 처리 — `.env` 없어도 앱 실행 (API 기능만 제한)

#### 설정 슬라이더 미연결
- **파일**: `lib/screens/settings/settings_screen.dart`
- **수정**: `onChanged`에서 `TtsService().setSpeechRate(v)`, `TtsService().setVolume(v)` 호출

#### TTS 기본 속도 불일치
- **파일**: `lib/services/tts_service.dart`
- **수정**: 초기화 rate 0.5로 변경

#### 외부 이미지 URL 제거
- **파일**: `lib/screens/mapping/photo_mapping_screen.dart`
- **수정**: 로컬 플레이스홀더 컨테이너로 교체

---

### 기능 추가

#### shared_preferences 설정 영속화
- **패키지**: `shared_preferences: ^2.3.2`
- **파일**: `lib/services/accessibility_settings.dart` (전면 재작성)
- **저장 항목**: 음성안내 ON/OFF, 큰 글씨, 고대비, TTS 속도, TTS 음량, 비상연락처

#### 비상 연락처 편집
- **파일**: `lib/screens/settings/settings_screen.dart`
- **기능**: 연락처 없을 때 추가 UI, 있을 때 편집·전화 버튼 표시

#### Gemini Vision 버튼 자동 매핑
- **패키지**: `image_picker: ^1.1.2`
- **파일**: `lib/screens/mapping/photo_mapping_screen.dart`
- **흐름**: 카메라 촬영 → Gemini Vision API → 3×3 그리드 자동 채움 → TTS 결과 안내
- **편집**: 각 셀 탭 → 다이얼로그에서 수정/삭제 가능

#### 음성 명령 개선 (Gemini 프롬프트)
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
- **시간 파싱**: "5초" → seconds:5 / "1분" → seconds:60 / "2분 30초" → seconds:150

#### EmergencyStopScreen 동적 기기명
- **파일**: `lib/screens/safety/emergency_stop_screen.dart`
- **추가**: `deviceName` 파라미터 (기본값: '기기'), 완료 TTS에 기기명 포함

---

## 2026-05-14 (세션 2)

### 버그 수정

#### macOS 엔타이틀먼트 — network.client 누락
- **파일**: `macos/Runner/DebugProfile.entitlements`, `Release.entitlements`
- **원인**: macOS 샌드박스에서 외부 HTTPS 요청(Gemini API) 차단
- **수정**: `com.apple.security.network.client` 엔타이틀먼트 추가

#### macOS 26 (Tahoe) TCC 크래시 — TTS / STT
- **파일**: `lib/services/tts_service.dart`, `lib/screens/voice/voice_listening_screen.dart`, `lib/screens/safety/emergency_stop_screen.dart`
- **원인**: macOS 26 beta에서 `AVSpeechSynthesisVoice`, `SFSpeechRecognizer` 초기화 시 TCC가 다이얼로그 대신 `SIGABRT` abort 발생. OS 버그
- **수정**: `!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS` 조건으로 TTS/STT 스킵
- **비고**: Android/iOS/Chrome 웹은 정상 작동. macOS 26 정식 출시 시 재확인 필요

#### flutter_tts getVoices API 오류
- **파일**: `lib/services/tts_service.dart`
- **원인**: `_tts.getVoices()`로 호출했으나 getter라 `()` 없이 접근해야 함
- **수정**: `await _tts.getVoices;` (괄호 없이)

---

### 기능 추가

#### 웹(Chrome) 플랫폼 지원
- **배경**: macOS 26 TCC 버그로 네이티브 앱 실행 불가 → Chrome에서 개발·테스트
- **변경**: `kIsWeb` 체크로 macOS 가드를 네이티브 앱에만 적용
- **Chrome TTS**: 앱 로드 시 자동 발화는 Chrome 자동재생 정책으로 차단 — 첫 사용자 상호작용 이후 정상
- **Chrome STT**: 브라우저 권한 다이얼로그로 처리

#### 음성 화면 침묵 감지 (5초 타임아웃)
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
- **기능**: 5초 침묵 시 재시도 안내 / 말이 있었으면 자동 Gemini 분석 시작
- **Chrome 자연 종료 처리**: `onStatus: 'done'` / `'notListening'` 감지 → 즉시 분석

#### BLE 하드웨어 연동 TODO 스텁
- **파일**: `lib/services/ble_service.dart` (신규 생성)
- **내용**: ESP32 GATT UUID 문서화, scan/connect/sendPress/sendEmergencyStop 스텁
- **연결 지점**: `device_connect_screen.dart`, `home_screen.dart`, `photo_mapping_screen.dart`에 TODO 마킹

---

## 2026-05-14 (세션 3)

### 기능 추가

#### 버튼 매핑 SharedPreferences 영속화
- **파일**: `lib/screens/mapping/photo_mapping_screen.dart`
- **내용**: `_saveMapping()` / `_loadMapping()` 추가
- **동작**: "매핑 완료" 탭 시 저장, 화면 열 때 자동 복원 + TTS 안내
- **저장 키**: `mapping_grid_<deviceId>`, `mapping_device_type_<deviceId>`

#### 기기 목록 동적 관리
- **파일**: `lib/screens/home/home_screen.dart`
- **내용**: 하드코딩 3개짜리 `const` 리스트 → `DeviceInfo` 클래스 + SharedPreferences 저장
- **DeviceInfo**: name, status, iconCodePoint → JSON 직렬화
- **기능**: 상단 "+" 버튼으로 추가 (이름 + 아이콘 8종 선택), 롱프레스로 삭제
- **빈 상태 UI**: 기기 없을 때 "기기 추가" 버튼 표시

#### 기기 이름 수정
- **파일**: `lib/screens/home/home_screen.dart`
- **내용**: 롱프레스 → 수정/버튼매핑/삭제 옵션 Bottom Sheet
- **수정 다이얼로그**: 텍스트 입력 후 저장 → SharedPreferences 즉시 반영

#### 기기별 버튼 매핑 분리
- **파일**: `lib/screens/mapping/photo_mapping_screen.dart`
- **내용**: `deviceId` / `deviceName` 파라미터 추가
- **저장 키 분리**: `mapping_grid_global` (기존) → `mapping_grid_<deviceId>` (기기별)
- **접근**: 홈 화면 롱프레스 옵션 "버튼 매핑"에서 기기명 전달하며 진입

#### RemoteControlScreen 기기명 연결
- **파일**: `lib/screens/control/remote_control_screen.dart`
- **내용**: `deviceName` 파라미터 추가 (기본값: '스마트 기기')
- **변경**: 하드코딩 "스마트 전자레인지 연결됨" → `${widget.deviceName} 연결됨`

#### QR 스캔 실제 구현
- **패키지**: `mobile_scanner: ^6.0.0` 추가
- **파일**: `lib/screens/connection/qr_scan_screen.dart` (전면 재작성)
- **기능**: 실제 카메라 라이브 스캔, QR 인식 시 확인 다이얼로그, 플래시 토글
- **QR 형식**: `{"deviceId":"esp32_001","name":"전자레인지","type":"microwave"}` 또는 plain text
- **플랫폼**: Android/iOS 동작. macOS/Chrome은 카메라 미지원으로 비활성

---

## 플랫폼별 지원 현황

| 기능 | Android | iOS | macOS 앱 | Chrome (웹) |
|------|:-------:|:---:|:--------:|:-----------:|
| TTS 음성 안내 | ✅ | ✅ | ❌ (OS 버그) | ✅ |
| STT 음성 명령 | ✅ | ✅ | ❌ (OS 버그) | ✅ |
| Gemini AI | ✅ | ✅ | ✅ | ✅ |
| 사진 매핑 | ✅ | ✅ | ✅ (갤러리) | ✅ |
| QR 스캔 | ✅ | ✅ | ❌ | ❌ |
| 설정 영속화 | ✅ | ✅ | ✅ | ✅ |
| 기기 목록 저장 | ✅ | ✅ | ✅ | ✅ |
| 버튼 매핑 저장 | ✅ | ✅ | ✅ | ✅ |

---

## 환경 설정

```
# .env 파일 (프로젝트 루트, git 제외)
GOOGLE_AI_PRO_API_KEY=실제_키_입력
GEMINI_MODEL=gemini-2.5-flash   # 또는 gemini-2.5-pro
```

---

## 남은 작업

| 항목 | 상태 | 비고 |
|------|------|------|
| BLE 실제 연동 | ⏳ 대기 | 하드웨어 완성 후 |
| QR → 기기 자동 추가 | ⏳ | 현재는 스낵바 안내만. 홈 기기 목록 직접 추가는 사용자가 수동 |
| macOS TTS/STT | ⏳ 대기 | macOS 26 정식 출시 후 TCC 재확인 |
| 가디언 알림 | ⏳ 미정 | Firebase 또는 서버 연동 (공모전 후반) |
