# Touch Bridge 앱-하드웨어 연동 계약서 (실무 기준)

## 1) 목적
앱(STT/AI)과 하드웨어(ESP32/AVR) 간 명령 포맷을 고정해, 기기별 매핑(2x2/3x3 등)이 바뀌어도 코드가 깨지지 않게 한다.

## 2) 고정 명령어 규격 (앱 -> 하드웨어)

### 2-1. 텍스트 기반 직접 명령 (UART 투과 전송)
하드웨어(GRBL 커스텀 펌웨어)의 부하를 줄이기 위해 앱에서 계산된 인덱스를 직접 전송한다.

- `BTN_n` : n번째 버튼을 터치 (1부터 시작).
  - 계산 공식: `(y * cols) + x + 1`
- `SET_GRID <rows> <cols> <ox10> <oy10> <px10> <py10>`
  - `ox10, oy10, px10, py10`: 실제 mm 단위에 10을 곱한 정수값 (소수점 제거용).
- `STOP` : 긴급 중단 및 원점 복귀.

### 2-2. BLE JSON 액션 (레거시/보안 제어용)
- `{"action": "stop", "deviceId": "..."}`
- `{"action": "set_grid", ...}` (단, 현재는 텍스트 명령 권장)

### 2-3. UUID (고정값)
- Service: `0000FFE0-0000-1000-8000-00805F9B34FB`
- Characteristic: `0000FFE1-0000-1000-8000-00805F9B34FB`

## 3) 유의사항
1. 그리드는 가변적이다 (rows/cols). 실행 전 반드시 `SET_GRID`를 전송하여 하드웨어 상태를 동기화한다.
2. 하드웨어는 명령 수신 후 `ok` 또는 `TOUCH_OK` 응답을 보내야 하며, 앱은 이를 로그로 기록한다.
3. 앱-하드웨어 간 타임아웃 방지를 위해 명령 사이 500ms~800ms의 딜레이를 권장한다.

## 4) 기기별 가변 매핑 정책
- 저장 구조 권장:
  - `deviceId`
  - `grid.rows`, `grid.cols`
  - `grid.originX`, `grid.originY`
  - `grid.pitchX`, `grid.pitchY`
  - `buttonMap` (`BT-01` -> `{x,y}`)

- 실행 순서 권장:
  1. 기기 선택
  2. 해당 기기 `SET_GRID` 전송
  3. 명령 시퀀스(`BT-xx`)를 현재 기기 `buttonMap`으로 좌표 변환
  4. `press` 전송 반복

## 5) 테스트 체크리스트
1. BLE 미연결 상태: 음성 명령 -> 로그 생성 확인(파이프라인 점검)
2. BLE 연결 상태: `press` JSON 전송, ESP32 UART 변환(`PRESS x y`), AVR 응답(`ok/TOUCH_OK`) 확인
3. 그리드 변경: 3x3/2x2 모두 인덱스 범위 에러 없이 동작 확인
