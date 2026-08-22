# Touch Bridge 작업 로그

> 담당: 박성원 | AI 협업: Gemini CLI (Auto-Edit)
> 프로젝트: 2026 한이음 드림업 — 시각장애인용 가전 터치패드 자동 입력 시스템  
> 팀: 3팀 멜론머스크 (박성원 · 서예솔) — README/CLAUDE.md와 통일 (2026-08-21)  
> 기간: 2026.03 ~ 2026.10

---

## 2026-06-23 — 사진 매핑/음성 제어 실기기 안정화 계획

### 배경
- 실기기에서 `docs/MOCK_MAPPING_DATA.md`의 물리 좌표 기반 음성 명령 실행은 확인됨.
- 개발자 모드 조이스틱 좌표 이동도 확인됨.
- 현재 문제는 사진 매핑 저장값과 음성 명령 실행 경로가 목데이터 fallback에 묶여 있어, 기기별 실제 매핑이 제어에 안정적으로 반영되지 않는 점.

### 작업 원칙
1. 검증된 목데이터 좌표는 데모 fallback으로 보존한다.
2. 사진/수동 매핑으로 저장한 기기별 매핑을 음성 실행에서 우선 사용한다.
3. 각 단계가 끝날 때마다 `flutter analyze`, 관련 단위/위젯 테스트, 문서 최신화를 수행한다.
4. 상세 TODO는 `docs/MAPPING_VOICE_STABILIZATION_TODO.md`를 기준으로 관리한다.

### 1차 구현 완료
- `VoiceListeningScreen._sendBleSequence`를 저장 매핑 우선 실행으로 변경.
  - 활성 기기의 `DeviceMappingProfile`에 `buttonMap` 또는 그리드 설정이 있으면 `SET_GRID` 후 `BTN_n` 전송.
  - 저장 매핑이 없을 때만 `docs/MOCK_MAPPING_DATA.md` 기반 물리 좌표 G-code fallback 사용.
- `MicrowaveCommandService.btnToGrid`는 3x3 논리 좌표 전용으로 복구하고, 목데이터 물리 좌표는 `btnToPhysical`에만 유지.
- `PhotoMappingViewModel`이 Vision 응답의 `button_id`, `row`, `col`, `label`을 처리하도록 수정.
- 매핑 저장 후 하드웨어 응답 체크를 실제 펌웨어 응답(`GRID_CONFIG_UPDATED`, `ok`)과 맞춤.
- 개발자 모드/수동 매핑 조이스틱을 `$J` 대신 `G91` -> `G1` -> `G90` 안정 이동 명령으로 변경.
- 백엔드 `microwave_logic.py`의 Python boolean 오타(`true` -> `True`) 수정.

### 검증
- `flutter analyze`: 통과.
- `flutter test`: 통과.

### 다음 작업 최우선순위로 승격
- 앱의 핵심 대상이 시각장애인/저시력 사용자임을 기준으로, 보호자 모드와 접근성 UX 재정렬을 TODO 최상단으로 올림.
- 보호자 모드가 켜져 있을 때만 기기 추가/삭제/매핑/고급 설정을 허용하는 정책을 다음 작업의 첫 번째 과제로 둔다.
- TTS, 햅틱, 음성 블록, 침묵/실패 안내, 긴급 중단 UX를 화면을 보지 않는 사용자가 익숙하게 쓸 수 있도록 재검토한다.
- 오늘 작업은 계획 정리까지만 수행하고, 실제 구현은 다음 작업일에 진행한다.

### UX 구조 결정 메모
- 일반 사용자에게 음성 명령은 별도 하단 탭이 아니라 전역 입력/활성 기기 제어 액션으로 제공하는 방향이 적합하다.
- 연결/매핑 화면은 일반 사용자 메인 탭이 아니라 보호자 모드의 초기 설정 및 기기 관리 흐름으로 이동한다.
- 모드별 내비게이션 초안:
  - 사용자 모드: 홈, 비상 정지, 설정.
  - 보호자 모드: 홈, 기기 관리, 비상 정지, 설정.
  - 개발자/시연 모드: 음성 테스트, BLE 연결, 개발자 콘솔, 로그 화면.
- 음성 명령 대상 기기 결정 정책:
  1. 발화에 포함된 기기명을 우선 사용.
  2. 없으면 홈/제어에서 선택된 활성 기기를 사용.
  3. 없으면 최근 사용 기기를 사용.
  4. 불확실하거나 위험하면 TTS로 되묻는다.

---

## 2026-06-25 — 접근성 중심 리디자인 실행 계획 수립

### 목표
- 앱을 개발/시연용 탭 구조에서 시각장애인/저시력 사용자의 실제 사용 흐름에 맞게 재설계한다.
- 보호자 모드, 사용자 모드, 개발자/시연 모드를 분리해 기기 추가/삭제/매핑/연결 기능을 안전하게 격리한다.
- Claude와 병행 작업할 수 있도록 담당 영역과 동시 수정 금지 파일을 문서화한다.

### 산출물
- `docs/ACCESSIBILITY_REDESIGN_PLAN.md` 추가.
- `docs/MAPPING_VOICE_STABILIZATION_TODO.md`에서 접근성 리디자인 계획 문서 링크 추가.

### 우선순위
1. 내비게이션 구조 재설계.
2. 보호자 모드 접근 제어.
3. 홈 화면을 활성 기기 + 큰 음성 액션 중심으로 재구성.
4. 음성 명령 대상 기기 결정 정책 구현.
5. TTS/햅틱/음성 실패/긴급 중단 안내 공통화.
6. 테스트와 문서 최신화.

### 작업 규칙
- 각 구현 단계마다 `dart format`, `flutter analyze`, `flutter test`를 수행한다.
- 단계 완료 시 `docs/WORK_LOG.md`에 변경 내용과 테스트 결과를 기록한다.
- Claude와 병행할 경우 `main_navigation_screen.dart`, `home_screen.dart`, `settings_screen.dart`, `WORK_LOG.md`는 동시에 수정하지 않는다.

### 1차 구현 완료
- 하단 내비게이션을 보호자 모드 기준으로 동적 구성하도록 변경.
  - 사용자 모드: `홈`, `비상`, `설정`.
  - 보호자 모드: `홈`, `기기 관리`, `비상`, `설정`.
  - 기존 `연결`, `음성` 탭은 일반 사용자 하단 바에서 제거.
- 일반 사용자용 `EmergencyAccessScreen` 추가.
  - 큰 이중 확인 비상 정지 버튼 제공.
  - 현재 연결 기기 또는 활성 BLE 기기에 `sendEmergencyStop` 전송.
- 홈 화면을 활성 기기 + 큰 `말하기` 버튼 중심으로 변경.
  - 음성 제어는 홈의 `말하기` 버튼에서 `VoiceListeningScreen(autoStart: true)`로 진입.
  - 보호자 모드 OFF에서는 새 기기 추가 카드와 롱프레스 관리 기능 숨김.
  - 보호자 모드 OFF + 기기 없음 상태에서는 보호자에게 기기 추가 요청 안내.
- 설정 화면을 사용자 설정/보호자 설정/개발자 도구로 구획.
  - 보호자 모드 ON일 때만 기기 추가 및 연결, 기기/하드웨어 관리, 음성 테스트, BLE 로그, 개발자 콘솔 노출.
- 기기 관리 화면에 새 기기 추가 진입 버튼과 빈 상태 안내 추가.

### 검증
- `flutter analyze`: 통과.
- `flutter test`: 통과.
- 추가 테스트: `test/screens/main_navigation_screen_test.dart`
  - 사용자 모드 하단 바에서 `연결`, `음성`, `기기 관리`가 보이지 않는지 확인.
  - 보호자 모드 하단 바에서 `기기 관리`가 보이고 `연결`, `음성`이 보이지 않는지 확인.

### Claude 문서 작업 반영
- Claude가 작성한 `docs/ACCESSIBILITY_COPY_GUIDE.md`의 TTS 원칙을 코드 문구에 1차 반영.
- 홈 진입 안내를 "화면 이름 → 현재 상태 → 다음 행동" 구조로 짧게 수정.
- 설정 진입 및 보호자 모드 ON/OFF 안내를 구체적인 행동 중심 문구로 수정.
- 음성 인식 시작/침묵/실패/재시도 문구를 다음 기준으로 정리.
  - "말씀이 들리지 않았습니다. 다시 말하려면 마이크를 누르세요."
  - "명령을 이해하지 못했습니다. 기기 이름과 동작을 함께 말해 주세요."
- 비상 정지/정지 완료 문구를 "즉시 중단했습니다. 기기가 멈췄습니다." 중심으로 통일.
- 사진 매핑 AI 분석 문구에서 모호한 "잠시만 기다려주세요"를 제거하고 예상 시간과 대체 행동을 안내.

### 재검증
- `flutter analyze`: 통과.
- `flutter test`: 통과.

### 음성 명령 대상 기기 결정 로직 구현
- `VoiceDeviceResolver` 추가.
  - 등록된 홈 기기 목록에서 발화에 포함된 기기명을 먼저 찾는다.
  - 기기명이 없으면 홈/제어에서 선택된 활성 기기를 사용한다.
  - 활성 기기 없이 여러 기기가 있으면 "어떤 기기를 작동할까요?"라고 되묻는다.
  - 기기명만 말하면 해당 기기를 활성화하고 "어떤 동작을 할까요?"라고 다시 묻는다.
- `VoiceListeningScreen`에서 AI 파싱 전에 대상 기기를 로컬 정책으로 확정하도록 변경.
  - AI/백엔드는 기기 선택이 아니라 동작 의도와 `BT-xx` 버튼 시퀀스 생성에 집중한다.
  - 등록 기기에 BLE ID가 없어도 현재 연결된 ESP32를 끊지 않도록 기존 활성 BLE 정보를 보존한다.
- 홈 화면에 화면 3회 터치 음성 진입을 추가.
  - 현재 선택된 기기를 활성화하고 `VoiceListeningScreen(autoStart: true)`로 진입한다.
  - 기기가 없으면 보호자에게 기기 추가를 요청하는 TTS만 안내한다.

### 검증
- `dart format`: 통과.
- `flutter analyze`: 통과.
- `flutter test`: 통과.
- 추가 테스트: `test/services/voice_device_resolver_test.dart`
  - 발화에 포함된 기기명 우선 선택.
  - 기기명만 말했을 때 동작 재질문.
  - 기기명이 없을 때 활성 기기 fallback.
  - 활성 기기 없이 여러 기기가 있을 때 기기 선택 재질문.
  - 등록 기기가 없을 때 보호자 기기 추가 요청 안내.

### 사진 매핑 좌표 보존 및 테스트 터치 1차 구현
- `DeviceMappingProfile`에 `buttonPositions` 추가.
  - 사진 위에서 사용자가 찍은 normalized 좌표(`x`, `y`)를 버튼별로 저장한다.
  - 기존 row/col만 있는 프로필은 그리드 중심점 좌표로 자동 보정해 하위 호환을 유지한다.
- `PhotoMappingViewModel` 저장 로직 변경.
  - 저장 시 `buttonMap(row/col)`과 `buttonPositions(x/y)`를 함께 저장한다.
  - 새 버튼은 `BT-01`부터 순서대로 할당하고 기본 라벨을 `10초`, `30초`, `1분`, `시작` 등 논리 버튼명으로 지정한다.
  - 초기화는 기준점과 버튼 포인트를 모두 초기화한다.
- `ImageControlScreen` 표시 로직 변경.
  - 이미지 위 노란 마커는 `buttonPositions`를 우선 사용한다.
  - 하드웨어 실행은 기존 저장 `buttonMap(row/col)`을 사용해 현재 펌웨어 계약과 호환된다.
- 사진 매핑 마커 탭 UX 변경.
  - 기존 즉시 삭제 대신 `테스트 터치`, `이름 변경`, `삭제` 액션 시트를 표시한다.
  - `테스트 터치`는 현재 그리드 설정을 전송한 뒤 해당 버튼의 row/col `BTN_n`을 실행한다.

### 검증
- `dart format`: 통과.
- `flutter analyze`: 통과.
- `flutter test`: 통과.
- 추가 테스트: `test/services/device_mapping_service_test.dart`
  - `buttonPositions` 직렬화/역직렬화 확인.
  - 기존 row/col-only 프로필의 사진 좌표 자동 보정 확인.

### 반응형 이미지 좌표계 안정화
- `MappingCoordinateService` 추가.
  - `BoxFit.contain` 기준으로 컨테이너 안에서 실제 사진이 보이는 `Rect`를 계산한다.
  - 레터박스 영역 터치는 매핑 좌표로 저장하지 않는다.
  - normalized 좌표와 화면 로컬 좌표를 같은 Rect 기준으로 상호 변환한다.
- `PhotoMappingScreen` 좌표계 수정.
  - 기존 `BoxFit.cover`를 제거해 사진이 잘리지 않도록 변경.
  - 사용자가 찍는 기준점/버튼 좌표는 실제 사진 표시 영역 안에서만 계산한다.
  - 마커 드래그도 사진 표시 영역 크기를 기준으로 보정한다.
- `ImageControlScreen` 좌표계 수정.
  - 사진 매핑 화면과 같은 `MappingCoordinateService`를 사용한다.
  - 화면 크기나 사진 비율이 달라도 저장된 `buttonPositions`가 실제 사진 위 같은 위치에 표시된다.

### 검증
- `dart format`: 통과.
- `flutter analyze`: 통과.
- `flutter test`: 통과.
- 추가 테스트: `test/services/mapping_coordinate_service_test.dart`
  - 가로/세로 비율이 다른 사진의 contain 배치 Rect 계산.
  - 레터박스 영역 터치 무시.
  - 이미지 내부 터치 좌표 normalized 변환.
  - normalized 좌표의 로컬 좌표 복원.

### 기능 완성 인벤토리 및 실행 계층 공통화
- `docs/FEATURE_COMPLETION_INVENTORY.md` 추가.
  - 홈, 기기 관리, 연결, 사진 매핑, 수동 매핑, 음성 명령, 비상 정지, 설정, 개발자 모드의 현재 상태를 `완료`, `불안정`, `미연결`, `테스트 없음`, `실기기 필요` 기준으로 분류.
  - 오늘 남은 작업과 실기기 의존 항목을 분리.
- `MappingExecutionService` 추가.
  - 저장 매핑 기반 버튼 실행을 공통화.
  - 음성 명령, 이미지 제어, 코스 제어, 사진 매핑 테스트 터치가 같은 `SET_GRID + BTN_n` 경로를 사용.
  - 실행 로그에 `button_id`, `row`, `col`, `btn`, `x`, `y`, `device_id` 기록.
- 사진 매핑 화면에 `전체 버튼 테스트` 추가.
  - 저장 전 매핑된 버튼 전체를 순서대로 테스트.
  - 실패 시 "이 버튼 위치를 다시 조정하세요" TTS 안내.
- 수동 매핑 화면 원점/캘리브레이션 UX 보강.
  - 빨간 기준점과 실제 하드웨어 원점의 관계를 설명하는 안내 박스 추가.
  - `홈으로 이동`, `현재 위치를 원점으로 지정`, `원점 테스트 터치` 버튼 추가.
- 음성 저장 매핑 경로는 공통 실행 서비스로 전환.
  - 검증된 목데이터 G-code fallback은 데모 안정성을 위해 유지.

### 검증
- `dart format`: 통과.
- `flutter analyze`: 통과.
- `flutter test`: 통과.
- 추가 테스트: `test/services/mapping_execution_service_test.dart`
  - 저장된 `buttonMap` 좌표 우선 사용.
  - 저장 좌표가 없을 때 3x3 논리 좌표 fallback.
  - fallback 좌표가 현재 그리드 밖이면 null 반환.

### 사용자/보호자/개발자 모드 분리
- `AccessibilitySettings`에 `developerModeEnabled` 추가.
  - 기본값은 OFF.
  - 설정값은 SharedPreferences `developer_mode`에 저장.
- 설정 화면을 3모드 구조로 정리.
  - 사용자 모드: 접근성/TTS/비상 연락처 중심.
  - 보호자 모드: 기기 추가, 연결, 기기 및 하드웨어 관리.
  - 개발자 모드: 음성 테스트, BLE 로그, 개발자 콘솔.
- 개발자 콘솔 기능 보강.
  - `ESP 선택`으로 주변 ESP32 검색 및 연결 가능.
  - 현재 연결된 ESP 이름/ID 표시.
  - 조이스틱 이동 단위 선택 유지.
  - 이동 속도 `F값` 슬라이더 추가.
  - raw 명령 전송 유지.
  - 콘솔 로그에 검색/선택/연결/이동 명령 상태 표시.

### 검증
- `dart format`: 통과.
- `flutter analyze`: 통과.
- `flutter test`: 통과.
- 추가 테스트: `test/services/accessibility_settings_test.dart`
  - 개발자 모드 기본값 OFF.
  - 저장된 개발자 모드 ON 값 로드.

---

## 2026-06-16 — 기기 등록/매핑 플로우 개편 및 기술 부채

### 기기 등록 및 매핑 플로우 개선 계획 (COMPLETED)
사용자 등록 및 제어의 신뢰성을 높이기 위해 다음과 같은 로직으로 개편 완료:

1. **[COMPLETED] 등록/매핑 프로세스 분리 및 고도화 (`DeviceConnectScreen`)**
   - 구현 완료: 기기 등록(`DeviceConnectScreen`)과 매핑(`PhotoMappingScreen`) 과정을 명확히 분리. 기기 등록 시 모터 동작 방지.

2. **[COMPLETED] 매핑 좌표 불일치 이슈 해결**
   - 구현 완료: `BleService`에 `readResponse` 추가 및 `PhotoMappingScreen`의 `_executeBleUpload`에서 `SET_GRID` 전송 후 `GRID_OK` 응답 대기/검증 로직 구현.

3. **[COMPLETED] 하드웨어 움직임 불안정 이슈 해결 기초 작업 및 홈(Homing) 로직 추가**
   - 구현 완료: `BleService`에 `sendHoming` 추가.

4. **[COMPLETED] 매핑 화면(`PhotoMappingScreen`) 초기 위치 보정 기능 구현**
   - 구현 완료: `_redMarkerPosition` 상태 추가, UI에 Red Marker 표시 및 드래그를 통한 기준점(0,0) 설정 로직 구현. 터치 시 기준점 우선 설정.

5. **[COMPLETED] 기기-ESP32 간 동적 연결 전환 시스템 구현**
   - 구현 완료: `ActiveDeviceService.setActiveDevice` 호출 시 자동으로 `BleService.ensureConnected`를 트리거하여 다이내믹 연결 전환 구현.

6. **[PARTIALLY COMPLETED] 하드웨어 움직임 불안정 이슈 해결 (레이턴시 측정)**
   - 구현 완료: `BleService.sendPress`에 레이턴시 측정 및 `AppLogger` 기록 기능 구현.

7. **[COMPLETED] 음성 명령 기반 즉시 제어 구현**
   - 구현 완료: `MicrowaveCommandService`에 정규식 기반 `IMMEDIATE_PRESS` 파싱 로직 추가 및 `VoiceListeningScreen`에서 해당 액션 처리 로직 구현.

8. **[COMPLETED] 매핑 화면(`PhotoMappingScreen`) UX 개선**
   - 구현 완료: `_buildMarker`에서 `GestureDetector` 이벤트를 탭(삭제)과 롱프레스(수정)로 변경 적용.

9. **[COMPLETED] 하드웨어 우선 기기 등록 아키텍처 구현**
   - 구현 완료: `DeviceConnectScreen`에서 허브 연결 상태 확인 후 가전 등록 허용 로직 적용.

10. **[COMPLETED] 상태 가시화 헤더 UI 구현**
    - 구현 완료: `TopAppBar`를 `ActiveDeviceService` 및 `BleService` 상태를 구독하도록 변경하여 실시간 표시 구현.

11. **[COMPLETED] 이미지 피커 리소스 격리 작업**
    - 구현 완료: `image_picker` 호출 전 `_tts.stop()` 호출 및 `Future.delayed`를 통한 세션 전환 지연 적용.

12. **[COMPLETED] 코드 구조화 (Refactoring)**
    - 구현 완료: `ButtonMarker`, `MappingHeader` 위젯 추출 및 `PhotoMappingViewModel` (MVVM) 도입.

13. **[COMPLETED] 음성 명령 - 물리 좌표 매핑 정밀화**
    - 구현 완료: `BT-01`, `BT-02`, `BT-08` 물리 좌표 매핑 및 G-Code 직접 전송 로직 적용.

14. **[TODO] 하드웨어 신뢰성 강화**
    - 문제: 통신 지연(`ACK` 누락) 발생 시 하드웨어 명령 유실 가능성.
    - 조치: 펌웨어에서 명령별 `ACK` 피드백을 강화하고, 앱에서는 타임아웃 발생 시 재시도 로직 구현.

15. **[COMPLETED] UI 반응형 레이아웃 최적화**
    - 구현 완료: `ResponsiveScale` 로직 개선 및 전역 화면 레이아웃 가변성 확보.

---

## [기술 명세] 음성 명령 및 좌표 매핑 가이드

### 1. 물리 좌표 체계
- **데이터 위치**: `docs/MOCK_MAPPING_DATA.md`
- **매핑 방식**: `BT-01` 등의 논리적 ID를 하드웨어 기계 좌표(`MPos`)와 연결.
- **예시**:
    - 1번 버튼 (`BT-01`) -> `X=2.0, Y=22.0`
    - 2번 버튼 (`BT-02`) -> `X=9.0, Y=22.0`
    - 8번 버튼 (`BT-08`) -> `X=8.0, Y=2.0`

### 2. 하드웨어 전송 명령 (G-Code)
- **이동**: `G90 G0 X{x} Y{y}`
- **터치**: `G1 Z-1.0 F150` -> `G4 P0.4` -> `G0 Z0.0 F150` (시연용 1mm 깊이)

### 3. 음성 명령 흐름
1. 사용자가 "1번 눌러줘" 발화.
2. `MicrowaveCommandService`가 `BT-01` 의도 파악.
3. `btnToPhysical`에서 물리 좌표 획득.
4. `BleService.sendRaw`를 통해 G-Code 전송.

---

## 2026-06-16 — 자동 BLE 매핑 및 접근성 연결 고도화

### 자동 BLE 매핑 시스템 구현
- **목적**: "가전기기 - 전용 하드웨어(ESP32)" 간의 1:1 관계를 자동화함.
- **변경 내용**:
  - `home_devices` 데이터 구조에 `bleId`, `bleName` 추가.
  - `ActiveDeviceService` 캐시 고도화 및 Self-Healing 연결 로직 적용.

### 검증
- `flutter analyze`: 통과
- 음성 명령 시뮬레이션 및 실기기 테스트 (1번, 2번, 8번 작동 확인)

---

## 2026-06-30 — 구조 리팩토링 및 디자인 토큰 정리 (Claude 협업)

### 배경
- 메인 화면 등 전반적인 구조가 어색하다는 피드백 + "파일이 길어도 되니 책임별로 나누는 게 낫다"는 방향 확인.
- 디자인도 고대비 다크 테마(저시력 접근성 의도)는 유지하되, 톤이 단조롭고 카드/버튼 위계가 부족하다는 피드백.

### 구조 정리
- **하단 네비게이션 중복 제거**: `main_navigation_screen.dart`의 실제 사용 중인 탭 구성과 별개로 `widgets/bottom_nav_bar.dart`(MainTab enum)가 다른 탭 구성으로 따로 존재했음. `stop_done_screen.dart`에서만 쓰였는데, 그 화면에서 control/voice/settings 탭을 누르면 TTS로 "이동합니다"라고 안내만 하고 실제 화면은 안 바뀌는 버그가 있었음 — 음성에 의존하는 사용자에게 특히 위험. 죽은 위젯 삭제, 화면은 기존 "홈으로 돌아가기" 버튼만 남기는 것으로 단순화.
- **가짜 버튼 제거**: `stop_done_screen.dart`의 "메뉴"/"프로필" 아이콘이 `Semantics(button: true)`만 있고 `onTap`이 전혀 연결 안 되어 있었음(눌러도 무반응). 공용 `TopAppBar`로 교체.
- **`home_devices` 저장소 단일화**: `home_screen`, `device_management_screen`, `device_connect_screen`, `photo_mapping_view_model`, `voice_listening_screen`, `active_device_service` 6곳이 각자 `SharedPreferences` + `jsonDecode/Encode`를 반복하던 걸 `services/home_device_store.dart`로 통합.
- **대형 파일 구조 분리** (책임별 위젯/서비스 파일로 분리, 줄 수는 참고용):
  - `voice_listening_screen.dart` 1071→816줄 — 음파 시각화/액션 버튼/예시 명령어 칩 위젯 분리, 순수 텍스트 매칭 로직을 `services/voice_text_matcher.dart`로 분리
  - `home_screen.dart` 508→403줄 — 헤더/음성 버튼/페이지 인디케이터/하단 내비 힌트 위젯 분리
  - `settings_screen.dart` 697→348줄 — 폼 위젯 9종을 `widgets/settings_form_widgets.dart`로 분리
  - `photo_mapping_screen.dart` 589→379줄 — 캘리브레이션 안내/이미지뷰/마커레이어/포인트액션시트 분리
  - `ble_service.dart` 585→513줄 — HMAC challenge-response 인증을 `services/ble_security_session.dart`로 분리 (public API 무변경)
  - `developer_console_screen.dart` 477→219줄 — ESP 연결 패널/ESP 선택 시트/조깅 컨트롤 패널 분리
  - `manual_mapping_screen.dart` 451→388줄 — 라벨 숫자 입력/조그 버튼/액션 칩 공용 위젯 분리(거의 동일한 버튼 빌더 3개를 1개로 통합)
- `photo_mapping_view_model.dart`(504줄, ChangeNotifier)는 전담 테스트가 없어 `notifyListeners()` 타이밍이 깨질 위험이 있다고 판단해 분리하지 않고 보존.

### 디자인 정리
- `app_colors.dart`에 보조 강조색(`secondary`, 청록), `surfaceElevated`(카드용 단계 명도), `primaryGradient`/`accentLineGradient` 추가.
- 14개 이상 파일에서 하드코딩 hex 색상 100곳 이상을 토큰으로 교체. 공용 위젯(버튼/카드/앱바)과 홈 화면, 메인 네비게이션, 비상정지 완료 화면에 그라디언트+글로우 적용.
- **버그 발견 및 수정**: 색상 토큰화 일괄 치환 중 불투명한 진회색 버튼 배경(`#2A2A2A`)이 투명한 테두리 토큰(`borderDefault`, 8% 불투명도)으로 잘못 매핑되어 `manual_mapping_screen`의 모터 테스트 버튼들이 거의 안 보이게 됐던 걸 발견, 전체 코드베이스 재검사 후 `surfaceElevated`로 수정.

### 검증
- 매 단계 `flutter analyze`(0건), `flutter test`(29/29 통과), Chrome 부팅 스모크 테스트로 회귀 확인.

---

## 2026-08-20 — [P0-1] 스크린리더 TTS 억제 정합화 (전면 코드 리뷰 후속 1단계)

### 배경 (전면 리뷰에서 발견된 버그)
- `TtsService.speak()`의 스크린리더 억제 검사가 **interrupt 승격 전 원래 priority**로
  판단하는데, 화면 코드 곳곳의 주석과 CLAUDE.md는 정반대("interrupt:true는 result로
  승격되어 억제되지 않는다")를 가정하고 있었음.
- 결과: TalkBack/VoiceOver 활성 시 **이중 탭 arm 안내, 비상정지 성공/실패 결과,
  명령 전송/실패 안내가 전부 무음**. `TtsPriority.emergency`를 명시한
  `EmergencyButton` arm 안내만 살아남는 상태였음.

### 확정한 계약 (tts_service.dart에 문서화)
- 억제 여부는 **호출부가 명시한 priority로만** 판단한다. `interrupt`는 선점 재생
  플래그일 뿐 억제와 무관.
- navigation/info → 스크린리더 활성 시 억제 (포커스/liveRegion이 대신 전달).
- result/emergency → 절대 억제하지 않음. 스크린리더에서도 들려야 하는 결과·실패·비상
  발화는 호출부에서 `priority: TtsPriority.result/emergency`를 **명시**해야 한다.

### 수정 내용
- `tts_service.dart`: 계약 주석 전면 재작성 + 테스트용 `screenReaderOverrideForTest` 추가.
- **비상 경로 emergency 명시**: `emergency_access_screen`(기기 없음/연결 실패/즉시 중단/
  ACK 결과 4곳), `emergency_stop_screen`(정지 결과), `voice_listening_screen._handleEmergencyStop`.
- **결과·arm·실패 경로 result 명시**: `emergency_stop_screen`(카운트다운 구간·홀드 안내),
  `stop_done_screen`(완료 안내·홈 버튼 arm), `main_navigation_screen`(탭 arm·탭 전환),
  `command_feedback_service`(sent/confirmed/failed), `remote_control_screen`(숫자 입력·
  초기화·시작·미연결 실패 등 전부), `course_control_screen`, `image_control_screen`.
- **liveRegion 공백 보완**(voice_listening_screen): `_sendBleSequence` 실패 4곳과
  비상정지 결과가 `_statusMessage`를 갱신하지 않아 스크린리더 채널로도 전달되지 않던
  문제 수정. 저신뢰 확인 질문은 질문 전문을 liveRegion에 싣도록 변경.
- **무반응 dead-end 보완**: remote/course/image 제어 화면의 "기기 미연결" 경로에
  실패 earcon(`playFailure`) 추가.
- **부수 수정**: `remote_control_screen._toggleStart`에서 `actualSeconds <= 0` 조기
  return 시 `_isSending`이 true로 남아 시작 버튼이 영구 무반응이 되는 잠재 버그 수정.
  탭 arm 상태를 `main_navigation_screen` Semantics(value/hint/liveRegion)로도 노출.
  arm 안내가 "취소" 한 단어였던 것을 "취소. 한 번 더 누르면 실행합니다"로 확장.
- **틀린 주석 정정**: stop_done/remote_control/main_navigation/voice_listening의
  "interrupt는 억제되지 않는다" 주석 제거, CLAUDE.md 스크린리더 지원 표 갱신.

### 테스트
- `test/services/tts_service_test.dart`에 억제 계약 회귀 테스트 5건 추가:
  SR 활성 시 navigation 억제 / interrupt:true여도 억제 / result 유지 / emergency 유지 /
  SR 비활성 시 navigation 정상 재생.
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 169/169 통과 (Flutter 3.47.1).

---

## 2026-08-21 — [P0-2] 확인 질문 후 자동 재청취 (리뷰 후속 2단계)

### 배경 (전면 리뷰에서 발견된 결함)
- 저신뢰 인식 확인("맞으면 예라고 말씀해 주세요")과 AI `needs_confirmation` 경로에서
  질문을 말한 뒤 **마이크가 꺼진 채로 끝났다**. 답하려면 마이크 버튼을 다시 찾아
  두 번(arm→확인) 눌러야 해서, 전맹 사용자에게 사실상 dead-end급 마찰이었음.
  `_restartListeningAfterPrompt()`는 기기 명확화(되묻기) 경로에서만 호출되고 있었다.

### 수정 내용
- `TtsService.waitUntilIdle()` 신설 — 발화 큐가 빌 때까지 대기(최대 10초).
  `speak()`는 재생 완료를 기다리지 않으므로, 질문이 끝난 **뒤** 마이크를 열
  타이밍을 호출부가 잡을 수 있게 하는 기반 API.
- `_restartListeningAfterPrompt()`를 고정 900ms 지연 → `waitUntilIdle` + 300ms
  버퍼로 변경. 질문 소리가 STT에 섞여 들어가거나, 질문을 듣는 중에 침묵 타이머가
  돌기 시작하는 문제를 함께 방지(기존 기기 명확화 경로도 같이 개선됨).
- 재청취 호출 추가 5곳: 저신뢰 확인 질문, 저신뢰 거절 후 "다시 말씀해 주세요",
  MICROWAVE `needs_confirmation` 확인 질문, MICROWAVE 저신뢰/빈 명령 재발화 요청,
  WASHER/AC 빈 명령 재발화 요청.
- 취소 확정("알겠습니다. 취소할게요") 등 질문이 아닌 종료 안내에는 붙이지 않음 —
  사용자가 끝내려는 흐름에서 마이크가 다시 켜지는 역효과 방지.

### 테스트
- `TtsService.waitUntilIdle` 단위 테스트 3건 추가 (유휴 즉시 완료 / 큐 소진 후 완료 /
  타임아웃 시 예외 없음).
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 172/172 통과.

---

## 2026-08-21 — [P0-3] Z축 하강 후 실패 시 복구 시퀀스 (리뷰 후속 3단계)

### 배경 (전면 리뷰에서 발견된 안전 결함)
- `mapping_execution_service.dart`의 주석 스스로 "Z축이 내려간 채로 복귀 명령이
  전송되지 않으면 물리적으로 위험"이라 경고하면서, 실제로는 Z 하강 이후 단계가
  실패하면 `fail()`만 반환하고 **복구를 시도하지 않았다**. 누름 핀이 가전 버튼을
  계속 누르는 상태(전자레인지 연속 가동 등)로 방치될 수 있었다.

### 수정 내용 (`lib/services/mapping_execution_service.dart`)
- `sendGcodeSequenceWithIndex()` 신설 — 실패한 라인 인덱스를 반환해 "Z 하강 이후
  실패"를 판별할 수 있게 함(기존 `sendGcodeSequence`는 위임 유지).
- `pressButton()` (프로필 경로): Z 하강 라인(`G1 Z…`) 이후(라인 자체 포함, `>=`)
  실패 시 best-effort 복구 `G90` → `G0 Z<안전높이>` 전송. 복구 결과를 로그
  (`mapping.press.z_recovery`)와 개발자 메시지에 기록.
- `pressPhysical()` (목데이터 경로): `zDown` 플래그로 하강~상승 구간을 추적,
  구간 내 실패 시 상대 좌표 복구 `G1 Z1.0` → `G90` 전송. 하강 명령 "전송 시점"부터
  위험 구간으로 보수적으로 간주(전달됐는데 write 실패로 보고됐을 가능성 대비).
- **복구까지 실패한 경우에만** 사용자에게 구체적 경고: "누름 장치가 버튼을 누른 채
  멈춰 있을 수 있으니 기기 상태를 확인하고, 필요하면 비상 정지를 사용해 주세요."
  복구에 성공했으면 일반 재시도 안내 유지(불필요한 공포 조성 방지).

### 테스트
- Z축 복구 회귀 테스트 6건 추가 (`test/services/mapping_execution_service_test.dart`):
  pressPhysical/pressButton 각각 하강 후 실패 시 복구 시퀀스 전송 검증,
  복구 실패 시 "눌린 채 멈춤" 경고 문구 검증, 하강 전 실패 시 복구 미전송 검증.
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 178/178 통과.

---

## 2026-08-21 — [P0-4] 수동 매핑 병합 저장 — 사진 매핑 파괴 버그 수정 (리뷰 후속 4단계)

### 배경 (전면 리뷰에서 발견된 데이터 손실 버그)
- `manual_mapping_screen._saveAndUpload`가 `buttonMap: const {}`로 **새 프로필을
  만들어 그대로 저장**했다. 보호자가 좌표 재보정 용도로 이 화면에서 저장 한 번을
  누르면 사진 매핑이 만든 buttonMap · buttonPositions · customLabels · 모션
  파라미터(travelHeightZ 등) · imagePath가 전부 기본값으로 소실됐다.

### 수정 내용
- `DeviceMappingService.mergeGridUpdate()` 신설 (순수 함수, 테스트 가능):
  그리드 값(행/열/원점/간격/홈 위치)만 갱신하고 사진 매핑 산출물은 보존한다.
- 그리드가 **줄어** 새 범위를 벗어나게 된 버튼은 잘못된 물리 좌표로 눌리는 것을
  막기 위해 제거하되, 제거 목록을 반환해 화면이 TTS(result 우선순위)+스낵바로
  반드시 고지한다 — 침묵 삭제 금지. 제거된 버튼의 위치/라벨도 함께 정리(고아
  데이터 방지).
- `manual_mapping_screen`은 기존 프로필 load → 병합 → save 흐름으로 변경.
  BLE 전송 결과 TTS 2곳에 result 우선순위 명시(1단계 계약 후속).

### 테스트
- 병합 회귀 테스트 3건 추가 (`test/services/device_mapping_service_test.dart`):
  사진 매핑 데이터 보존(각 필드 전수 검증) / 그리드 축소 시 범위 밖 버튼 제거·보고 /
  그리드 확대 시 무손실.
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 181/181 통과.

---

## 2026-08-21 — [P0-5] 셀 충돌 검출 + Gemini Vision 결과 방어 (리뷰 후속 5단계)

### 배경 (전면 리뷰에서 발견된 안전·견고성 결함)
- 사진 매핑의 정밀 터치 좌표는 표시용일 뿐, 실제 물리 좌표는 row/col 그리드
  양자화로만 계산된다. 서로 다른 두 버튼이 같은 셀에 떨어져도 **감지·경고가 없어**
  "시작" 자리에서 "취소"가 눌릴 수 있었다.
- `_applyAiMappingResult`가 파싱 **전에** `_points.clear()`를 호출해, AI가
  `"x": "0.5"` 같은 문자열을 주면 cast 예외로 기존 수동 포인트까지 소실.
  버튼 개수·그리드 크기 상한 없음(10개째부터 저장 시 조용히 유실), 빈 id에
  DateTime 문자열 삽입 등.

### 수정 내용
- `MappingCoordinateService.detectCellCollisions()` 신설 (순수 함수):
  정규화 좌표를 그리드로 양자화했을 때 같은 셀에 몰리는 버튼 라벨 그룹을 검출.
- `PhotoMappingViewModel.save()`: 저장 전 충돌 검사 — 충돌 시 저장을 중단하고
  겹친 버튼 이름을 TTS(result)로 고지, 그리드 확대/위치 조정 안내.
- `_applyAiMappingResult` 전면 방어 재작성:
  - 타입 안전 파싱(`num`/문자열 허용, 깨진 항목은 건너뛰고 카운트)
  - **전체 파싱 성공 후에만** 기존 포인트 교체 (실패 시 수동 포인트 보존)
  - 버튼 수 상한 9개(초과분 제외 고지), 그리드 상한 10×10 클램프
  - 빈/중복 id는 BT-xx 순번으로 보정 (DateTime 문자열 제거)
  - 적용 결과(개수/제외/건너뜀)를 TTS(result)로 구체 고지
- 테스트 경로 기술용어 노출 수정: `testPoint`/`testAllPoints`가 개발자용
  message(BT-xx 포함) 대신 userMessage/라벨을 읽어주도록 변경 + result 우선순위.

### 테스트
- 신규 `test/screens/mapping/photo_mapping_view_model_test.dart` 13건:
  셀 충돌 검출 4건 / save 충돌 차단 1건 / AI 방어 8건 (문자열 좌표, 부분 실패,
  전체 실패 시 보존, 빈 응답 보존, 9개 상한, 그리드 클램프, id 보정·중복 제거).
  — 리뷰에서 "치명적 무테스트 영역"으로 지적된 PhotoMappingViewModel 첫 테스트.
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 194/194 통과.

---

## 2026-08-21 — [P0-6] 가짜 동작 3종 제거/실구현 (리뷰 후속 6단계)

### 배경 (전면 리뷰에서 발견된 신뢰 붕괴 패턴)
시각장애인 사용자에게 "말은 하는데 실제로는 아무것도 하지 않는" UI는 최악의
패턴이다. 리뷰에서 3건 발견:
1. 설정의 비상 연락처 "전화 걸기"가 `_tts.speak('연결합니다.')` 한 줄로 끝 — 발신 없음.
2. NFC가 3초 기다렸다가 무조건 "찾을 수 없습니다"를 말하는 가짜 (nfc_manager는
   이미 의존성에 있었음).
3. 이미지 제어의 시작 버튼이 무조건 30초 고정 카운트다운 후 "작동이 끝났습니다"
   라고 거짓 안내 — 실제 기기는 계속 돌고 있을 수 있음.
추가로 QR 스캔 화면이 무음 스텁인데 문서는 "실제 구현(mobile_scanner)"이라고 주장.

### 수정 내용
- **전화 걸기 실구현** (`settings_screen.dart` + `url_launcher` 의존성 추가):
  tel: 스킴으로 다이얼러를 번호 프리필 상태로 열고, 실제 발신은 사용자가 통화
  버튼으로 확정(오발신 방지 — 이중 확인 원칙과 일치). 번호 미등록/발신 불가
  환경도 result 우선순위로 정직 안내.
- **NFC 실구현** (`device_connect_screen.dart`): nfc_manager 세션으로 NDEF 텍스트
  레코드에서 기기 코드를 읽어 QR/코드 입력과 동일 경로(`_processCloudDeviceId`)로
  등록. 미지원 플랫폼/NFC 꺼짐/15초 타임아웃/빈 태그 각각 정직한 안내 + 대안 유도.
  Android `NFC` 권한, iOS `NFCReaderUsageDescription` 추가 (iOS는 Xcode에서
  Near Field Communication Tag Reading capability 활성화 필요 — 미활성 시
  isAvailable=false로 안전 폴백).
- **가짜 30초 타이머 제거** (`image_control_screen.dart`): 세션 중 누른 시간
  프리셋(10초/30초/1분/5분, 기본 라벨일 때만) 누적으로 실제 카운트다운을 열고,
  누적이 없으면 간편 코스와 동일한 정직 안내("시간을 알 수 없어 타이머는 표시하지
  않습니다. 멈추려면 비상 정지를 사용하세요"). 취소 라벨 누름 시 누적 리셋.
- **QR 스텁 정직화** (`qr_scan_screen.dart`): 무음 스텁 → TTS 안내 + 대안 경로
  유도 화면. README/CLAUDE.md의 "QR 실제 구현" 허위 서술을 현재 상태로 정정.
- **보너스**: BLE 스캔에서 기기를 찾았을 때도 개수 안내 추가(기존엔 목록 시트가
  무음으로 열림), NFC 세션 dispose 정리.

### 참고
- NFC/전화는 실기기 검증 필요(에뮬레이터/PC에서는 폴백 경로만 확인 가능).
  NFC 태그는 NDEF 텍스트 레코드에 기기 코드를 쓰면 됨.
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 194/194 통과.

---

## 2026-08-21 — [P1-7] BLE 연결 이벤트 신뢰성 (리뷰 후속 7단계 — 2주차 시작)

### 배경 (전면 리뷰에서 발견된 "침묵 상태" 결함)
1. 연결 리스너 가드가 `_connectedDevice`(discoverServices 후에야 설정됨) 기준이라,
   연결 직후 플랫폼이 밀어주는 connected 이벤트가 타이밍에 따라 드롭 →
   UI/배너가 "연결됨" 안내를 영영 못 받을 수 있었다.
2. 명시적 `disconnect()`가 리스너를 먼저 취소해 disconnected 이벤트도 UI에 미전달.
3. `ActiveDeviceService.setActiveDevice`가 `ensureConnected` 실패 bool을 버림 —
   기기 선택은 성공처럼 보이는데 연결 실패가 첫 명령에서야 드러남.
   시각장애인 사용자가 연결/끊김을 모른 채 침묵 속에 방치되는 실패 모드.

### 수정 내용
- `ble_service.dart`:
  - 리스너 가드를 `identical(sub, _connectionSub)`(활성 구독 여부)로 교체 —
    타이밍 의존 드롭 제거.
  - 연결 셋업 완료 시 connected를 **명시 emit**, 명시적 disconnect 시(실제 연결이
    있었던 경우) disconnected를 명시 emit.
  - `isConnectedStream`에 `distinct()` — 명시 emit과 플랫폼 이벤트가 겹쳐도
    배너/TTS가 같은 상태를 두 번 안내하지 않음.
- `active_device_service.dart`:
  - `setActiveDevice`가 BLE 연결 결과 bool 반환 (bleId 없으면 true).
    실패 시 `active_device.ble_connect_failed` 로그. 선택 저장 자체는 유지.
  - `autoPickFirstDevice`가 `deviceType`을 함께 전달 — ApplianceCommandRouter가
    이름 추론에 의존하지 않도록.

### 테스트
- `active_device_service_test.dart`에 연결 결과 전파 3건 추가
  (실패 시 false + 선택은 저장 / 성공 시 true / bleId 없으면 true).
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 197/197 통과.

---

## 2026-08-21 — [P0-7] 물리 동작 경로 인증 게이트 (리뷰 후속 8단계)

### 배경 (전면 리뷰에서 발견된 보안 결함)
- `ble_service.dart` 주석은 "PRESS·SET_GRID·raw G-code는 반드시 인증 후에만
  허용"이라 선언했지만, 인증 검사는 JSON 명령(`_sendAndWaitAck`)에만 있고
  **물리 동작을 일으키는 `sendRaw` 경로 전체가 인증을 우회**했다.
  HMAC 세션이 보호하는 것은 set_servo/get_servo/home뿐 — 사실상 장식.

### 확정한 정책 (BleSecuritySession.authorizePhysicalAction)
- **프로비저닝된 기기(페어링 키 있음)**: 유효한 HMAC 세션 없이는 raw 명령을
  보내지 않는다(fail-closed). 세션이 없으면 자동으로 challenge/auth 핸드셰이크를
  시도하고 실패 시 차단 + `ble.raw.blocked_unauthorized` 로그.
- **미프로비저닝 기기(데모)**: 경고 로그와 함께 허용(fail-open) — 인증을
  구현하지 않은 데모 펌웨어와의 호환 유지. 프로덕션 전환 시 fail-closed로
  변경해야 함(SECURITY.md 로드맵과 연동).
- STOP(비상정지)은 기존대로 JSON 비인증 허용 유지 — 인증 실패로 못 멈추는
  상황 방지(안전 우선).

### 남은 한계 (펌웨어 협업 필요 — 문서화만)
- `provision`이 여전히 비인증·평문: 최초 1회 물리 확인(기기 버튼) 기반 제한은
  펌웨어 측 구현이 필요하다. 세션 수립 후 명령별 MAC/카운터 부재도 동일.
  → `docs/SECURITY.md` 프로덕션 로드맵 항목으로 유지.

### 테스트
- **`ble_security_session` 첫 테스트 7건** 신설(리뷰 지적: 보안 코어 무테스트):
  미프로비저닝 fail-open(핸드셰이크 미시도 확인) / 핸드셰이크 성공 허용(MAC hex
  검증) / 인증 실패 차단 / NONCE 형식 오류 차단 / 세션 캐시(재인증 없음) /
  reset 후 재인증 / 키 다르면 MAC 다름.
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 204/204 통과.

---

## 2026-08-21 — [P1-8] BLE 응답 채널 재설계: 명령 직렬화 + waiter 선등록 (리뷰 후속 9단계)

### 배경 (전면 리뷰에서 발견된 경쟁 조건)
1. `_sendAndWaitAck`과 `readResponse`가 **같은 `_ackCompleter`를 덮어써** 동시
   명령 시 첫 호출의 completer가 유실되고, 두 번째 호출이 첫 명령의 응답을
   받을 수 있었다(명령-응답 상관관계 없음, 큐/뮤텍스 없음).
2. `sendGetStatus`는 `sendRaw('$$')` **완료 후에** waiter를 등록해, write 직후
   도착한 응답이 버려지고 2초 타임아웃으로 끝나는 경쟁. 사진 매핑의
   `sendSetGrid + readResponse` 패턴도 동일한 문제.

### 수정 내용 (`ble_service.dart`)
- `_withCommandLock` 명령 직렬화 큐 도입: 모든 write와 응답 대기가 요청 순서대로
  하나씩 실행된다. 앞선 명령이 예외로 끝나도 큐는 계속 진행.
  **재진입 금지 계약**: 인증 핸드셰이크는 잠금 밖에서 수행(주석 명시) —
  sendRaw 게이트/JSON 인증 모두 잠금 획득 전에 auth를 끝내므로 데드락 없음.
- `_ackCompleter` → `_responseWaiter`로 정리하고 조작을 잠금 안으로 한정.
- `sendRawWithResponse()` 신설: **waiter를 write 전에 등록**하고 다음 notify
  한 줄을 기다린다. `sendGetStatus`가 이를 사용(응답 유실 경쟁 해소).
- `sendSetGridWithResponse()` 신설 + 사진 매핑 `_executeBleUpload`를 이 API로
  전환. 위험한 구 `readResponse`는 제거. 전송 미확인 시 메시지도 정직화
  ("하드웨어 전송 미확인 — 연결 상태를 확인하세요").
- 비상정지(STOP)는 JSON 경로로 잠금을 공유하지만, raw 라인 write는 잠금 구간이
  짧아(응답 대기 없음) 시퀀스 사이에 즉시 끼어든다.

### 남은 한계 (하드웨어 연동 시 개선)
- GRBL `ok` 기반 흐름 제어(라인별 ok 확인 후 다음 라인)는 실기기에서 응답
  포맷을 확인한 뒤 도입 예정 — 현재는 직렬화 + 120ms 간격 오픈루프 유지.

### 테스트
- `ble_command_queue_test.dart` 신설 4건: 순서 보장 / 예외 후 큐 지속 /
  다중 결과 반환 / sendRawWithResponse 오버라이드 경로.
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 208/208 통과.

---

## 2026-08-21 — [P1-9] STT 싱글톤 이중 초기화 해소 — 공용 음성 세션 (리뷰 후속 10단계)

### 배경 (전면 리뷰에서 발견된 신뢰성 결함)
- `speech_to_text`의 `SpeechToText`는 패키지 차원의 싱글톤이며 `initialize()`
  콜백은 **최초 1회만** 등록된다. VoiceListeningScreen과 EmergencyStopScreen이
  각자 초기화해서:
  (a) 나중에 초기화한 화면의 onStatus/onError가 등록되지 않아 **비상 화면의
      "멈춰" 음성 재청취 루프가 조용히 죽을 수 있었고** (3초 홀드만 남는 상태),
  (b) 스택 아래 깔린 voice 화면의 onStatus가 비상 화면의 listen 이벤트를 받아
      `_isRecording` 상태가 오염되고 엉뚱한 발화("말씀이 들리지 않았습니다")가
      나올 수 있었다.

### 수정 내용
- `services/speech_session_service.dart` 신설:
  - 초기화는 한 번만 수행(멱등), macOS TCC 가드도 이곳으로 일원화.
  - 화면은 `attach(SpeechClient)`/`detach(name)`로 콜백을 등록/해제하고,
    이벤트는 **가장 나중에 attach한 화면(스택 최상단)** 에만 전달된다 —
    push/pop 내비게이션과 자연스럽게 맞는 구조. detach 시 이전 화면이 이어받음.
- 두 화면을 공용 세션으로 이전: listen/stop/isListening 전부 서비스 경유,
  dispose에서 detach. 비상 화면의 "멈춰" 감지가 화면 진입 순서와 무관하게
  동작하게 됨.

### 테스트
- `speech_session_service_test.dart` 신설 6건: 최상단 전달 / detach 후 승계 /
  재attach 시 최상단 승격(중복 없음) / 중간 detach / 무소유 시 무예외 /
  에러 이벤트 위임.
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 214/214 통과.

---

## 2026-08-21 — [P0-8] 백엔드 보안·견고성 (리뷰 후속 11단계 — 2주차 완료)

### 배경 (전면 리뷰에서 발견된 심각 결함)
1. **무인증 공개 프록시**: 모든 엔드포인트 무인증 + rate limit 없음 — URL만
   알면 누구나 Gemini 쿼터를 소진 가능(요금 폭탄 표면).
2. **무인증 프로필 덮어쓰기**: `/vision-mapping?save_as_id=`가 검증 없이
   `replace_one(upsert)` — 임의 이미지 한 장으로 기존 기기 프로필의
   시작↔취소 배치를 바꿔치기 가능(물리 안전 결함). 앱은 이 파라미터를 쓰지도 않음.
3. 이벤트 루프 블로킹(동기 generate_content), 업로드 크기 무제한, `*`+credentials
   CORS, 발화 원문 INFO 로깅(개인정보), deprecated on_event, vision이 명령
   파싱용 system_instruction이 박힌 모델을 재사용, 프롬프트 주입으로
   needs_confirmation 우회/임의 message 낭독 가능.

### 수정 내용 (backend/)
- **save_as_id 제거** — 필요 시 인증된 관리자 경로로 재도입(주석 명시).
- **API 키 인증**: `BACKEND_API_KEY` 설정 시 `/parse-command`·`/vision-mapping`·
  `/device-profile`에 `X-API-Key` 헤더 필수(미설정 = 로컬 개발 개방 모드).
- **레이트리밋**: 인메모리 슬라이딩 윈도우, IP당 분당 60회(비전 10회) → 429.
- **응답 스키마 검증** (`validation.py` 신설): action/target 화이트리스트,
  버튼 ID `BT-[A-Z]?\d{2}` 패턴 강제, 실행형 액션에 유효 버튼이 없으면 NONE
  강등, seconds 0~1200 클램프, confidence 0~1, needs_confirmation은 정확히
  true일 때만, message 제어문자 제거+200자 절단 — 프롬프트 주입의 마지막 방어선.
- 업로드 5MB 상한(413), `interpret`를 to_thread+30초 타임아웃으로(루프 블로킹
  해소), vision 전용 모델 분리(system_instruction 충돌 제거),
  `get_interpret_prompt("")`의 빈 꼬리 제거(MICROWAVE_SYSTEM_PROMPT 직접 사용),
  CORS credentials 해제, 발화 로그를 길이+20자 미리보기로 축소,
  on_event → lifespan, 오류 상세를 클라이언트에 노출하지 않도록 정리.
- `.env_ex`(루트/백엔드)에 `AI_BACKEND_API_KEY`/`BACKEND_API_KEY`/`MONGO_URI` 추가,
  README 환경 설정 절 갱신.

### 수정 내용 (앱 — `ai_backend_service.dart`)
- `X-API-Key` 헤더 전송(선택적, .env `AI_BACKEND_API_KEY`).
- 3중 복붙이던 재시도 블록을 `_postJsonWithRetry` 헬퍼로 통합.
- `fetchDeviceProfile`이 전역 `http.get`(타임아웃 없음) 대신 `_client`+15초
  타임아웃 사용 — 이 메서드만 무한정 대기 가능하던 문제 수정.

### 검증 한계
- 이 PC에는 Python이 없어 백엔드는 정적 구현만 검증됨. **백엔드 실행 환경에서
  `uvicorn main:app` 기동 + `/parse-command` 스모크 확인 필요.**

---

## 2026-08-21 — [정합성-1] 이중 탭 타임아웃 20초 통일 + 단일 상수화 (리뷰 후속 12단계 — 3주차 시작)

### 배경
- "이중 탭 타임아웃 20초 통일(WCAG 2.2.1)"이 README·심사 문서의 대외 주장이었지만
  실제 코드는 20초 4곳 + **15초 6곳** 혼재, 주석에는 "4초"까지 잔존 —
  심사위원이 코드로 반증 가능한 상태였다.

### 수정 내용
- `kDoubleTapArmTimeout`(20초) 상수를 `accessibility_settings.dart`에 신설하고
  arm 타이머 **10곳 전부**를 상수로 치환: primary/emergency 버튼,
  메인 내비 탭, 제어 3화면, control_mode_sheet, voice 마이크, stop_done 홈 버튼,
  manual_mapping. (TTS 안전 타임아웃 20초·NFC 15초·HTTP 15초는 별개 값으로 유지)
- "4초" 잔존 주석/문서 정리: manual_mapping·control_mode_sheet 주석,
  CLAUDE.md 이중 탭 절. REFERENCES.md "15초 통일" → 20초로 정정.
- 상수 드리프트 방지 회귀 테스트 1건 추가(값 변경 시 문서 동반 갱신 강제 신호).
- AGENTS.md의 4초 서술은 다음 단계(문서 정합성 패스)에서 파일 자체를 정리하며 처리.
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 215/215 통과.

---

## 2026-08-21 — [정합성-2] 문서 계보 복구·아카이빙 (리뷰 후속 13단계)

### HARDWARE_MIGRATION_PLAN.md 복구 (최우선 모순 해소)
- README가 "NK1704S+TB6600+GRBL 기준은 이 문서"라고 링크하는데, 실제 파일은
  전혀 다른 구버전(NEMA11+TMC2208)이었다 — git 히스토리 조사 결과 `0a1d1e0`
  커밋("초기 프로젝트 구조...")이 현행 문서를 구버전으로 **덮어쓴 사고**로 확인.
- `cf770f8` 시점의 현행 버전(NK1704S+TB6600+GRBL)을 복원하고, NEMA11 구버전은
  `docs/archive/HARDWARE_MIGRATION_PLAN_NEMA11_TMC2208_구버전.md`로 이동
  (아카이브 사유 헤더 포함).

### AGENTS.md 이중 관리 제거
- CLAUDE.md의 스테일 사본(3인 팀, 4초 타임아웃, 구 하드웨어 전략)이던 AGENTS.md를
  **CLAUDE.md 포인터 파일**로 교체 — 같은 내용을 두 곳에서 관리하다 어긋나는
  사고의 재발 방지.

### CLAUDE.md 허위/구식 서술 정정
- 하드웨어 절: 폐기된 키캡/SG90/CoreXY 3단계 → 현행 GRBL XYZ 갠트리로 교체
  (CoreXY 기각 사유·참조 문서 명시).
- 존재하지 않는 "스와이프 뒤로가기" 절 삭제, "5초 침묵" → 기본 8초·설정 5~15초,
  홈 화면 기기 목록 서술을 실제 구조(HomeDeviceStore/Map)로 교체,
  환경변수 절에 AI_BACKEND_API_KEY 추가.

### 스테일 문서 아카이빙 + 정리
- `docs/archive/` 신설: CLOUD_INTEGRATION_PLAN(실코드 MongoDB에 추월당함),
  MAPPING_VOICE_STABILIZATION_TODO, FEATURE_COMPLETION_INVENTORY,
  accessibility-improvements-2026-05-04 이동. `.ipynb_checkpoints` 삭제.
- AI_SYSTEM_OVERVIEW_KO(3장 스테일)·HARDWARE_TASKS(SG90/DRV8825 잔존)에
  최신화 주석 헤더 추가 — 전면 재작성 대신 어느 부분이 유효한지 명시.
- WORK_LOG 헤더 팀 구성을 README와 통일(박성원 · 서예솔).

---

## 2026-08-21 — [정합성-3] 심사 문서 병합·정비 (리뷰 후속 14단계)

### 배경
- 7월의 DOCS_MERGE_PROPOSAL이 한 달째 미실행 상태였고(발표 직결 자산 방치),
  REPRO_RUNBOOK은 6-1절 번호 깨짐·개인 맥북 호스트명 노출·포트 8001/8000 혼재·
  macOS 전용 명령만 존재하는 상태였다.

### REPRO_RUNBOOK 전면 정비
- 병합: 2-1 하드웨어 안전 체크리스트(전원 인가 전/후), 6) 합격 기준("화면 가리고
  완주"), 6-0-1 GRBL 오류/통신 신뢰성 검증, 6-3 스크린리더 병행 검증(+비상 결과
  가청 확인 항목), 8) 릴리스 전 회귀 세트(타임아웃 20초로 정정), 9) 결과 기록 양식.
- 수정: 6-1절 번호 깨짐(두 목록 병합 사고)을 6-1/6-1-1로 분리 복구, 개인 호스트명
  제거(일반화), 포트 8000 통일(백엔드 main.py 기본 포트도 8000으로 변경),
  Windows 실행 절차 병기, 셀 충돌 검출·병합 저장 검증 항목 추가.

### JUDGING_BRIEF 보강
- 실행 파이프라인 도식(2), 하드웨어 선택 이유 표(2-1), **예상 질문과 답변 6문항**
  (Q&A — 이번 리팩토링 내용 반영: 셀 충돌 차단, Z 복구, ACK 기반 정직 안내,
  서버 스키마 검증) 병합. 현재 구현 상태 표를 2026-08-21 기준으로 갱신
  (침묵 감지 8초 정정, 테스트 215개, 보안/기기 등록 행 신설).

### DEMO_SCRIPT 보강
- 시연 전 체크리스트, 시나리오 2 "화면 안 보고 수행" 연출, 시연 실패 대응표 5종,
  대안 마무리 멘트 병합.

### ACCESSIBILITY_COPY_GUIDE 보강
- 4.6 ALARM 상황 문구 + 비상 완료 문구를 ACK 분기형으로 정정(거짓 완료 단언 금지),
  4.8 테스트 터치 경고·셀 충돌 안내 문구, 5-1 기술 용어 금칙 표(BT-xx 포함),
  8장 Semantics/스크린리더 병행 규칙(구현 완료된 TTS 억제 계약 반영) 신설.

### 마무리
- DOCS_MERGE_PROPOSAL은 병합 완료 주석과 함께 `docs/archive/`로 이동.
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 215/215 통과.

---

## 2026-08-21 — [P1-마감] 잔여 버그 일괄 수정 (리뷰 후속 15단계 — 3주차 완료)

### 수정 목록 (전면 리뷰 잔여 P1)
1. **BleLoadingHelper 중복 실행**: `StatefulBuilder` builder 안에서 `onExecute`를
   호출해 진행률 setState마다 BLE 업로드가 재시작되던 결함 → `started` 플래그로
   최초 1회만 실행, 다이얼로그 닫힌 뒤 콜백 가드(`closed`) 추가.
2. **appliance_selection 취소/샘플 구분 불가**: 시트 dismiss와 '샘플 이미지'가
   모두 null이라 취소해도 샘플로 매핑 화면에 진입 → 반환 계약을
   `({path, useSample})?`로 변경(null=취소=진입 안 함), 피커 취소 시 안내 추가.
3. **VoiceTextMatcher contains 오탐**: "그런데 말이야"의 '네' 같은 오탐이 곧
   물리 버튼 누름이던 문제 → 긍정은 정확 일치+짧은 변형만(엄격), 부정은 포함
   매칭 유지(오탐 결과가 '취소'라 안전한 비대칭 정책). 첫 테스트 9건 신설.
4. **EmergencyIntent '일시정지' 충돌**: 세탁기 일시정지 요청이 '정지' 부분 매칭으로
   항상 비상 정지에 가로채이던 문제 → "일시정지" 표현 제거 후 토큰 검사
   (다른 중단 토큰 동반 시엔 여전히 비상 정지). 회귀 테스트 2건 추가.
5. **home_screen**: `_deleteTimer` dispose 누락(죽은 context 다이얼로그 위험) 수정,
   홈 안내를 최초 1회로 제한 + interrupt 제거 — 기기 목록 갱신마다 백그라운드
   홈이 현재 안내/온보딩 TTS를 지우던 레이스 해소. 온보딩 안내는 result
   우선순위로 승격(1회뿐인 핵심 안내, 홈 navigation 안내에 대체되지 않음).
6. **ble_log_screen 구독 누수**: logStream 구독을 저장/취소하지 않아 화면을
   여닫을 때마다 리스너가 누적되던 문제 수정 (+ScrollController dispose).
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 224/224 통과.

---

## 2026-08-22 — [기능 A-1] 전역 비상 정지 버튼

### 배경 (전면 리뷰 지적: 비상 정지 도달성)
- 비상 탭은 메인 내비게이션에만 있어, 이미지 제어·숫자 패드·간편 코스 같은
  push된 화면에서 기기를 멈추려면 "뒤로가기 → 비상 탭 이중 탭 → 비상 버튼
  이중 탭"의 다단계가 필요했다. 위험 상황에서 이 다단계는 시각장애인에게 치명적.

### 구현
- `EmergencyStopService` 신설 — 대상 결정(연결 기기 우선→활성 기기) → 재연결 →
  STOP 전송 → ACK 해석의 단일 창구. 3개 화면(비상 탭/카운트다운/음성)에 복제돼
  있던 동일 로직을 이 서비스로 통합(정지 경로는 안전 직결이라 사본 금지).
- `GlobalEmergencyAction` 위젯 신설 — `TopAppBar`에 기본 상주하는 빨간 비상
  버튼. 이중 탭 패턴(20초 arm, 백그라운드 전환 시 해제), 모든 발화 emergency
  우선순위, armed 상태 Semantics value/hint/liveRegion 병행 노출, 48dp 터치 타겟.
  ACK 확인 시에만 완료 화면 이동(거짓 완료 금지).
- `TopAppBar.showEmergency`(기본 true) — 비상 계열 3화면(비상 탭/카운트다운/완료)만
  중복 노출 방지를 위해 끔. **이제 어떤 화면에서든 상단 두 번 탭이면 즉시 중단.**

### 테스트 인프라 발견/개선
- testWidgets(FakeAsync) 환경에서 flutter_tts 플랫폼 채널 호출이 영원히 완료되지
  않아 speak()를 await하는 위젯 로직이 멈추는 문제 발견 →
  `TtsService.disableEngineForTest` 도입(큐 계약은 유지, 엔진 호출만 생략).
  이후 위젯 테스트에서 TTS 의존 화면을 테스트할 수 있는 기반.

### 테스트
- EmergencyStopService 2건(기기 없음 정직 실패 / 연결 실패 시 acknowledged=false),
  GlobalEmergencyAction 위젯 4건(기본 노출 / showEmergency:false 미노출 /
  첫 탭 arm만 / 둘째 탭 실행 후 미확인이면 완료 화면 미이동 + 버튼 잠김 해제).
- 검증: `flutter analyze` 신규 이슈 0건, `flutter test` 230/230 통과.
