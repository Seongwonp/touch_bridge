# Touch Bridge

**시각장애인을 위한 가전 터치패드 자동 입력 시스템**

> 2026 한이음 드림업 공모전 — 3팀 멜론머스크 (차아미 · 박성원 · 서예솔)  

---

## 프로젝트 개요

전자레인지·세탁기·키오스크 등 터치패널 기반 가전이 시각장애인에게 접근하기 어렵다는 문제를 해결합니다.  
가전 터치패드 위에 부착하는 **IoT 하드웨어 장치**가 스마트폰 앱·음성 명령을 받아 **물리적으로 버튼을 대신 눌러주는** 시스템입니다.

---

## 주요 기능

### 음성 명령 (STT + Gemini AI)
- `speech_to_text`로 음성 수집 → Gemini 2.5 Flash로 의도 파싱
- 지원 명령: 기기 작동(초 단위), 비상 정지, 화면 이동
- 5초 침묵 감지 자동 타임아웃 + 재시도 안내

### TTS 음성 안내
- 모든 화면 진입·버튼 탭·완료 시 한국어 음성 피드백
- 속도·음량 설정 저장 (SharedPreferences)

### 비상 정지
- 버튼 3초 홀드 또는 음성 "멈춰"/"정지"/"그만"
- 카운트다운 중 5초 이하 → 매초 음성 안내
- 완료 시 기기명 포함 TTS

### 이중 탭 확인 패턴
- 중요한 액션은 탭 → 안내 → 4초 내 재탭으로 실행 (오작동 방지)

### Gemini Vision 버튼 자동 매핑
- 가전기기 사진 촬영 → Gemini Vision API로 버튼 위치 인식
- 3×3 그리드 자동 채움 → 수동 편집 가능

### 설정 영속화
- TTS 속도·음량, 접근성 옵션, 비상 연락처 → 앱 재시작 후에도 유지

---

## 기술 스택

| 분류 | 패키지 | 버전 |
|------|--------|------|
| 프레임워크 | Flutter / Dart | 3.x / 3.x |
| 음성 인식 | `speech_to_text` | ^7.3.0 |
| TTS | `flutter_tts` | ^4.2.5 |
| AI (NLU + Vision) | `google_generative_ai` | ^0.2.3 |
| 사진 선택 | `image_picker` | ^1.1.2 |
| 설정 저장 | `shared_preferences` | ^2.3.2 |
| 환경 변수 | `flutter_dotenv` | ^5.2.1 |

---

## 플랫폼 지원

| 기능 | Android | iOS | macOS 앱 | Chrome (웹) |
|------|:-------:|:---:|:--------:|:-----------:|
| TTS 음성 안내 | ✅ | ✅ | ❌ * | ✅ |
| STT 음성 명령 | ✅ | ✅ | ❌ * | ✅ |
| Gemini AI | ✅ | ✅ | ✅ | ✅ |
| 사진 매핑 | ✅ | ✅ | ✅ (갤러리) | ✅ |
| 설정 영속화 | ✅ | ✅ | ✅ | ✅ |

> \* macOS 26 (Tahoe) beta OS 버그로 TTS/STT 비활성화. 정식 출시 후 재확인 예정.

---

## 환경 설정

프로젝트 루트에 `.env` 파일 생성 (git 제외):

```env
GOOGLE_AI_PRO_API_KEY=여기에_실제_키_입력
GEMINI_MODEL=gemini-2.5-flash
```

- API 키는 [Google AI Studio](https://aistudio.google.com/)에서 발급
- Vision 기능(사진 매핑)도 동일 키 사용 (별도 키 불필요)
- 고품질 분석이 필요하면 `GEMINI_MODEL=gemini-2.5-pro`

---

## 실행 방법

```bash
# 의존성 설치
flutter pub get

# Chrome에서 실행 (개발·테스트 권장)
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios
```

> Chrome 첫 실행 시 마이크 권한 팝업이 뜹니다. 허용해야 음성 명령이 동작합니다.  
> TTS는 첫 사용자 탭 이후부터 작동합니다 (Chrome 자동재생 정책).

---

## 플랫폼별 권한 설정

### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>음성 명령을 듣기 위해 마이크 접근이 필요합니다.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>음성 명령을 텍스트로 인식하기 위해 권한이 필요합니다.</string>
<key>NSCameraUsageDescription</key>
<string>가전기기 버튼을 AI로 인식하기 위해 카메라 접근이 필요합니다.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>기기 사진을 선택하여 버튼을 매핑하기 위해 사진 라이브러리 접근이 필요합니다.</string>
```

### macOS (`macos/Runner/Info.plist` + entitlements)
- Info.plist: NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription, NSCameraUsageDescription, NSPhotoLibraryUsageDescription
- Entitlements: audio-input, speech-recognition, photos-library, camera, network.client

---

## 프로젝트 구조

```
lib/
├── main.dart                              # 앱 진입점, dotenv·설정 로드
├── screens/
│   ├── main_navigation_screen.dart        # 4탭 하단 내비게이션
│   ├── home/home_screen.dart              # 기기 카드 스와이프 (PageView)
│   ├── control/remote_control_screen.dart # 타이머 제어 키패드
│   ├── voice/voice_listening_screen.dart  # STT + Gemini AI 음성 명령
│   ├── safety/
│   │   ├── emergency_stop_screen.dart     # 비상 정지 (3초 홀드 / 음성)
│   │   └── stop_done_screen.dart          # 정지 완료 확인
│   ├── settings/settings_screen.dart      # 접근성·연락처 설정
│   ├── connection/
│   │   ├── device_connect_screen.dart     # 기기 연결 (QR/BLE/NFC)
│   │   └── qr_scan_screen.dart            # QR 스캔
│   └── mapping/photo_mapping_screen.dart  # Gemini Vision 버튼 매핑
├── services/
│   ├── tts_service.dart                   # TTS Singleton
│   ├── accessibility_settings.dart        # 설정 Singleton + SharedPreferences
│   └── timer_service.dart                 # 카운트다운 타이머
├── theme/                                 # 고대비 다크 테마
└── widgets/                               # 재사용 위젯
```

---

## Gemini AI 명령 형식

```json
{
  "action": "MICROWAVE_CONTROL | EMERGENCY_STOP | NAVIGATE | NONE",
  "device": "전자레인지",
  "seconds": 30,
  "commands": ["start"],
  "target": "connection | mapping | settings",
  "message": "알겠어요. 전자레인지 30초 돌릴게요."
}
```

---

## 하드웨어 연동 (예정)

```
ESP32 BLE GATT Server
Service UUID : 0000FFE0-0000-1000-8000-00805F9B34FB
Characteristic: 0000FFE1-...

명령 포맷:
{ "action": "press", "x": 0, "y": 1, "deviceId": "microwave_1" }
```

---

## 개발 현황

- [x] 4탭 내비게이션 + 이중 탭 확인 패턴
- [x] TTS Singleton (설정 영속화)
- [x] STT + Gemini AI 음성 명령 (침묵 감지 포함)
- [x] 비상 정지 (홀드 / 음성 / 카운트다운)
- [x] Gemini Vision 버튼 자동 매핑
- [x] SharedPreferences 설정 저장
- [x] 웹(Chrome) 지원
- [x] Android·iOS·macOS 권한 설정
- [ ] BLE 실제 연동 (하드웨어 완성 후)
- [ ] QR 스캔 (`mobile_scanner` 패키지 필요)
- [ ] 버튼 매핑 데이터 영속화
- [ ] 기기 목록 동적 관리

---

## 작업 로그

자세한 변경 이력은 [`docs/WORK_LOG.md`](docs/WORK_LOG.md)를 참고하세요.
