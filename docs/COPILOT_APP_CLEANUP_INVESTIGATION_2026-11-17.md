# Touch Bridge 앱 정리·운영 조사 보고서

- 조사 기준일: 2026-11-17
- 조사 브랜치: `feat/guardian-hub`
- 조사 범위: Flutter 앱의 기능 도달성, 제거 후보, 의존성·에셋, 무인 부스 운영 위험
- 조사 원칙: 코드 수정·삭제·커밋 없이 정적 분석과 참조 추적만 수행
- 검증 결과: `flutter analyze` → **No issues found**

> **2026-11-17 검토 정정(코드 대조):**
> - `SemanticsService.announce`는 `lib/services/tts_service.dart:225`에서 **사용 중**이다(TalkBack이 켜졌을 때 앱 음성을 낭독기 공지로 보냄, deprecated 경고는 `ignore`). 11/25 전에는 `sendAnnouncement`로 바꾸지 않는다.
> - `permission_handler`는 `lib/screens/connection/device_connect_screen.dart`에서 사용 중이라 **유지**한다.
> - 핵심 흐름은 **홈의 큰 '말하기' 버튼**에서 시작한다. 조작 메뉴는 보조 경로다.
> - 실행 중에는 마이크가 닫힌다. 실행 중 정지는 음성 "멈춰"가 아니라 **화면의 단일 탭 정지**다. 음성 정지는 음성 입력 단계에서만 처리된다.
> - 확정된 부스 조건: 음성과 실제 누름 중심, 사전 등록 매핑, 전자레인지 전용, CT 알림은 앱이 화면에 켜져 있을 때만.
> - 반영 결과: `path_provider`(전이 의존성으로는 남음)·`google_generative_ai`·`cupertino_icons` 직접 의존 삭제, 가전 추가 화면의 QR 버튼 제거, `--dart-define=TOUCH_BRIDGE_BOOTH=true`일 때 간편 코스·숫자 패드·연습 모드 숨김(`lib/services/booth_mode.dart`). release 빌드가 R8 누락 클래스(Tink 애너테이션)로 실패하던 문제를 `android/app/proguard-rules.pro`로 해결했고, release APK는 53.6MB다.

> 이 문서는 현재 코드 기준의 조사 보고서다. 실제 APK 크기, 장시간 실행, 실기기 BLE, Android 릴리스 동작은 별도 실험이 필요하며, 확인되지 않은 내용은 **확인 필요**로 표시했다.

## 1. 후보 요약표

| 후보 | 현재 도달 경로 | 실제 상태 | 권고 | 위험 | 작업량 | 순서 |
|---|---|---|---|---|---:|---:|
| QR 스캔 | 설정 → 보호자 설정 → 가전 추가 → QR | `mobile_scanner`가 제거되어 안내 화면만 표시되는 스텁 | **사용자 화면에서 숨김 또는 NFC 설명으로 대체** | 낮음. 실제 등록 경로로 오인할 수 있음 | S | 1 |
| NFC 등록 | 보호자 설정 → 가전 추가 → NFC | 실제 `nfc_manager` 세션·NDEF 읽기 구현 | **유지** | 낮음 | - | - |
| 기기 코드 입력/BLE 검색 | 보호자 설정 → 가전 추가 | BLE 검색·선택·기기 코드 입력 경로가 실제 동작 | **유지** | 보호자 등록 핵심 | - | - |
| 연습 모드 | 설정 → 연습 | STT, 비상 정지, 햅틱·TTS 연습 구현 | **부스에서는 숨김, 개발/교육용으로 보존** | 핵심 사용자 흐름과 별개지만 접근성 교육 가치 있음 | S | 2 |
| 이미지 제어 | 홈 기기 카드 → 조작 메뉴 | 저장된 매핑 이미지를 읽고 버튼 선택·실행 | **부스에서는 숨김 검토, 보호자·저시력 수동 경로는 확인 후 유지** | 이미지 매핑을 삭제하면 이 경로가 깨짐 | M | 4 |
| 간편 코스 | 홈 기기 카드 → 조작 메뉴 | 코스 정의·실행 코드가 존재 | **부스에서는 숨김** | 코스와 음성 핵심 흐름의 동작 중복 | S | 3 |
| 숫자 패드/리모컨 | 홈 기기 카드 → 조작 메뉴 | `RemoteControlScreen` 및 물리 명령 실행 구현 | **부스에서는 숨김, 최종 삭제는 사용성 확인 후** | 수동 대체 조작 경로를 제거할 수 있음 | S | 3 |
| 개발자 콘솔·BLE 로그·조이스틱 | 설정 → 개발자 모드(디버그 빌드) | 실제 raw 명령·로그 도구. 릴리스에서는 `kDebugMode`로 숨김 | **유지하되 릴리스/부스에서 숨김** | 잘못된 raw 명령, 안전 계약 우회 위험 | S | 1 |
| 세탁기·에어컨 명령 | 음성 해석·`ApplianceCommandRouter` | 서비스와 BLE 라우팅이 실제 구현 | **부스 UI에서 숨김, 코드 삭제는 보류** | 라우터·기기 타입·저장 데이터와 결합 | M | 5 |
| 실험 지표·CSV | 보호자 설정 → 실험 기록 | 누적 지표 저장·CSV 클립보드 복사 구현 | **부스에서는 접기/숨김, 연구 빌드에는 유지** | 연구 기록을 잃을 수 있음 | S | 2 |
| 상태 조회 “얼마나 남았어?” | 음성 명령 라우터 | `status` intent와 실행 상태 응답 구현 | **유지** | 남은 시간 안내는 부스 시연·접근성에 유용 | - | - |
| 다시 말하기/재생 | 음성 명령 라우터 | `replayLastSpeech`와 TTS 마지막 결과 재생 구현 | **유지** | 청각 안내 복구에 중요 | - | - |
| Gemini 음성 파싱 | 음성 화면 → Render 백엔드 | 실제 HTTP API 호출. 실패 시 규칙 경로와 분리 | **유지하되 오프라인 실패 안내 강화** | 서버 cold start·Wi-Fi 장애 | M | 6 |
| Gemini Vision 사진 매핑 | 보호자 설정 → 기기 → 사진 매핑 | 사진 업로드 후 백엔드 Vision 매핑 | **유지, 수동 매핑을 항상 대체하지 않음** | 네트워크·AI 실패 시 등록 불가 | - | - |
| 수동 매핑 | 보호자 설정 → 기기 → 버튼 위치 | 실제 좌표 보정·BLE 점검 경로 | **유지** | 실제 장치 안전과 직접 연결 | - | - |
| `guardianModeEnabled`·구형 매핑 migration | 저장소·설정 호환 경로 | 과거 데이터 호환 가능성이 있어 참조 추적 필요 | **당장 삭제 금지, 사용 데이터 확인 후 정리** | 기존 사용자 매핑·기기 목록 손실 | M | 7 |
| 구형 GRBL/G-code 호환 | 모션·매핑 실행·프로토콜 | 일부 호환 경로가 펌웨어·앱 계약에 남아 있음 | **유지하되 문서·UI에서 숨김** | 실제 펌웨어 v4와 계약 불일치 가능성 | M | 8 |

## 2. 기능 목록과 코드 근거

### 2.1 사용자 핵심 흐름

앱 시작 시 `.env` 로드, 접근성 설정, 실험 지표, 활성 기기 초기화, 데모 시드, BLE warm-up, 앱 생명주기 서비스를 순서대로 시작한 뒤 `MainNavigationScreen`을 연다 (`lib/main.dart:13-32`).

하단 내비게이션은 **홈·비상·설정** 세 탭으로 고정되어 있다 (`lib/screens/main_navigation_screen.dart:39-65`). 보호자 기능은 설정의 `GuardianHubScreen` 하나로 모아져 있다 (`lib/screens/settings/settings_screen.dart:153-178`, `lib/screens/guardian/guardian_hub_screen.dart:16-28`).

핵심 실행 경로는 다음과 같다.

```text
홈 기기 카드
  → 조작 메뉴
  → 음성으로 제어
  → STT
  → 규칙 해석 또는 Render AI 파싱
  → 확인 질문
  → BLE 실행
  → 남은 시간/결과 안내
  → 비상 정지 또는 완료
```

음성 화면은 백엔드가 설정되지 않아도 마이크를 열고 “30초 돌려줘”처럼 앱 내부 규칙으로 처리할 수 있다고 명시한다 (`lib/screens/voice/voice_listening_screen.dart:240-246`). STT 종료·오류·화면 해제 시 세션과 타이머를 정리하는 코드도 있다 (`lib/screens/voice/voice_listening_screen.dart:275-340`).

### 2.2 보호자 설정

`GuardianHubScreen`은 가전 추가, 등록 기기 선택, 원점 복귀, 실험 기록을 제공한다 (`lib/screens/guardian/guardian_hub_screen.dart:16-28`, `:107-214`). 이 화면은 사용자 화면에 보호자용 장치 관리가 섞이지 않도록 만든 구조이므로 **삭제 금지**다.

가전 추가 화면은 다음을 제공한다.

- BLE 검색·선택·연결 (`lib/screens/connection/device_connect_screen.dart:45-181`)
- QR 화면 진입 (`lib/screens/connection/device_connect_screen.dart:178-183`)
- NFC 세션과 NDEF 텍스트 읽기 (`lib/screens/connection/device_connect_screen.dart:228-328`)
- 기기 코드·기기 정보 저장 (`lib/screens/connection/device_connect_screen.dart:384-443`)

QR 화면은 `mobile_scanner` 의존성이 없는 상태의 안내 화면이다. 실제 스캔 기능으로 오인될 수 있으므로, 현재 구조에서는 진입 버튼을 숨기거나 “현재는 NFC/BLE 등록을 사용한다”는 안내만 남기는 편이 안전하다 (`lib/screens/connection/qr_scan_screen.dart:1-30`).

사진 매핑과 수동 매핑은 서로 대체 관계가 아니라 **AI를 쓰는 빠른 등록 경로와 실패 시 안전한 수동 보정 경로**다. 사진 매핑은 `image_picker`와 Vision API를 사용하고 (`lib/screens/mapping/mapping_image_source.dart:1-20`, `lib/services/ai_backend_service.dart:157-193`), 수동 매핑은 실제 좌표 확인·원점 복귀·BLE 점검과 연결된다. 수동 매핑은 유지해야 한다.

### 2.3 조작 메뉴 후보

홈 조작 메뉴는 네 가지를 직접 노출한다 (`lib/screens/home/widgets/control_mode_sheet.dart:250-340`).

1. 음성으로 제어 — 핵심 흐름
2. 이미지로 제어 — 실제 구현
3. 간편 코스 — 실제 구현이나 부스 핵심 흐름과 중복
4. 숫자 패드 — 실제 구현이나 수동 대체 경로

따라서 일괄 삭제보다는 **부스 프로필에서 음성 제어만 기본 노출하고 나머지는 보호자/개발자 메뉴로 이동**하는 것이 가장 안전하다. 이미지·숫자 패드는 시각장애 사용자에게 음성 실패 시의 대체 경로가 될 수 있어, 사용성 평가 없이 완전 삭제하면 안 된다.

### 2.4 연습 모드

연습 모드는 설정 화면에서 직접 도달하며 (`lib/screens/settings/settings_screen.dart:247-277`), STT·탭 확인·3초 홀드·TTS를 별도 구현한다 (`lib/screens/practice/practice_screen.dart:27-100`). 기능이 죽은 스텁은 아니다.

다만 공공 부스에서는 방문자가 실제 가전 조작과 연습 화면을 혼동할 수 있으므로, **부스 빌드에서 숨기고 연구/교육 빌드에서는 유지**하는 것이 적절하다.

### 2.5 개발자 도구

개발자 설정은 `kDebugMode` 안에서만 렌더링되며, 개발자 모드가 켜졌을 때 음성 테스트·통신 로그·개발자 콘솔을 보여 준다 (`lib/screens/settings/settings_screen.dart:278-358`). 릴리스 APK에서는 해당 UI가 컴파일 조건상 노출되지 않는다.

따라서 개발자 도구를 제거할 필요는 없고, 오히려 실제 장치 문제를 진단하기 위해 보존하는 것이 낫다. 단, raw G-code나 조이스틱이 안전 계약을 우회하지 않는지는 별도 검증이 필요하다.

## 3. 미사용 코드·패키지·에셋 조사

### 3.1 패키지

| 패키지 | 코드 참조 상태 | 판단 |
|---|---|---|
| `flutter_tts` | `TtsService` 전역 사용 | 유지 |
| `speech_to_text` | 공용 STT 세션과 음성 화면 사용 | 유지 |
| `flutter_blue_plus` | BLE 검색·연결·notify 사용 | 유지 |
| `nfc_manager` | NFC 등록 세션 사용 | 유지 |
| `image_picker` | 사진 매핑 입력 사용 | 유지 |
| `http`, `http_parser` | 백엔드 JSON·multipart 요청 사용 | 유지 |
| `flutter_dotenv` | `.env` 로드·백엔드 URL/키 읽기 사용 | 유지하되 키 번들 노출은 별도 보안 과제 |
| `shared_preferences` | 설정·기기·매핑·지표 영속화 | 유지 |
| `url_launcher` | 비상 연락처 전화 앱 실행 | 유지 |
| `crypto`, `flutter_secure_storage` | BLE 보안·저장소 참조 확인 필요 | 삭제 전 전체 import 재확인 |
| `audioplayers`, `vibration` | `feedback_service.dart`에서 효과음·진동 사용 | 유지 |
| `wakelock_plus` | `app_lifecycle_service.dart`에서 전면 화면 유지 사용 | 유지 |
| `path_provider` | 현재 Dart import가 확인되지 않음. `pubspec.yaml:20`, `CLAUDE.md:140`은 “추후 사용”으로 기록 | **삭제 후보** |
| `google_generative_ai` | 현재 앱은 `AiBackendService` HTTP 프록시를 사용하며 직접 Gemini SDK import가 확인되지 않음 | **삭제 후보, 전체 참조 재확인 필요** |
| `http_parser` | Vision multipart MIME 처리에 직접 사용 | 유지 |
| `cupertino_icons` | 코드 import 확인 필요 | 사용처 없으면 삭제 후보 |
| `permission_handler` | `device_connect_screen.dart`에서 사용(정정) | 유지 |

실제 APK 용량 기여는 ABI, R8, 압축, native binary에 따라 달라서 현재 상태만으로 정확한 수치를 제시할 수 없다. 제거 전후에 같은 `--release --split-per-abi` 조건으로 APK 크기를 비교해야 한다.

권장 측정 명령:

```powershell
flutter build apk --release --split-per-abi
Get-ChildItem build\app\outputs\flutter-apk\*.apk |
  Select-Object Name,Length
```

### 3.2 환경 변수·에셋

`.env`는 `pubspec.yaml:43`에서 asset으로 포함되고, `main.dart:20`과 `AiBackendService`·`AppLifecycleService`에서 읽는다. 따라서 미사용 asset은 아니지만, API 키가 APK asset에 포함될 수 있다는 보안 경고가 이미 문서에 있다 (`README.md:154-157`, `docs/WORK_LOG.md:255`).

현재 확인된 환경 변수는 다음과 같다.

- `AI_BACKEND_URL`: 음성 파싱·Vision 매핑·프로필 조회·Render keep-warm에 사용
- `AI_BACKEND_API_KEY`: 선택적 `X-API-Key` 헤더에 사용

`GOOGLE_API_KEY`, `SCHOOL_API_KEY`, `MONGO_URI`는 앱 `.env`가 아니라 백엔드용 예시 문서에 속한다. 앱 asset에 실제 값을 넣지 않아야 한다.

효과음 에셋은 `feedback_service.dart`에서 `audioplayers`로 사용되므로 삭제하면 안 된다. 기타 에셋의 파일별 사용처는 **확인 필요**다.

### 3.3 제거 후보에 연결된 테스트

- 연습 화면: `test/screens/practice/practice_screen_test.dart`
- 이미지/수동 매핑: `test/screens/photo_mapping_screen_m4_test.dart`, `test/screens/mapping/*`
- 음성·상태·재생: `test/screens/voice/*`, `test/services/status_intent_test.dart`, `test/services/replay_intent_test.dart`
- 실험 지표: `test/services/accessibility_experiment_service_test.dart`
- 백엔드 cold start/URL: `test/services/app_lifecycle_service_test.dart`, `test/services/ai_backend_service_test.dart`

후보를 숨기는 경우 테스트를 삭제하기보다, **핵심 동작을 계속 보장하는 회귀 테스트로 유지**하는 것이 좋다. 완전 삭제할 때만 해당 기능 전용 테스트를 함께 정리한다.

## 4. 무인 부스 운영성

### 4.1 시작 시 동작

`main()`은 다음 작업을 순차 실행한다 (`lib/main.dart:13-32`).

1. Flutter 바인딩·세로 화면 고정
2. `.env` 로드
3. 접근성 설정·실험 지표 로드
4. 활성 기기 초기화
5. 데모 데이터 seed
6. BLE warm-up
7. 앱 생명주기 서비스 시작
8. `runApp`

설정 파일·SharedPreferences·기기 초기화가 느려지면 첫 화면 표시가 늦어질 수 있다. 현재 파일 기반 초기화는 대부분 빠른 편으로 보이나, 실제 저사양 Android 기기에서 startup 시간을 측정해야 한다.

### 4.2 타이머·구독 정리

긍정적인 점:

- `MainNavigationScreen`은 탭 확인 타이머를 dispose에서 취소한다 (`lib/screens/main_navigation_screen.dart:339-345`).
- NFC timeout timer는 `DeviceConnectScreen.dispose`에서 취소한다 (`lib/screens/connection/device_connect_screen.dart:436-443`).
- 음성 화면은 wave/recording/silence/action/press 타이머와 stop 요청 구독을 dispose에서 정리한다 (`lib/screens/voice/voice_listening_screen.dart:275-293`).
- 연습·이미지·리모컨·코스 화면도 각 action timer와 controller를 dispose에서 정리한다.
- `AppLifecycleService`의 keep-warm timer는 foreground/background 전환과 `stop()`에서 취소한다 (`lib/services/app_lifecycle_service.dart:72-112`).

확인 필요:

- 장시간 반복 실행에서 `AppLogger`의 메모리 증가 상한
- `AccessibilityExperimentService` 누적 작업 수의 상한
- BLE response/log stream에 연결된 모든 listener의 lifecycle
- `setState after dispose`는 정적 분석만으로 완전히 잡히지 않으므로 반복 실행 테스트 필요

### 4.3 BLE 재연결

`AppLifecycleService`는 foreground 복귀 시 한 번 재연결하고, `BleService` 자체의 지수 백오프 재연결과 겹치지 않도록 `_reconnecting`, `isReconnecting`, `isBusy`를 확인한다 (`lib/services/app_lifecycle_service.dart:115-151`). 설계상 무한 재시작을 직접 만드는 구조는 확인되지 않았다.

다만 실제 부스에서는 다음을 측정해야 한다.

- ESP32 전원 반복 차단 시 2→4→8초 재연결이 최대 횟수 후 종료되는지
- BLE 장치가 발견되지 않을 때 스캔·notify listener가 계속 남지 않는지
- 연결 실패 중 비상 정지가 우선 처리되는지

### 4.4 STT

음성 화면은 화면 종료 시 공용 세션에서 detach하고 stop한다 (`lib/screens/voice/voice_listening_screen.dart:275-293`). STT 자연 종료와 늦은 이벤트도 `mounted`와 상태 플래그로 제한한다.

그러나 Android 음성 인식 엔진이 네트워크 의존인지, 한국어 오프라인 모델이 실제 기기에 설치되어 있는지는 Flutter 코드만으로 보장되지 않는다. `speech_to_text`는 기기 Speech Recognizer와 설정에 영향을 받으므로 **인터넷 차단·비행기 모드에서 한국어 명령을 실제 기기로 시험해야 한다**.

### 4.5 Render 백엔드 cold start/장애

`AppLifecycleService`는 foreground에서 `/healthz`를 호출하고 10분 주기로 keep-warm한다 (`lib/services/app_lifecycle_service.dart:84-107`, `:153-215`). 기본 HTTP timeout은 60초다.

백엔드가 설정되지 않아도 음성 화면은 열리지만, 앱 규칙으로 처리할 수 있는 단순 명령만 가능하다 (`lib/screens/voice/voice_listening_screen.dart:240-246`). AI 파싱은 최대 15초 요청과 1회 재시도를 사용하고, Vision은 최대 60~65초 timeout과 재시도를 사용한다 (`lib/services/ai_backend_service.dart:100-130`, `:157-193`).

부스에서는 다음을 명확히 분리해야 한다.

- 시연 보장 명령: 앱 규칙만으로 처리되는 `30초`, `1분`, `시작`, `정지` 등
- AI 필요 명령: 자연어 확장·복합 명령
- 실패 안내: “서버가 늦다”가 아니라 “간단한 명령으로 다시 말해 달라”는 사용자 문구

### 4.6 화면 고정·충전·발열

`wakelock_plus`는 화면을 켜 두지만 CPU를 백그라운드에서 계속 유지하는 기능은 아니다. 현재 구조는 앱이 foreground인 동안 화면 잠금을 막는 목적에 적합하다.

Android 화면 고정(screen pinning)은 사용자 확인을 거치는 임시 고정이고, 완전한 lock task kiosk는 Device Owner/MDM 설정이 필요하다. 공공 부스라면 우선 Android 기본 화면 고정을 사용해 시험하고, 앱을 빠져나갈 수 없어야 하는 운영이라면 전용 기기·관리 정책 여부를 별도로 결정해야 한다.

충전기를 꽂은 채 몇 시간 켜 둘 때는 다음을 실제 기기로 측정해야 한다.

- 화면 밝기와 wakelock 상태에서 배터리 온도
- BLE 연결·STT·TTS를 반복했을 때 발열
- 충전 중 화면 밝기 자동 조절·저전력 모드 진입 여부
- 폰 거치대의 통풍과 케이블 고정

## 5. 추가 조사 항목

### 5.1 CT 종료 알림

현재 `pubspec.yaml`에는 `flutter_local_notifications`가 없다. 따라서 Android 13 알림 권한이나 상시 실행 foreground service가 현재 구현되어 있다고 볼 근거는 없다.

`flutter_local_notifications`를 추가하면 Android 13(API 33) 이상에서 `POST_NOTIFICATIONS` 권한 요청과 알림 채널·foreground service 설정이 필요하다. BLE를 앱이 내려간 뒤에도 유지하려면 알림 플러그인만으로는 부족하고 Android native foreground service 또는 전용 BLE 백그라운드 설계가 필요하다.

권고:

- CT 종료 알림이 “앱이 foreground인 부스”에서만 필요하면 먼저 앱 내부 TTS/화면 상태로 해결
- 앱이 background/terminated 상태에서도 필요하면 별도 설계로 분리
- Android 13 권한, 서비스 수명, 배터리 최적화 제외, 개인정보 표시까지 함께 검토

### 5.2 서버 없는 음성 처리

현재 구조는 단순 명령의 로컬 규칙 경로와 AI 백엔드 경로를 분리하고 있다. 이는 부스 운영에 유리하다. 다만 “한국어 STT 자체가 오프라인으로 되는가”는 앱 코드가 아니라 Android Speech Recognizer·기기 언어팩에 달려 있으므로, 다음 명령을 인터넷 차단 상태에서 실측해야 한다.

- `전자레인지 30초`
- `30초 시작`
- `멈춰`
- `얼마나 남았어?`
- `아까 그거 다시`

음성 인식이 실패하면 화면 버튼을 통한 시연 대체 경로를 반드시 준비해야 한다.

### 5.3 TalkBack 안내

Flutter 공식 API 문서 기준으로 `SemanticsService.announce`는 Flutter 3.35.0-0.1.pre 이후 deprecated이며 `sendAnnouncement`가 대체 API로 제시된다. 또한 Android의 announcement event는 TalkBack 음성 큐를 비우는 등 disruptive behavior 때문에 deprecated 방향이다.

(정정: 실제로는 `tts_service.dart:225`에서 사용 중이다.) TTS와 `Semantics(liveRegion: true)`를 함께 쓰는 구조이므로 다음을 권장한다.

- 직접 `announce` 호출 여부 전체 검색
- 결과·정지·실패는 live region/semantics 상태 변화 중심으로 유지
- Flutter 버전 업 시 `sendAnnouncement` 호환성과 Android API 36 동작을 실기 확인
- 음성 중복을 막기 위해 TTS와 TalkBack을 동시에 강제하지 않기

### 5.4 부스 운영 설정

권장 운영 프로필:

- 릴리스 APK
- 세로 방향 고정
- wakelock 활성
- Android 화면 고정
- 개발자 도구 숨김
- 음성 제어를 첫 화면의 가장 큰 진입점으로 배치
- 버튼 정지와 음성 정지를 모두 시연
- 서버 장애 시 로컬 규칙 시연으로 자동 전환

### 5.5 릴리스 빌드

`AiBackendService`는 debug build에서 HTTP를 허용하지만 release build에서는 HTTPS만 허용한다 (`lib/services/ai_backend_service.dart:63-82`). 현재 `.env`가 `https://touch-bridge-server.onrender.com`이면 이 조건에 맞는다.

개발자 메뉴는 `kDebugMode` 블록에 있으므로 release에서는 UI가 숨겨진다 (`lib/screens/settings/settings_screen.dart:278-358`). 그러나 release 빌드에서 다음을 반드시 확인해야 한다.

- `.env` asset이 실제 APK에 포함되고 올바른 Render URL을 읽는지
- Render 인증 키가 비어 있어도 공개 API 정책상 동작하는지
- Android release 권한·BLE 스캔·마이크·NFC가 debug와 동일한지
- Proguard/R8 또는 서명 APK에서 TTS/STT·BLE가 동작하는지
- 첫 실행 온보딩과 기존 SharedPreferences 데이터가 유지되는지

## 6. 안전한 정리 실행 순서

1. **부스 UI 프로필부터 분리**: QR, 연습, 코스, 숫자패드, 실험 지표를 삭제하지 않고 숨김.
2. **개발자 도구는 release에서만 숨김 확인**: raw 명령·조이스틱·BLE 로그는 개발 빌드에 유지.
3. **QR 진입 제거**: NFC/BLE 등록 안내가 명확한지 실제 보호자 테스트 후 QR 버튼만 제거.
4. **패키지 후보 정리**: `path_provider`, 직접 Gemini SDK, `cupertino_icons`, `permission_handler`의 전체 import·플랫폼 설정·테스트를 확인한 뒤 하나씩 제거.
5. **세탁기·에어컨 코드 결정**: 실제 제품 범위에서 제외할지 먼저 정하고, 삭제 대신 기기 타입 라우팅·저장 데이터·테스트를 함께 정리.
6. **릴리스 APK 생성·크기 비교**: split-per-ABI 기준으로 전후 크기와 startup 시간을 기록.
7. **무인 4시간 시험**: BLE 전원 반복, 음성·탭 반복, 서버 down, 화면 고정, 충전·발열을 같은 기기에서 측정.
8. **안전 회귀 테스트**: 비상 정지, `motionEpoch`, 정지 전파, 확인 질문, TTS 우선순위, 보호자 설정을 기준선으로 재검증.

## 7. 개발자 확인 필요 질문

1. 11월 25일 부스에서 실제로 관람객에게 보여 줄 조작 방식은 음성만인가, 이미지·숫자패드도 필요한가?
2. 사진 매핑은 현장에서 직접 시연하는가, 사전에 등록된 매핑만 사용하는가?
3. 세탁기·에어컨은 향후 제품 범위에 남겨야 하는가, 전자레인지 전용 부스로 확정하는가?
4. 기존 사용자 데이터가 남아 있는 설치본에서 `guardianModeEnabled`와 `mapping_grid_<name>` migration을 유지해야 하는가?
5. 부스용 APK는 방문객이 앱을 빠져나갈 수 없는 완전 kiosk가 필요한가, Android 화면 고정으로 충분한가?
6. 인터넷을 끊은 상태에서 한국어 STT를 반드시 보장해야 하는가?
7. CT 종료 알림은 앱이 foreground인 부스에서만 필요한가, 앱 background/terminated 상태까지 지원해야 하는가?
8. 실제 APK의 목표 최대 용량과 허용 가능한 첫 화면 표시 시간은 얼마인가?
9. 4시간 무인 운용 중 보호자가 주기적으로 점검할 수 있는가, 아니면 BLE·서버 장애도 자동 복구해야 하는가?
10. `.env`의 `AI_BACKEND_API_KEY`는 release APK에 포함되어도 되는 임시 시연 키인가? 보안상 정적 번들 노출을 허용할 수 없는 운영이면 `--dart-define` 또는 서버 측 별도 인증 구조가 필요하다.

## 참고 링크

- Flutter `SemanticsService.announce`: https://api.flutter.dev/flutter/semantics/SemanticsService/announce.html
- Flutter build modes: https://docs.flutter.dev/testing/build-modes
- `flutter_local_notifications` Android 13 권한·foreground service 문서: https://pub.dev/documentation/flutter_local_notifications/latest/
- Android 화면 고정/키오스크 참고 패키지: https://pub.dev/documentation/kiosk_mode/latest/
- `wakelock_plus`의 화면 wakelock 한계: https://github.com/fluttercommunity/wakelock_plus
