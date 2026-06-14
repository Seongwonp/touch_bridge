# 앱-하드웨어 연동 규약 (Touch Bridge)

## 1) 데이터 흐름
1. 앱(STT/AI)에서 명령 생성
2. 앱이 BLE JSON을 ESP32로 전송
3. ESP32가 UART 명령으로 변환
4. AVR/GRBL이 터치 동작 수행
5. AVR 응답을 ESP32/앱 로그로 확인

## 2) 고정값 (변경 금지)

### BLE UUID
- Service: `0000FFE0-0000-1000-8000-00805F9B34FB`
- Characteristic: `0000FFE1-0000-1000-8000-00805F9B34FB`

### BLE JSON action enum
- `press`
- `stop`

### UART 명령 형식
- `BTN_<n>` (1-index)
- `BT-<n>` (앱 버튼 ID 호환)
- `PRESS <x> <y>` (0-index 좌표)
- `SET_GRID <rows> <cols> <ox10> <oy10> <px10> <py10>`
- `SET_SERVO <up_angle> <down_angle> <press_ms>`
- `GET_SERVO`

## 3) 가변 그리드 정책 (중요)
- 앱 매핑은 기기별로 다를 수 있음 (2x2, 3x3, 향후 확장)
- 각 기기별로 아래를 저장:
  - `rows`, `cols`
  - `originX`, `originY`
  - `pitchX`, `pitchY`
  - `buttonMap` (`BT-01` -> `{x,y}`)
- 기기 제어 시작 시 반드시 `SET_GRID`를 먼저 전송

## 4) 주의사항
1. 3x3 고정 전제 금지
2. 좌표는 `(x,y)` 0-index 기준 고정
3. AI `commands`는 논리 시퀀스이므로 하드웨어 좌표와 분리
4. 응답 처리 분리:
   - 성공: `ok`, `TOUCH_OK:...`
   - 실패: `error:...`, `ERROR:...`

## 5) 빠른 점검
1. `SET_GRID 3 3 0 0 200 200`
2. `BT-05` 또는 `BTN_5`
3. `PRESS 1 0`
4. 2x2 테스트: `SET_GRID 2 2 0 0 250 250` 후 범위 에러 확인
5. SG90 파라미터 테스트: `SET_SERVO 60 110 300`
6. SG90 설정 조회: `GET_SERVO` -> `SERVO_CFG U60 D110 P300`

## 6) UNO 핀맵 기준 (Stage 2 반영)

### Step/Dir
- X_STEP: D2
- Y_STEP: D3
- Z_STEP: D4 (현재 SG90 구성에서 기본 미사용)
- X_DIR: D5
- Y_DIR: D6
- Z_DIR: D7 (현재 SG90 구성에서 기본 미사용)
- STEPPER_ENABLE: D8

### Limit / Control / Probe
- X_LIMIT: D9
- Y_LIMIT: D10
- Z_LIMIT: D11 (또는 VARIABLE_SPINDLE 시 D12)
- RESET: A0
- FEED_HOLD: A1
- CYCLE_START: A2
- PROBE: A5

### SG90 (Stage 3 기본값)
- Servo signal pin: A4(PC4)
- 기본 각도:
  - `up_angle = 60`
  - `down_angle = 110`
- 기본 누름 유지 시간:
  - `press_ms = 300`

### SET_SERVO 유효 범위
- `up_angle`: 0..180
- `down_angle`: 0..180
- `press_ms`: 50..3000
- `up_angle != down_angle` 필수
