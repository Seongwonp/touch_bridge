# Touch Bridge 접근성 중심 리디자인 실행 계획

> 작성일: 2026-06-25
> 목표: Touch Bridge를 개발/시연 편의 구조가 아니라 시각장애인/저시력 사용자가 실제로 안전하게 쓸 수 있는 앱 구조로 완성한다.

## 작업 원칙

1. 일반 사용자는 화면을 거의 보지 않아도 홈, 음성 제어, 비상 정지를 수행할 수 있어야 한다.
2. 기기 추가/삭제/매핑/연결/개발자 도구는 보호자 모드 또는 개발자 모드로 격리한다.
3. 모든 단계는 구현 후 반드시 테스트하고, `docs/WORK_LOG.md`에 결과를 남긴다.
4. UI 흐름 변경 시 `docs/REPRO_RUNBOOK.md`와 `docs/JUDGING_BRIEF.md`도 같이 갱신한다.
5. Claude와 병행할 때는 같은 파일을 동시에 수정하지 않는다.

## 중요도 순서

### P0. 내비게이션 구조 재설계

**목표**
- 일반 사용자 하단 바에서 `연결`, `음성` 탭을 제거한다.
- 음성은 독립 탭이 아니라 홈/활성 기기의 주요 액션으로 제공한다.
- 연결/매핑은 보호자 모드의 기기 관리 흐름으로 이동한다.

**권장 구조**
- 사용자 모드: `홈`, `비상 정지`, `설정`
- 보호자 모드: `홈`, `기기 관리`, `비상 정지`, `설정`
- 개발자 모드: 설정 내부에서 별도 토글로 켜며, `음성 테스트`, `BLE 로그`, `개발자 콘솔`, `ESP 선택`, `조이스틱`, `raw 명령`, `속도 조절` 제공

**주요 파일**
- `lib/screens/main_navigation_screen.dart`
- `lib/screens/home/home_screen.dart`
- `lib/screens/settings/settings_screen.dart`
- `lib/screens/settings/device_management_screen.dart`

**테스트**
- 보호자 모드 OFF: 연결/매핑 탭이 보이지 않아야 한다.
- 보호자 모드 ON: 기기 관리 진입이 가능해야 한다.
- 하단 탭 이동은 기존 이중 탭/TTS 패턴을 유지해야 한다.

### P1. 보호자 모드 접근 제어

**목표**
- 보호자 모드가 켜져 있을 때만 기기 추가, 삭제, QR/BLE/NFC 연결, 사진 매핑, 수동 매핑, 개발자 도구를 허용한다.
- 보호자 모드가 꺼져 있으면 실수로 구조를 바꾸는 액션은 숨기거나 차단한다.

**주요 파일**
- `lib/services/accessibility_settings.dart`
- `lib/screens/home/widgets/home_add_device_card.dart`
- `lib/screens/home/widgets/control_mode_sheet.dart`
- `lib/screens/connection/device_connect_screen.dart`
- `lib/screens/mapping/photo_mapping_screen.dart`
- `lib/screens/mapping/manual_mapping_screen.dart`

**테스트**
- 보호자 모드 OFF에서 기기 추가 버튼이 숨겨지는지 확인.
- 보호자 모드 OFF에서 매핑 진입 시 안내 후 차단되는지 확인.
- 보호자 모드 ON에서 기존 등록/매핑 플로우가 유지되는지 확인.

**모드 분리**
- 사용자 모드: 홈/음성 제어/비상 정지/일반 설정만 사용.
- 보호자 모드: 기기 추가, 연결, 매핑, 기기 관리 사용.
- 개발자 모드: ESP 선택, 조이스틱, raw 명령, BLE 로그, 속도 조절 사용. 개발 완료 후 제거 가능한 임시 실험 모드로 유지.

### P2. 홈 화면을 시각장애인 사용자 중심으로 재구성

**목표**
- 홈 화면 첫 TTS가 현재 활성 기기, 연결 상태, 가능한 다음 행동을 알려준다.
- 큰 `말하기` 액션을 제공한다.
- 기기 변경은 큰 버튼/스와이프/TTS로 충분히 이해 가능해야 한다.
- 기기 추가/삭제/매핑은 보호자 모드에서만 노출한다.

**주요 파일**
- `lib/screens/home/home_screen.dart`
- `lib/screens/home/widgets/home_device_card.dart`
- `lib/screens/home/widgets/home_empty_state.dart`
- `lib/screens/home/widgets/control_mode_sheet.dart`

**테스트**
- 기기 없음 + 보호자 모드 OFF: 보호자에게 기기 추가 요청 안내가 나와야 한다.
- 기기 있음: 활성 기기명과 상태 TTS가 나와야 한다.
- 큰 말하기 액션이 `VoiceListeningScreen(autoStart: true)` 또는 동등한 음성 시작 흐름으로 연결되어야 한다.

### P3. 음성 명령 대상 기기 결정 정책

**목표**
- 사용자가 매번 기기를 먼저 말하지 않아도 되게 한다.
- AI가 기기명을 인식하면 해당 기기를 우선 사용한다.
- 기기명이 없으면 활성 기기, 최근 사용 기기 순서로 결정한다.
- 불확실하거나 위험할 때만 되묻는다.

**정책**
1. 발화에 포함된 기기명
2. 홈/제어에서 선택된 활성 기기
3. 최근 사용 기기
4. 후보가 여러 개거나 위험하면 TTS로 확인 질문

**주요 파일**
- `lib/screens/voice/voice_listening_screen.dart`
- `lib/services/active_device_service.dart`
- `backend/microwave_logic.py`
- `backend/prompts.py`

**테스트**
- "전자레인지 30초"는 전자레인지 대상.
- "30초 시작"은 활성 기기 대상.
- 활성 기기 없음 + 여러 기기 있음: 기기 선택 질문.

**구현 메모**
- `VoiceDeviceResolver`가 앱에 저장된 기기 목록을 기준으로 기기명을 먼저 해석한다.
- 기기명만 말한 경우에는 해당 기기를 활성화한 뒤 "어떤 동작을 할까요?"라고 다시 묻는다.
- 홈 화면은 화면 3회 터치로 현재 선택 기기의 음성 명령을 바로 시작할 수 있다.
- 모델은 명령 의도/버튼 시퀀스 파싱에 집중하고, 대상 기기 선택은 앱 로컬 정책이 우선한다.

### P4. TTS/햅틱/음성 블록 공통 규칙 정리

**목표**
- 안내 문장이 화면을 보지 않는 사용자에게 자연스럽고 짧아야 한다.
- 첫 탭, 실행, 실패, 위험 상황의 햅틱/TTS 패턴을 통일한다.

**규칙 초안**
- 화면 진입: 화면 이름 + 현재 상태 + 가능한 행동 1개
- 첫 탭: "OO 버튼입니다. 실행하려면 한 번 더 누르세요."
- 실행: "OO을 실행합니다."
- 실패: "실패했습니다. 이유는 OO입니다."
- 침묵: "말씀이 들리지 않았습니다. 다시 말하려면 마이크를 누르세요."
- 위험/정지: 강한 진동 + "즉시 중단합니다."

**주요 파일**
- `lib/services/tts_service.dart`
- `lib/services/feedback_service.dart`
- `lib/widgets/primary_button.dart`
- `lib/widgets/emergency_button.dart`
- `lib/screens/voice/voice_listening_screen.dart`
- `lib/screens/safety/emergency_stop_screen.dart`

**테스트**
- 이중 탭 상태 전환 테스트.
- 음성 침묵/실패 상태 메시지 테스트.
- 비상 정지 진입/완료 상태 테스트.

### P5. 긴급 중단 최우선 접근성 플로우

**목표**
- 일반 사용자 모드에서 비상 정지는 항상 하단 바 또는 화면 주요 위치에서 접근 가능해야 한다.
- 음성 명령 `"멈춰"`, `"정지"`, `"그만"`, `"중단"`, `"stop"`은 어떤 흐름에서도 최우선 처리한다.
- 3초 홀드는 TTS/햅틱/진행 상태가 명확해야 한다.

**주요 파일**
- `lib/screens/safety/emergency_stop_screen.dart`
- `lib/screens/safety/stop_done_screen.dart`
- `lib/widgets/emergency_button.dart`
- `lib/screens/main_navigation_screen.dart`
- `lib/screens/voice/voice_listening_screen.dart`

**테스트**
- 비상 탭 진입 테스트.
- 음성 비상 명령 우선 처리 테스트.
- 정지 완료 화면 TTS/홈 복귀 테스트.

## Claude 병행 작업 분리안

### Codex 우선 담당
- `main_navigation_screen.dart` 구조 변경
- 보호자 모드 접근 제어
- 홈 화면 음성 액션 연결
- 테스트/문서 갱신

### Claude에게 맡기기 좋은 작업
- TTS 문장 후보 작성
- 화면별 사용자/보호자/개발자 권한 표 작성
- `JUDGING_BRIEF`, `DEMO_SCRIPT_3MIN` 문구 개선
- 접근성 평가 체크리스트 초안 작성

### 동시 수정 금지 파일
- `lib/screens/main_navigation_screen.dart`
- `lib/screens/home/home_screen.dart`
- `lib/screens/settings/settings_screen.dart`
- `docs/WORK_LOG.md`

## 매 단계 완료 조건

1. 관련 코드 구현.
2. `dart format` 실행.
3. `flutter analyze` 통과.
4. 관련 테스트 추가/수정 후 `flutter test` 통과.
5. `docs/WORK_LOG.md`에 변경 내용과 테스트 결과 기록.
6. 사용자에게 실기기 확인이 필요한 항목을 명확히 보고.
