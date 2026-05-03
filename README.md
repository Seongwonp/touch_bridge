# Touch Bridge

"Touch Bridge"는 저시력자 및 시각 장애인을 위해 스마트 기기를 음성으로 제어하고, 물리적 버튼을 대신 눌러주는 하드웨어 기기와 연동되는 Flutter 기반의 모바일 애플리케이션입니다. 이 앱은 Google Speech-to-Text (STT)와 Google AI Pro (Gemini API)를 활용하여 사용자의 음성 명령을 정확하게 인식하고 해석하며, 높은 접근성을 제공하도록 설계되었습니다.

## 주요 기능

*   **음성 명령 제어:** Google STT를 통해 사용자의 음성을 텍스트로 변환하고, Google AI Pro (Gemini)를 통해 명령의 의도를 파악하여 스마트 기기를 제어합니다.
*   **시각 장애인 접근성 최적화:**
    *   **TTS (Text-to-Speech):** 모든 주요 상호작용, 상태 변경, 오류 발생 시 명확하고 상세한 음성 피드백을 제공합니다.
    *   **Semantics (시맨틱 라벨):** 스크린 리더(TalkBack, VoiceOver) 사용자를 위해 모든 UI 요소에 의미 있는 설명을 추가했습니다.
    *   **높은 대비 디자인:** 어두운 테마와 밝은 강조 색상(노란색)을 사용하여 시인성을 극대화했습니다.
    *   **햅틱 피드백:** 중요한 상호작용에 햅틱 피드백을 제공하여 비시각적 피드백을 강화합니다.
*   **스마트 기기 관리:** 등록된 스마트 기기 목록을 확인하고, 각 기기의 상태를 모니터링합니다.
*   **수동 제어:** 키패드 인터페이스를 통해 기기를 수동으로 조작할 수 있습니다.
*   **비상 정지 시스템:** 음성 명령 또는 길게 누르기 제스처를 통해 작동 중인 기기를 즉시 안전하게 중단시킬 수 있습니다.
*   **기기 연결:** QR 코드 스캔 등 다양한 방법을 통해 새로운 스마트 기기를 앱에 연결합니다.
*   **사진 매핑:** 기기의 물리적 버튼 위치를 사진 기반의 3x3 그리드 인터페이스를 통해 매핑합니다.
*   **설정:** 음성 안내 속도 및 음량 조절, 가디언 모드(보호자 알림) 설정, 비상 연락처 관리 등 앱의 동작을 사용자 맞춤형으로 설정합니다.

## 기술 스택

*   **프레임워크:** Flutter
*   **언어:** Dart
*   **음성 인식 (STT):** `speech_to_text` 패키지 (Google Speech-to-Text 기반)
*   **자연어 이해 (NLU):** `google_generative_ai` 패키지 (Google AI Pro / Gemini API)
*   **텍스트 음성 변환 (TTS):** `flutter_tts` 패키지
*   **환경 변수 관리:** `flutter_dotenv`
*   **오디오 녹음 (레거시):** `record` 패키지 (현재는 `speech_to_text`로 대체됨)
*   **HTTP 통신:** `http` 패키지

## 프로젝트 설정 및 실행

### 1. 환경 변수 설정

Google AI Pro (Gemini) API 키를 `.env` 파일에 설정해야 합니다. 프로젝트 루트 디렉토리에 `.env` 파일을 생성하고 다음 내용을 추가합니다.

```dotenv
GOOGLE_AI_PRO_API_KEY=YOUR_GOOGLE_AI_PRO_API_KEY
```

`YOUR_GOOGLE_AI_PRO_API_KEY`를 Google Cloud Console에서 발급받은 실제 API 키로 대체하세요.

### 2. 플랫폼별 권한 설정

#### Android

`android/app/src/main/AndroidManifest.xml` 파일을 열고, `<manifest>` 태그 바로 아래에 다음 권한이 포함되어 있는지 확인합니다.

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

#### iOS

`ios/Runner/Info.plist` 파일을 열고, `<dict>` 태그 안에 다음 키-값 쌍이 포함되어 있는지 확인합니다.

```xml
<key>NSMicrophoneUsageDescription</key>
<string>음성 명령을 듣기 위해 마이크 접근이 필요합니다.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>음성 명령을 텍스트로 인식하기 위해 권한이 필요합니다.</string>
```

### 3. 종속성 설치

프로젝트 루트 디렉토리에서 다음 명령어를 실행하여 필요한 모든 Flutter 패키지를 설치합니다.

```bash
flutter pub get
```

### 4. 앱 실행

다음 명령어를 사용하여 앱을 실행합니다.

```bash
flutter run
```

## 접근성 가이드라인 (시각 장애인 사용자용)

이 애플리케이션은 시각 장애인 사용자를 위해 특별히 설계되었습니다. 다음 기능을 활용하여 앱을 더욱 효과적으로 사용할 수 있습니다.

*   **스크린 리더 사용:** Android의 TalkBack 또는 iOS의 VoiceOver를 활성화하여 앱의 모든 요소에 대한 음성 설명을 들을 수 있습니다.
*   **음성 피드백:** 앱은 중요한 동작, 상태 변경 및 오류에 대해 음성으로 안내합니다.
*   **두 번 탭 상호작용:** 일부 내비게이션 및 제어 요소는 의도치 않은 활성화를 방지하기 위해 두 번 탭하여 활성화해야 합니다. 첫 번째 탭 시 음성 안내가 제공됩니다.
*   **높은 대비:** 앱의 어두운 테마와 밝은 노란색 강조 색상은 시인성을 높여줍니다.

## 개발 가이드

### 코드 구조

프로젝트는 다음과 같은 논리적 구조를 따릅니다.

*   `lib/main.dart`: 앱의 진입점 및 초기 설정.
*   `lib/screens/`: 각 화면별 UI 및 로직.
    *   `home/`: 메인 기기 목록 및 제어 모드 선택.
    *   `connection/`: 기기 연결 방법 (QR 스캔 등).
    *   `control/`: 수동 기기 제어 (키패드, 타이머).
    *   `safety/`: 비상 정지 및 완료 화면.
    *   `voice/`: 음성 명령 처리 (STT, Gemini 연동).
    *   `mapping/`: 사진 기반 버튼 매핑.
    *   `settings/`: 앱 설정.
*   `lib/services/`: TTS, 타이머 등 앱 전반에 사용되는 서비스 로직.
*   `lib/theme/`: 앱의 디자인 테마 (색상, 텍스트 스타일).
*   `lib/widgets/`: 재사용 가능한 UI 위젯.

### Google AI Pro (Gemini) 프롬프트

`VoiceListeningScreen`에서 Gemini API를 호출할 때 사용되는 프롬프트는 사용자의 음성 명령을 JSON 형식으로 구조화된 명령으로 변환하도록 지시합니다. 새로운 명령이나 기기 제어 로직을 추가하려면 이 프롬프트를 업데이트해야 합니다.

```
You are an AI assistant that controls smart home devices.
Analyze the user's voice command and respond in a JSON format.
The "action" field must be one of: EMERGENCY_STOP, NAVIGATE, MICROWAVE_CONTROL, NONE.
If the "action" is "NAVIGATE", include a "target" field with a value of: connection, mapping, settings.
If the "action" is "MICROWAVE_CONTROL", include a "commands" field as an array, with values like: "start", "stop", "set_time_30s", "set_time_1m", "set_time_2m".
If you cannot understand the command, set "action" to "NONE" and include a "message" field with an appropriate response for the user.
Your response must be a JSON object. Do not include any other explanations or text outside the JSON.

User's command: "$text"
```

### 기여

이 프로젝트에 기여하고 싶다면, 언제든지 이슈를 제기하거나 Pull Request를 생성해주세요.

## 라이선스

[프로젝트 라이선스 정보]

---

**개발자 참고 사항:**

*   **테스트:** 실제 기기에서 TalkBack/VoiceOver를 활성화하여 모든 접근성 기능이 올바르게 작동하는지 철저히 테스트하는 것이 중요합니다.
*   **Gemini API 응답:** Gemini API의 응답 형식은 프롬프트에 따라 달라질 수 있으므로, `_sendTextToGemini` 및 `_handleCommand` 함수 내의 JSON 파싱 로직이 실제 Gemini 응답과 일치하는지 확인해야 합니다.
*   **하드웨어 연동:** 현재는 디자인 및 음성 인식까지만 구현되었으며, 하드웨어 기기와의 실제 연동 API는 추후 개발될 예정입니다.
*   **`TtsService`:** `TtsService`는 `flutter_tts`를 래핑한 서비스로, 앱 전반에 걸쳐 일관된 TTS 기능을 제공합니다.
*   **`ResponsiveScale`:** `ResponsiveScale` 위젯은 다양한 화면 크기에 대응하기 위한 유틸리티입니다.
