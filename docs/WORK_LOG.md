# Touch Bridge 작업 로그

> 담당: 박성원 | AI 협업: Gemini CLI (Auto-Edit)
> 프로젝트: 2026 한이음 드림업 — 시각장애인용 가전 터치패드 자동 입력 시스템  
> 팀: 3팀 멜론머스크 (차아미 · 박성원 · 서예솔)  
> 기간: 2026.03 ~ 2026.10

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
