# Touch Bridge 앱-하드웨어 연동 계약서 (실무 기준)

## 1) 목적
앱(STT/AI)과 하드웨어(ESP32/AVR) 간 명령 포맷을 고정해, 기기별 매핑(2x2/3x3 등)이 바뀌어도 코드가 깨지지 않게 한다.

## 2) 고정 enum/상수

### 2-1. BLE JSON action (앱 -> ESP32)
- `press`
- `stop`

### 2-2. UART 명령 prefix (ESP32 -> AVR)
- `BTN_<n>` : 1-index 버튼 번호
- `BT-<n>` : 앱 호환 버튼 번호
- `PRESS <x> <y>` : 0-index 좌표
- `SET_GRID <rows> <cols> <ox10> <oy10> <px10> <py10>`

### 2-3. UUID (고정값)
- Service: `0000FFE0-0000-1000-8000-00805F9B34FB`
- Characteristic: `0000FFE1-0000-1000-8000-00805F9B34FB`

## 3) 유의사항
1. AI 결과 `commands`는 버튼 ID 시퀀스이므로 ESP32/AVR 전달 전 변환 규칙을 고정한다.
2. 그리드는 고정 3x3이 아니다. 기기별 `rows/cols/origin/pitch`를 저장하고 실행 전 `SET_GRID`를 먼저 전송한다.
3. 좌표는 0-index `(0,0) ~ (cols-1, rows-1)`를 사용한다.
4. 응답 처리:
   - 성공: `ok` + `TOUCH_OK:...`
   - 실패: `error:3` + `ERROR:...`
5. `BT-05` 같은 논리 버튼은 기기별 기능 매핑으로 덮어쓸 수 있어야 한다.

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
