# Touch Bridge 앱-하드웨어 연동 계약서 (실무 기준)

## 1) 목적
앱(STT/AI)과 하드웨어(ESP32/AVR) 간 명령 포맷을 고정해, 기기별 매핑(2x2/3x3 등)이 바뀌어도 코드가 깨지지 않게 한다.

2026-07-19 기준 하드웨어 방향은 `Arduino Uno + GRBL`을 유지하고, 모터/드라이버를 `NK1704S 42각 스텝모터 3개 + TB6600 3개`로 강화하는 것이다. ESP32는 앱과 Arduino Uno 사이의 통신 브릿지 역할을 담당한다.

## 2) 통신 채널

### 2-1. 기본/현재 채널: BLE
- 기존 Flutter 앱의 `BleService` 경로를 유지한다.
- 개발자 콘솔, raw 명령, 조이스틱, 비상 정지는 BLE raw text 전송으로 우선 검증한다.

### 2-2. 추가 검토 채널: Wi-Fi
- 가정용 고정 장치 특성을 고려해 ESP32에 HTTP/WebSocket 제어 API를 추가할 수 있다.
- Wi-Fi는 상태 모니터링, 로그 수집, 보호자 기능 확장에 유리하다.
- Wi-Fi only는 공유기/비밀번호 문제에 취약하므로 BLE는 초기 설정/복구/근거리 시연 경로로 유지한다.

### 2-3. UUID (BLE 고정값)
- Service: `0000FFE0-0000-1000-8000-00805F9B34FB`
- Characteristic: `0000FFE1-0000-1000-8000-00805F9B34FB`

## 3) 고정 명령어 규격 (앱 -> ESP32 -> Arduino Uno GRBL)

### 3-1. 권장 실행 경로: XYZ G-code
하드웨어가 NEMA17급 XYZ 구조로 바뀌면 앱은 논리 버튼 ID를 X/Y/Z G-code 시퀀스로 변환한다.

```gcode
G90
G21
G0 Z5 F600
G0 X120 Y80 F1200
G1 Z-2 F200
G4 P0.2
G0 Z5 F600
```

- `G90`: 절대 좌표
- `G21`: mm 단위
- `G0 Z<travelHeightZ>`: 안전 높이로 복귀
- `G0 X<x> Y<y>`: 버튼 위치로 이동
- `G1 Z<pressDepthZ>`: 터치 깊이까지 누름
- `G4 P<seconds>`: 짧은 유지 시간
- `STOP` 또는 GRBL 즉시 정지 명령: 긴급 중단

### 3-2. 레거시/호환 명령
기존 앱과 펌웨어 테스트를 위해 아래 명령은 당분간 유지한다.

- `BTN_n`: n번째 버튼을 터치 (1부터 시작)
  - 계산 공식: `(y * cols) + x + 1`
- `SET_GRID <rows> <cols> <ox10> <oy10> <px10> <py10>`
  - `ox10, oy10, px10, py10`: 실제 mm 단위에 10을 곱한 정수값
- `PRESS <x> <y>`: 0-index 기반 좌표 터치
- `STOP`: 긴급 중단

### 3-3. BLE JSON 액션 (레거시/보안 제어용)
- `{"action": "stop", "deviceId": "..."}`
- `{"action": "set_grid", ...}` (단, 현재는 텍스트 명령 권장)

## 4) 유의사항
1. 그리드는 가변적이다 (rows/cols). 앱은 논리 버튼 ID(`BT-xx`)를 현재 기기의 매핑 프로필 기준으로 해석한다.
2. 신규 XYZ 구조에서는 `SET_GRID`만으로 충분하지 않다. `originX`, `originY`, `pitchX`, `pitchY`, `travelHeightZ`, `pressDepthZ`, `travelFeed`, `pressFeed`를 함께 관리한다.
3. 하드웨어는 명령 수신 후 GRBL `ok`, `error`, `ALARM` 또는 터치 완료 응답을 보내야 하며, 앱은 이를 로그로 기록한다.
4. 앱-하드웨어 간 타임아웃 방지를 위해 명령 사이 500ms~800ms의 딜레이를 권장한다.
5. 개발자/수동 조이스틱 이동은 `$J` 또는 `G91` -> `G1 <axis><value> F<feed>` -> `G90` 중 펌웨어에서 더 안정적인 경로 하나로 통일한다.
6. Z축은 힘이 강해지므로 앱 비상정지, 하드웨어 E-STOP, 리미트 스위치를 모두 유지한다.

## 5) 기기별 가변 매핑 및 연결 정책
- **저장 구조 권장**:
  - `deviceId` (가전기기 고유 ID)
  - `bleId` (해당 가전에 할당된 ESP32 하드웨어 ID/Mac)
  - `bleName` (사용자 확인용 블루투스 이름)
  - `wifiHost` 또는 `deviceIp` (Wi-Fi 제어 API 추가 시)
  - `grid.rows`, `grid.cols`
  - `grid.originX`, `grid.originY`
  - `grid.pitchX`, `grid.pitchY`
  - `motion.travelHeightZ`, `motion.pressDepthZ`
  - `motion.travelFeed`, `motion.pressFeed`
  - `buttonMap` (`BT-01` -> `{x,y}`)

- **실행 순서 및 자동 연결 정책**:
  1. **기기 등록**: BLE 또는 Wi-Fi 프로비저닝 성공 시 해당 가전의 하드웨어 ID를 저장.
  2. **기기 선택**: 홈 화면에서 가전 선택 시 저장된 연결 정보를 사용해 ESP32 연결 시도.
  3. **좌표 계산**: 명령 시퀀스(`BT-xx`)를 현재 기기의 `buttonMap`, origin/pitch, motion 설정에 맞춰 X/Y/Z G-code로 변환.
  4. **실행**: ESP32가 raw G-code를 Arduino Uno GRBL로 UART 전달.
  5. **Fallback**: 기기별 저장 매핑이 없을 때만 `docs/MOCK_MAPPING_DATA.md`의 검증된 데모 물리 좌표를 사용한다.

## 6) 테스트 체크리스트
1. BLE 미연결 상태: 음성 명령 -> 로그 생성 확인(파이프라인 점검)
2. BLE 연결 상태: raw G-code 전송, ESP32 UART 전달, Arduino Uno GRBL 응답(`ok/error/ALARM`) 확인
3. Wi-Fi API 추가 시: 동일 명령이 BLE와 같은 실행 큐/비상정지 우선순위를 사용하는지 확인
4. 그리드 변경: 3x3/2x2 모두 인덱스 범위 에러 없이 X/Y 좌표가 계산되는지 확인
5. Z축: `travelHeightZ` -> `pressDepthZ` -> 복귀 시퀀스가 과압 없이 동작하는지 확인
