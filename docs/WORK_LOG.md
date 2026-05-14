# Touch Bridge 작업 로그

> 담당: 박성원 | AI 협업: Claude Sonnet 4.6  
> 프로젝트: 2026 한이음 드림업 — 시각장애인용 가전 터치패드 자동 입력 시스템  
> 브랜치: `Touch_bridge_b`

---

## 2026-05-14

### 버그 수정

#### TTS 첫 발화 무음 버그
- **파일**: `lib/services/tts_service.dart`
- **원인**: `_initTts()`가 async인데 Future를 저장하지 않아, `speak()` 첫 호출 시 초기화가 완료되기 전에 실행됨
- **수정**: `late final Future<void> _init = _initTts()` 저장, `speak()`에서 `await _init` 대기

#### macOS STT 크래시
- **파일**: `lib/screens/safety/emergency_stop_screen.dart`
- **원인**: `VoiceListeningScreen`에는 macOS 플랫폼 체크가 있었으나 `EmergencyStopScreen`에는 누락됨
- **수정**: `_initSpeech()` 시작 시 `defaultTargetPlatform == TargetPlatform.macOS` 체크 추가
- **누락 import**: `package:flutter/foundation.dart` 추가 (defaultTargetPlatform, kDebugMode)

#### speech_to_text v7 API 호환
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
- **원인**: `bool available = await _speech.listen(...)` — v7에서 `listen()`은 `Future<void>` 반환
- **수정**: `await _speech.listen(...)` + `_speech.isListening`으로 상태 확인

#### dotenv 크래시 방지
- **파일**: `lib/main.dart`
- **수정**: `dotenv.load()` try-catch 처리 — `.env` 없어도 앱 실행 (API 기능만 제한)

#### .env 파일 누락
- **원인**: `.env`가 Flutter asset으로 선언됐는데 파일이 없어 빌드 실패
- **수정**: `.env` 플레이스홀더 파일 생성 (API 키는 직접 입력 필요)

#### 설정 슬라이더 미연결
- **파일**: `lib/screens/settings/settings_screen.dart`
- **원인**: `_speed`, `_volume` 상태만 바꾸고 TtsService에 반영 안 됨
- **수정**: `onChanged`에서 `TtsService().setSpeechRate(v)`, `TtsService().setVolume(v)` 호출

#### TTS 기본 속도 불일치
- **파일**: `lib/services/tts_service.dart`
- **원인**: 초기화 시 rate=0.45, 설정 UI 기본값 1.0x = rate 0.5로 불일치
- **수정**: 초기화 rate 0.5로 변경

#### 외부 이미지 URL 제거
- **파일**: `lib/screens/mapping/photo_mapping_screen.dart`
- **원인**: 하드코딩된 Google 이미지 URL → 오프라인/빌드 오류
- **수정**: 로컬 플레이스홀더 컨테이너로 교체

#### 기타
- `stop_done_screen.dart`: 하단 탭 라벨 영문 → 한국어 변경
- `AndroidManifest.xml`: BLE 권한 추가 (하드웨어 연동 준비)

---

### 기능 추가

#### shared_preferences 설정 영속화
- **패키지**: `shared_preferences: ^2.3.2`
- **파일**: `lib/services/accessibility_settings.dart` (전면 재작성)
- **저장 항목**: 음성안내 ON/OFF, 큰 글씨, 고대비, TTS 속도, TTS 음량, 비상연락처
- **적용 시점**: `main.dart`에서 `AccessibilitySettings.instance.load()` await 후 앱 실행
- **TTS 자동 적용**: `TtsService._initTts()`가 저장된 속도·음량 읽어서 초기화

#### 비상 연락처 편집
- **파일**: `lib/screens/settings/settings_screen.dart`
- **기능**: 연락처 없을 때 추가 UI, 있을 때 편집·전화 버튼 표시
- **다이얼로그**: 이름 + 전화번호 TextField → 저장 시 SharedPreferences 반영

#### Gemini Vision 버튼 자동 매핑
- **패키지**: `image_picker: ^1.1.2` (기존 `google_generative_ai` 활용)
- **파일**: `lib/screens/mapping/photo_mapping_screen.dart` (StatefulWidget 전환)
- **흐름**: 카메라 촬영 → Gemini Vision API 전송 → 3×3 그리드 자동 채움 → TTS 결과 안내
- **편집**: 각 셀 탭 → 다이얼로그에서 버튼 이름 수정/삭제 가능
- **macOS**: 카메라 미지원 → 갤러리 폴백
- **API 키**: 기존 `GOOGLE_AI_PRO_API_KEY` 동일 키 사용 (Vision 별도 키 불필요)
- **모델 변경**: `.env`에서 `GEMINI_MODEL=gemini-2.5-pro` 로 변경 시 고품질 분석

#### 음성 명령 개선 (Gemini 프롬프트)
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
- **변경**: 한국어 최적화 프롬프트, `seconds` + `device` 필드 추가
- **시간 파싱**: "5초" → seconds:5 / "1분" → seconds:60 / "2분 30초" → seconds:150
- **MICROWAVE_CONTROL 흐름**:
  1. 음성 인식 → Gemini 파싱
  2. TTS: "알겠어요. 전자레인지 5초 동작을 시작합니다."
  3. TTS 완료 후 EmergencyStopScreen(initialSeconds: 5, deviceName: '전자레인지')으로 이동
  4. 카운트다운: 5초 이하 → 매초 "5, 4, 3, 2, 1"
  5. 완료: "전자레인지 작동이 끝났습니다."

#### EmergencyStopScreen 동적 기기명
- **파일**: `lib/screens/safety/emergency_stop_screen.dart`
- **추가**: `deviceName` 파라미터 (기본값: '기기')
- **변경**: 상태 카드 하드코딩 제거, 완료 TTS에 기기명 포함

---

### 반응형 레이아웃 수정

#### VoiceListeningScreen 오버플로우
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
- **원인**: 고정 SizedBox(40/60/100) 합계가 macOS 창 높이(408px) 초과
- **수정**:
  - 고정 간격 → `Spacer`로 교체 (비례 분배)
  - 파형 높이: `(screenH * 0.11).clamp(48, 100)`
  - 버튼 크기: `(screenH * 0.15).clamp(80, 130)`
  - 텍스트에 `maxLines` + `overflow` 처리

---

## 환경 설정

```
# .env 파일 (프로젝트 루트, git 제외)
GOOGLE_AI_PRO_API_KEY=실제_키_입력
GEMINI_MODEL=gemini-2.5-flash   # 또는 gemini-2.5-pro
```

---

---

## 2026-05-14 (세션 2)

### 버그 수정

#### macOS 엔타이틀먼트 — network.client 누락
- **파일**: `macos/Runner/DebugProfile.entitlements`, `Release.entitlements`
- **원인**: macOS 샌드박스에서 외부 HTTPS 요청(Gemini API) 차단
- **수정**: `com.apple.security.network.client` 엔타이틀먼트 추가

#### macOS 26 (Tahoe) TCC 크래시 — TTS / STT
- **파일**: `lib/services/tts_service.dart`, `lib/screens/voice/voice_listening_screen.dart`, `lib/screens/safety/emergency_stop_screen.dart`
- **원인**: macOS 26 beta에서 `AVSpeechSynthesisVoice`, `SFSpeechRecognizer` 초기화 시 TCC(프라이버시 프레임워크)가 다이얼로그 대신 `SIGABRT` abort 발생. Info.plist + 엔타이틀먼트 모두 정상인데도 발생하는 OS 버그
- **수정**: `!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS` 조건으로 TTS speak(), STT initialize() 스킵
- **비고**: Android/iOS/Chrome 웹은 정상 작동. macOS 26 정식 출시 시 재확인 필요

#### flutter_tts getVoices API 오류
- **파일**: `lib/services/tts_service.dart`
- **원인**: `_tts.getVoices()`로 호출했으나 getter라 `()` 없이 `_tts.getVoices`로 접근해야 함
- **수정**: `await _tts.getVoices;`로 수정

---

### 기능 추가

#### 웹(Chrome) 플랫폼 지원
- **배경**: macOS 26 TCC 버그로 네이티브 앱 실행 불가 → Chrome에서 개발·테스트
- **변경**: `kIsWeb` 체크로 macOS 가드를 네이티브 앱에만 적용, 웹에는 TTS/STT 모두 활성화
- **Chrome TTS**: 앱 로드 시 자동 발화는 Chrome 자동재생 정책으로 차단됨 — 첫 사용자 상호작용 이후 정상 작동
- **Chrome STT**: 브라우저 권한 다이얼로그로 처리 (macOS TCC 완전 우회)
- **웹 음성 로드**: Chrome에서 음성이 비동기 로드됨 → `await Future.delayed(500ms)` + `await _tts.getVoices;` 후 `setLanguage('ko-KR')`

#### 음성 화면 침묵 감지 (5초 타임아웃)
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
- **기능**:
  - 녹음 시작 시 5초 침묵 타이머(`_silenceTimer`) 시작
  - 부분 결과(`partialResults`) 수신마다 타이머 리셋
  - 5초 경과 + 말이 없으면: "아무 말씀도 인식되지 않았습니다. 버튼을 눌러 다시 시도해주세요."
  - 5초 경과 + 말이 있으면: 자동으로 Gemini 분석 시작
- **Chrome 자연 종료 처리**: `onStatus: 'done'` / `'notListening'` 감지 → `_onSttNaturalEnd()` 호출로 처리
- **동작 흐름**:

  | 상황 | 결과 |
  |------|------|
  | 5초간 침묵 (말 없음) | 재시도 안내 |
  | 말하는 중 → 5초 침묵 | 자동 Gemini 분석 |
  | Chrome이 STT 자동 종료 | 즉시 분석 or 재시도 |
  | 최대 8초 경과 | 강제 종료 후 분석 |

---

## 플랫폼별 지원 현황

| 기능 | Android | iOS | macOS 앱 | Chrome (웹) |
|------|---------|-----|----------|------------|
| TTS 음성 안내 | ✅ | ✅ | ❌ (OS 버그) | ✅ |
| STT 음성 명령 | ✅ | ✅ | ❌ (OS 버그) | ✅ |
| Gemini AI | ✅ | ✅ | ✅ | ✅ |
| 사진 매핑 | ✅ | ✅ | ✅ (갤러리만) | ✅ |
| 설정 영속화 | ✅ | ✅ | ✅ | ✅ |

---

## 남은 작업

- [ ] BLE 실제 연동 (하드웨어 완성 후)
- [ ] QR 스캔 구현 (`mobile_scanner` 패키지 필요)
- [ ] 버튼 매핑 데이터 영속화 (SharedPreferences or sqflite)
- [ ] 기기 목록 동적 관리 (하드코딩 3개 → 사용자 추가/삭제)
- [ ] macOS TTS/STT — macOS 26 정식 출시 후 TCC 동작 재확인
- [ ] 가디언 알림 (Firebase 또는 서버 연동, 추후)
