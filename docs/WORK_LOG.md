# Touch Bridge 작업 로그

> 담당: 박성원 | AI 협업: Claude Sonnet 4.6  
> 프로젝트: 2026 한이음 드림업 — 시각장애인용 가전 터치패드 자동 입력 시스템  
> 팀: 3팀 멜론머스크 (차아미 · 박성원 · 서예솔)  
> 기간: 2026.03 ~ 2026.10

---

## 2026-05-20 (세션 4) — BLE 실제 연동 1차

### BLE 서비스 구현
- **파일**: `lib/services/ble_service.dart`
- `flutter_blue_plus` 기반 실제 메서드 구현
  - `scan(timeout)` : 주변 BLE 기기 스캔 + RSSI 정렬
  - `connect(deviceId)` : 대상 기기 연결 + GATT 서비스/특성 탐색
  - `disconnect()` : 연결 해제 및 상태 초기화
  - `sendPress(x, y, deviceId)` : 버튼 좌표 명령 JSON 전송
  - `sendEmergencyStop(deviceId)` : 긴급 정지 명령 전송

### 연결 화면 연동
- **파일**: `lib/screens/connection/device_connect_screen.dart`
- `StatefulWidget` 전환 후 BLE 스캔/선택/연결 플로우 연결
- 스캔 결과 Bottom Sheet에서 기기 선택 후 연결
- 상태 카드에 연결 상태(검색 중/연결 중/성공/실패) 반영

### 음성 명령 → BLE 전송 연결
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
- `MICROWAVE_CONTROL` 명령 시 버튼 시퀀스를 3x3 좌표로 변환해 `sendPress` 호출
- `BT-06` 또는 `EMERGENCY_STOP` 명령 시 `sendEmergencyStop` 호출
- `switch` 케이스별 `return` 정리로 의도치 않은 연속 실행 방지

### 문서/의존성 업데이트
- **파일**: `pubspec.yaml` → `flutter_blue_plus` 추가
- **파일**: `CLAUDE.md`, `README.md` → BLE 1차 구현 상태 반영

---

## 2026-05-20 (세션 5) — 데이터 무결성 1차 (deviceId 도입)

### 목적
- 기기 이름 변경 시 버튼 매핑 연결이 끊기지 않도록 식별자 분리

### 변경 내용
- **파일**: `lib/screens/home/home_screen.dart`
  - `DeviceInfo`에 immutable `id` 필드 추가
  - 기기 추가 시 `deviceId` 자동 생성
  - 이름 수정 시 `id` 유지
  - 기존 `home_devices` 데이터 자동 마이그레이션:
    - `id` 없는 레코드에 신규 `deviceId` 부여
    - 중복/빈 `id` 보정
  - 기존 매핑 키 자동 마이그레이션:
    - `mapping_grid_<deviceName>` → `mapping_grid_<deviceId>`
    - `mapping_device_type_<deviceName>` → `mapping_device_type_<deviceId>`
- **파일**: `lib/screens/connection/device_connect_screen.dart`
  - QR 등록 시 `deviceId`를 `home_devices`에 저장
  - 중복 등록 검사 기준에 `id` 포함 (`id` 또는 `name` 중복 차단)
- **파일**: `lib/screens/home/home_screen.dart`
  - 버튼 매핑 진입 시 `PhotoMappingScreen(deviceId: device.id)` 전달

### 검증
- `flutter analyze` : 통과
- `flutter test` : 통과

---

## 2026-05-20 (세션 6) — 보안/운영성 1차 (API 키 클라이언트 분리)

### 목적
- 앱 번들에서 Gemini API 키를 제거하고 서버 측에서만 키를 관리

### 변경 내용
- **신규 파일**: `lib/services/ai_backend_service.dart`
  - 앱에서 AI 기능 호출을 백엔드 API로 통일
  - `POST /parse-command` (음성 명령 파싱)
  - `POST /vision-mapping` (버튼 매핑 이미지 분석)
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
  - `google_generative_ai` 직접 호출 제거
  - 백엔드 `parse-command` 호출로 전환
- **파일**: `lib/screens/mapping/photo_mapping_screen.dart`
  - Gemini Vision 직접 호출 제거
  - 백엔드 `vision-mapping` 호출로 전환
- **파일**: `backend/main.py`
  - `POST /parse-command` 추가
  - `POST /vision-mapping` 추가
  - Gemini 키/모델은 백엔드 `.env`(`GOOGLE_API_KEY`, `GEMINI_MODEL`)에서만 사용

### 운영 환경 변수
- 앱(Flutter): `AI_BACKEND_URL`
- 백엔드(FastAPI): `GOOGLE_API_KEY`, `GEMINI_MODEL`

### 검증
- `flutter analyze` : 통과
- `flutter test` : 통과

---

## 2026-05-20 (세션 7) — 테스트 체계 확장 1차

### 목적
- 회귀 위험이 큰 음성 명령 핵심 로직을 자동 테스트로 고정

### 변경 내용
- **신규 파일**: `lib/services/microwave_command_service.dart`
  - 단순 규칙 파싱(`checkSimpleRules`)
  - 버튼 시퀀스 시간 계산(`calculateSeconds`)
  - 버튼 라벨 조합(`buildCommandsLabel`)
  - 버튼→3x3 좌표 매핑(`btnToGrid`)
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
  - 내부 private 로직을 `MicrowaveCommandService` 호출로 대체
- **신규 테스트**: `test/services/microwave_command_service_test.dart`
  - 규칙 파싱 3건
  - 시간 계산 2건
  - 좌표 매핑 2건

### 검증
- `flutter analyze` : 통과
- `flutter test` : 통과 (총 8개)

---

## 2026-05-20 (세션 8) — 테스트 체계 확장 2차 (BLE/연결 흐름)

### 변경 내용
- **파일**: `lib/services/ble_service.dart`
  - 테스트용 오버라이드 훅 추가
    - `setTestOverrides(scan, connect)`
    - `clearTestOverrides()`
- **신규 테스트**: `test/screens/device_connect_screen_test.dart`
  - BLE 검색 결과 없음 시 상태 문구 검증
  - BLE 스캔 결과 선택 후 연결 성공 상태 문구 검증

### 검증
- `flutter analyze` : 통과
- `flutter test` : 통과 (총 10개)

---

## 2026-05-20 (세션 9) — 접근성 실험 지표화 1차

### 목적
- 사용자 테스트(시각장애인/저시력) 시 정량 지표를 앱 내부에서 즉시 수집

### 변경 내용
- **신규 파일**: `lib/services/accessibility_experiment_service.dart`
  - 지표 영속화(SharedPreferences)
  - 수집 항목:
    - 총 작업 수, 완료 작업 수, 완료율
    - 평균 완료 시간
    - 음성 작업 수, 수동 작업 수
    - 비상 정지 횟수
    - 이중탭 타임아웃 횟수
- **파일**: `lib/main.dart`
  - 앱 시작 시 실험 지표 로드
- **파일**: `lib/screens/control/remote_control_screen.dart`
  - 수동 작업 시작 지표 기록
  - 이중탭 타임아웃 기록
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
  - 음성 작업 시작 지표 기록
- **파일**: `lib/screens/main_navigation_screen.dart`
  - 하단 탭 이중탭 타임아웃 기록
- **파일**: `lib/screens/safety/emergency_stop_screen.dart`
  - 자연 완료 시 작업 완료 기록
  - 비상 정지 시 정지 횟수/작업 중단 기록
- **파일**: `lib/screens/settings/settings_screen.dart`
  - `접근성 실험 지표` 섹션 추가
  - 실시간 지표 표시 + 지표 초기화 버튼

### 검증
- `flutter analyze` : 통과
- `flutter test` : 통과 (총 10개)

---

## 2026-05-20 (세션 10) — 심사용 패키징

### 변경 내용
- **신규 문서**: `docs/JUDGING_BRIEF.md`
  - 문제/해결/차별점/정량지표/기대효과 요약
- **신규 문서**: `docs/DEMO_SCRIPT_3MIN.md`

---

## 2026-05-20 (세션 11) — 기기 추가 직후 자동 매핑 플로우

### 목적
- 기기만 추가하고 매핑을 빼먹는 사용 흐름을 차단하여, 등록 직후 바로 제어 가능한 상태로 유도

### 변경 내용
- **파일**: `lib/screens/home/home_screen.dart`
  - `기기 추가` 완료 시 active device(`active_device_id`, `active_device_name`) 즉시 저장
  - 추가 완료 TTS 이후 `PhotoMappingScreen(deviceId, deviceName)`으로 자동 이동
  - 결과적으로 `+` → 이름/종류 입력 → 추가 → 카메라 매핑 순서가 1개 연속 플로우로 동작

### 검증
- 수동 확인: 홈 `+`에서 기기 추가 후 매핑 화면 자동 진입 확인

---

## 2026-05-20 (세션 17) — 하드웨어-앱 통신 프로토콜 최종 정렬 (ACK 기반)

### 목적
- 실제 물리 기기(ESP32/AVR)와 앱 간의 통신 신뢰성을 확보하고 현장 테스트를 위한 디버깅 도구 구축

### 변경 내용 (App)
- **파일**: `lib/services/ble_service.dart` (v2.0 고도화)
  - **Notify/ACK 메커니즘**: 하드웨어의 응답(Notify)을 기다리는 `_sendAndWaitAck` 구현 (최대 5초 대기)
  - **수치 규격화**: `mm * 10` 정수 스케일링 전송 (`ox10`, `px10` 등)
  - **설정 제어**: `SET_SERVO`, `GET_SERVO` 명령 추가
  - **로그 스트림**: 실시간 통신 로그 전송을 위한 broadcast stream 구축
- **파일**: `lib/screens/settings/ble_log_screen.dart` (신규)
  - **하드웨어 디버깅 UI**: 실시간 SEND/RECV 로그 시각화 및 서보 설정 조회 버튼 구현
- **파일**: `lib/screens/voice/voice_listening_screen.dart`
  - 명령 전송 시 하드웨어의 ACK를 기다리도록 순차 실행 보완 및 전송 실패 시 TTS 안내 추가

### 변경 내용 (Docs)
- **파일**: `Touch_bridge_HW_code/docs/FINAL_PROTOCOL_ALIGNMENT_KO.md` (신규)
  - 하드웨어 개발자와의 최종 협의를 위한 통신 규약 및 JSON 스펙 문서화

### 검증
- 앱 설정 메뉴에 "하드웨어 디버깅" 섹션 노출 확인
- 음성 명령 시퀀스 중 하드웨어 응답 지연(Timeout) 시나리오 대응 확인

---

## 2026-05-20 (세션 16) — 통합 클라우드 연결 (QR/NFC/Manual)

### 목적
- 모든 기기 등록 경로(QR, NFC, 수동 입력)를 클라우드 DB와 통합하여 사용자 편의성 극대화

### 변경 내용 (App)
- **파일**: `lib/screens/connection/device_connect_screen.dart`
  - `_onManualInputTap()`: 6자리 기기 코드를 직접 입력받는 다이얼로그 구현
  - `QR 스캔 로직 업그레이드`: 기존의 단순 이름 등록 방식에서 클라우드 프로필 자동 로드 방식으로 통합
  - `_processCloudDeviceId()`: 통합 처리 로직을 통해 어떤 경로로든 `deviceId`만 확보되면 서버에서 매핑 정보를 즉시 동기화하도록 개선
- **파일**: `docs/DATABASE_SCHEMA.md` (신규)
  - MongoDB 컬렉션 구조 및 샘플 데이터 규격 문서화

### 검증
- 수동 입력창에 `MW-LUX-777` 입력 시 고급형 전자레인지 정보 자동 로드 확인
- QR 스캔 시 해당 기기의 버튼 매핑까지 한 번에 완료되는 'Zero-Touch' 경험 확인

---

## 2026-05-20 (세션 15) — NFC 클라우드 연동 (Zero-Configuration)

### 목적
- 시각장애인이 복잡한 설정 없이 NFC 태그만으로 기기 정보를 즉시 로드하도록 구현

### 변경 내용 (App)
- **파일**: `pubspec.yaml` → `nfc_manager` 패키지 추가
- **파일**: `lib/services/ai_backend_service.dart`
  - `fetchDeviceProfile(deviceId)` 메서드 추가: 백엔드에서 특정 기기의 JSON 매핑 정보를 가져옴
- **파일**: `lib/screens/connection/device_connect_screen.dart`
  - `_onNfcTagTap()`: NFC 세션 시작 및 태그 감지 UI 구현
  - `_processCloudDeviceId()`: 읽어온 ID로 클라우드 데이터를 조회하고, 로컬 DB(`home_devices` 및 `DeviceMappingProfile`)에 자동 등록하는 워크플로우 완성

### 검증
- NFC 태그 인식 시 바텀 시트 노출 및 진동 피드백 확인
- `MW-BASE-001` 태그 인식 시 "전자레인지 조리를 시작합니다" 등 안내와 함께 기기 자동 추가 확인

---

## 2026-05-20 (세션 14) — MongoDB 전환 (Cloud Ready)

### 목적
- SQLite를 MongoDB로 교체하여 클라우드 확장성 및 유연한 데이터 구조 확보

### 변경 내용 (Backend)
- **파일**: `backend/database.py` (전면 재작성)
  - `motor` (비동기 MongoDB 드라이버) 도입
  - JSON 프로필 저장 및 조회를 위한 NoSQL 구조 설계
  - `device_id` 유니크 인덱스 설정
- **파일**: `backend/main.py`
  - 모든 DB 호출을 `await` 기반 비동기 처리로 업데이트
  - `vision-mapping` 시 기기 프로필 자동 저장 옵션(`save_as_id`) 추가

### 검증
- `pip install pymongo motor` 설치 확인
- 서버 시작 시 `MongoDB 연결 성공!` 로그 및 샘플 데이터(`MW-BASE-001`) 자동 생성 확인

---

## 2026-05-20 (세션 13) — 백엔드 고도화 및 클라우드 인프라 Phase 1

### 목적
- 음성 명령의 정확도 획기적 개선 및 기기 프로필 클라우드화 기초 마련

### 변경 내용 (Backend)
- **파일**: `backend/main.py`, `backend/prompts.py`, `backend/microwave_logic.py` (모듈화)
  - **정규식 기반 시간 파서:** "7분 30초" 등 복잡한 시간 표현을 AI 없이 즉시 1.0 확신도로 파싱
  - **프롬프트 고도화:** AI에게 요리 전문가 페르소나 부여, 모호한 명령(냉동만두 등)에도 적정 시간 추론 기능 강화
  - **리팩토링:** 뇌(Prompts), 지식(Logic), 통로(Main)로 역할 분리
- **신규 파일**: `backend/database.py`
  - SQLite 기반 기기 프로필 저장소 구축
  - QR/NFC 연동을 위한 `device_id` 기반 조회 API 추가
- **네트워크 문제 해결**
  - `iproxy` 포트 충돌(8000) 해결 및 백엔드 포트 8001 전환
  - 아이폰-맥 간 로컬 호스트(`hostname.local`) 연결 가이드 수립

### 변경 내용 (App & Docs)
- **신규 문서**: `docs/CLOUD_INTEGRATION_PLAN.md`
  - MongoDB 전환 계획 및 QR/NFC/수동 입력 로드맵 작성

### 검증
- 백엔드: "7분 30초" 요청 시 즉시 `450s` 응답 확인
- 앱: "해동해줘" 명령 시 자동 타이머 화면 전환 확인

---

## 2026-05-20 (세션 12) — 내비게이션/중지 보완 + 유동 매핑 명시 + 로깅

### 변경 내용
- **뒤로가기 누락 보완**
  - `DeviceConnectScreen`, `SettingsScreen`, `HomeScreen`에서 `Navigator.canPop()`일 때 상단 뒤로가기 버튼 노출
  - 탭 화면으로 쓸 때는 기존처럼 상단 타이틀만 유지, push 진입 시에는 즉시 복귀 가능
- **매핑 분석 중 중지(취소) 추가**
  - `PhotoMappingScreen`에 `분석 취소` 버튼 추가
  - 분석 요청 ID 토큰 방식으로 late response 무시 처리
- **유동 그리드 명시 강화**
  - 문서/백엔드 프롬프트에서 `3x3 고정` 뉘앙스 제거
  - `rows×cols` 동적 매핑 + 기본 fallback 3x3 정책으로 정리
- **로그 체계 추가 (Flutter + Backend)**
  - 신규 `lib/services/app_logger.dart`
  - Flutter 주요 이벤트 로깅:
    - 음성 분석 시작/결과/취소/오류
    - 매핑 분석 시작/완료/취소/오류
    - BLE 스캔/연결/해제/오류
    - AI 백엔드 요청/응답 상태
  - 백엔드 `main.py`:
    - 요청 미들웨어(요청 ID, 경로, status, elapsed ms)
    - `/parse-command`, `/vision-mapping` 핵심 이벤트 로깅
  - 3분 발표 시간축 기준 시연 스크립트
- **신규 문서**: `docs/REPRO_RUNBOOK.md`
  - 환경 변수/실행 명령/검증 명령/장애 대응 플랜 B
- **파일**: `README.md`
  - 심사용 문서 링크 섹션 추가
- **파일**: `CLAUDE.md`
  - 심사용 패키징 완료 상태 반영

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
