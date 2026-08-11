# Touch Bridge 작업 로그

> 담당: 박성원 | AI 협업: Gemini CLI (Auto-Edit)
> 프로젝트: 2026 한이음 드림업 — 시각장애인용 가전 터치패드 자동 입력 시스템  
> 팀: 3팀 멜론머스크 (박성원 · 서예솔)
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

## 2026-07-19 — 하드웨어 개선 방향 문서화

### 결정 배경
- 기존 28BYJ-48 기반 구조는 실제 터치 압력과 반복 위치 정밀도에서 한계가 있어 모터/드라이버 상향을 검토했다.
- DC 기어모터는 토크는 강하지만 엔코더/PID 없이 X/Y/Z 좌표 제어가 어려워, 앱의 사진 매핑 좌표와 연결하기에는 복잡도가 높다고 판단했다.

### 신규 하드웨어 기준
- X축: NK1704S 42각 스텝모터 1개 + TB6600 1개
- Y축: NK1704S 42각 스텝모터 1개 + TB6600 1개
- Z축: NK1704S 42각 스텝모터 1개 + TB6600 1개
- 전원: 12V 배럴잭 별도 모터 전원, MCU 전원과 분리, 공통 GND 유지
- 모션 제어: Arduino Uno + GRBL 유지
- 통신: ESP32가 BLE 또는 향후 Wi-Fi 명령을 받아 Arduino Uno GRBL로 UART 전달

### 앱 영향 범위
- 기존 앱 구조는 유지하되, `BT-xx -> row/col -> BTN_n` 중심 실행을 `BT-xx -> X/Y mm 좌표 -> Z 누름 G-code 시퀀스`로 확장해야 한다.
- 매핑 프로필에 `travelHeightZ`, `pressDepthZ`, `travelFeed`, `pressFeed` 같은 Z축/속도 설정을 추가 검토한다.
- 개발자 콘솔은 `$H`, X/Y/Z jog, raw G-code, STOP, GRBL 응답 로그를 중심으로 정리한다.
- Wi-Fi 제어 API를 추가하더라도 BLE는 초기 설정/복구/근거리 시연 경로로 유지한다.

### 문서 변경
- `docs/HARDWARE_MIGRATION_PLAN.md`: NEMA11/TMC2208 계획을 NK1704S/TB6600/Arduino Uno GRBL 기준으로 전면 갱신.
- `docs/HARDWARE_TASKS.md`: XYZ 모터/드라이버, 전원, 리미트 스위치, GRBL 튜닝 체크리스트 반영.
- `docs/HW_APP_INTEGRATION_CONTRACT_KO.md`: BLE/Wi-Fi 채널, XYZ G-code 실행 계약, 레거시 명령 호환 정책 정리.
- `docs/AI_SYSTEM_OVERVIEW_KO.md`: AI 협업용 아키텍처를 ESP32 BLE/Wi-Fi 브릿지 + Arduino Uno GRBL + TB6600 x3 구조로 갱신.
- `docs/MAPPING_VOICE_STABILIZATION_TODO.md`: 앱 수정 TODO와 실기기 검증 항목 추가.

### 검증
- 문서 변경만 수행. 앱 코드/테스트는 실행하지 않음.

---

## 2026-07-19 — 접근성/발표 문서 병합 보강

### 배경
- Claude가 기존 문서와 초안 비교 후 `DOCS_MERGE_PROPOSAL_2026-07-19.md`를 작성했다.
- 기존 문서와 충돌하지 않는 보강안만 선별해 실제 docs 문서에 병합했다.

### 변경 내용
- `ACCESSIBILITY_REDESIGN_PLAN.md`
  - 하드웨어 전제와 접근성 책임 분리 추가.
  - 개발자 모드 기능에 `$H`, Z축 테스트 누름, GRBL 로그, dry-run G-code 로그 추가.
  - GRBL `ok/error/ALARM`을 사용자 언어로 번역하는 P6 항목 추가.
- `ACCESSIBILITY_COPY_GUIDE.md`
  - GRBL `ALARM` 수신 시 사용자 문구 추가.
  - 테스트 터치 전 안전 경고 문구 추가.
  - 사용자 모드 기술 용어 금칙표와 Semantics/스크린리더 병행 규칙 추가.
- `REPRO_RUNBOOK.md`
  - 12V/TB6600/NK1704S 실기기 전원 인가 전·후 안전 체크리스트 추가.
  - 화면을 가린 상태의 사용자 모드 합격 기준, GRBL 오류/통신 신뢰성 검증, VoiceOver/TalkBack 병행 검증, 릴리스 전 회귀 세트 추가.
  - 기존 중복/번호 꼬임이 있던 매핑 검증 절차를 순서대로 재정리.
- `JUDGING_BRIEF.md`
  - 실행 파이프라인, 하드웨어 선택 이유 표, 예상 Q&A 6개 추가.
- `DEMO_SCRIPT_3MIN.md`
  - 시연 전 체크리스트, 화면 안 보기 연출, 시연 실패 대응표 추가.

### 검증
- 문서 변경만 수행. 앱 코드/테스트는 실행하지 않음.

---

## 2026-07-19 — 사용자 모드 기본화 및 XYZ dry-run 실행 경로

### 변경 배경
- 시각장애인 사용자가 처음 앱을 열었을 때 기기 관리/매핑 같은 보호자 기능이 보이면 앱이 과도하게 복잡해질 수 있어, 기본값을 사용자 모드에 맞췄다.
- 하드웨어가 NK1704S/TB6600/GRBL 기반 XYZ 구조로 전환될 예정이므로, 실기기 도착 전에도 앱에서 `BT-xx -> X/Y/Z G-code` 변환을 로그로 검증할 수 있게 했다.

### 코드 변경
- `AccessibilitySettings`
  - `guardianModeEnabled` 기본값을 `false`로 변경.
  - 저장값이 없으면 사용자 모드(홈/비상/설정 중심)로 시작한다.
- `DeviceMappingProfile`
  - Z축/모션 설정 필드 추가:
    - `travelHeightZ`
    - `pressDepthZ`
    - `travelFeed`
    - `pressFeed`
    - `dwellSeconds`
  - JSON 저장/로드에 `motion` 섹션 추가. 기존 프로필은 기본값으로 자동 보정된다.
- `MappingExecutionService`
  - `calculateX`, `calculateY`, `buildPressGcode`, `sendGcodeSequence` 추가.
  - 버튼 실행을 `BT-xx -> row/col -> X/Y mm -> Z 누름 G-code` 흐름으로 확장.
  - `dryRun` 옵션 추가. 실제 BLE 전송 없이 생성된 G-code, row/col, X/Y 좌표를 결과와 로그로 확인 가능.
- `DeveloperConsoleScreen`
  - `$H` 홈 복귀, `STOP`, Z축 테스트 누름, `BT-xx` dry-run G-code 로그 버튼 추가.
  - 활성 기기의 저장 매핑을 읽어 dry-run 변환 결과를 개발자 로그에 표시한다.

### 테스트
- `dart format`: 통과
- `flutter analyze`: 통과
- `flutter test`: 통과 (31개)

### 실기기 확인 필요
- TB6600/NK1704S 도착 후 `$H`, X/Y/Z jog, Z 테스트 누름, dry-run과 실제 raw G-code 전송 일치 여부 확인.
- GRBL `ok/error/ALARM` 응답을 앱에서 사용자 문구로 번역하는 후속 작업 필요.

---

## 2026-07-19 — 개발자 콘솔 반응형 보강

### 변경 내용
- `JogControlPanel`
  - 작은 폭(`<390px`)에서는 이동 단위/속도 설정이 세로로 접히도록 변경.
  - X/Y/Z 조그 버튼 크기, 아이콘 크기, 축 간격을 화면 폭에 맞춰 축소.
  - 버튼 크기를 명시해 hover/label 변화로 레이아웃이 흔들리지 않게 조정.
- `DeveloperConsoleScreen`
  - 작은 높이(`<700px`)에서는 raw 명령 입력창의 하단 여백을 줄여 320x640 화면에서도 세로 오버플로우가 나지 않도록 수정.

### 테스트
- `test/screens/developer_console_screen_test.dart` 추가.
  - 320x640 작은 화면에서 `$H`, `STOP`, `Z 테스트`, `dry-run`, 이동 단위 컨트롤이 렌더링되는지 확인.
- `flutter analyze`: 통과
- `flutter test`: 통과 (32개)
