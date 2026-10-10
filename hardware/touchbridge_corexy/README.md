# Touch Bridge CoreXY 모션 펌웨어

ESP32 + JMOD-MOTOR-1(TB6612FNG) + DFRobot FIT0482 x2, 엔코더 폐루프 CoreXY.

## 배선

| JMOD-MOTOR-1 | ESP32 |
|---|---|
| PWMA / AIN1 / AIN2 | 25 / 26 / 27 |
| PWMB / BIN1 / BIN2 | 32 / 33 / 13 |
| STBY | 4 |
| VCC(로직) | 3.3V |
| VM(모터 전원) | 6V 전원 (4.5~13.5V 허용, 모터 정격이 6V) |
| GND | GND (모터 전원 GND와 공통) |

| FIT0482 6핀 | 연결 |
|---|---|
| M+ / M- | 드라이버 AO1/AO2 (B모터는 BO1/BO2) |
| 엔코더 VCC / GND | 3.3V / GND |
| 엔코더 A / B | 모터A: 16 / 17, 모터B: 18 / 19 |

- 엔코더를 5V로 구동하면 출력이 5V가 될 수 있으니 3.3V로 먹이거나 레벨 변환을 하세요.
- 모터 A = 왼쪽, B = 오른쪽. 원점은 좌하단(X-, Y- 방향 벽).

## 처음 켤 때 순서 (벨트 걸기 전 권장)

1. `M 0.3 0 500` → 모터 A가 돌고 `P`에서 enc 첫 값이 **증가**해야 함. 감소하면 `ENC_A_INVERT` 토글.
2. `M 0 0.3 500` → 모터 B도 같은 방식으로 확인 (`ENC_B_INVERT`).
3. 벨트를 건 뒤 `M 0.3 0.3 300` → 캐리지가 **+X(오른쪽)**로 가야 함. `M 0.3 -0.3 300` → **+Y**.
   - 반대로 가면 `MOTOR_x_INVERT`와 `ENC_x_INVERT`를 **같이** 토글 (모터만 바꾸면 양의 피드백으로 폭주).
   - X와 Y가 뒤바뀌면 A/B 모터 배선을 서로 바꿈.
4. `Z`(현재 위치를 원점으로) → `G 20 0` → `G 20 20` → `G 0 0` 으로 작은 이동 확인.
5. 진동하면 `K`로 kp를 낮추고, 도착이 느리거나 FAULT SETTLE이 나면 ki를 올림.
   예: `K 0.015 0.05 0.00005 0.00012`
6. 기구가 안정되면 `H`로 원점 복귀(스톨 감지) 사용. 리밋 스위치를 달면 `USE_LIMIT_SWITCHES = true`.

## 꼭 맞춰야 할 값 (config.h)

- `PULLEY_TEETH`, `BELT_PITCH_MM` : 실제 풀리 (기본 GT2 20T = 40mm/회전)
- `X_MAX_MM`, `Y_MAX_MM` : 실제 이동 범위
- `MOTOR_x_INVERT`, `ENC_x_INVERT` : 위 시험 결과

## BLE 연동

GATT 쓰기 콜백에서 `motion.moveTo(x, y)`, `motion.home()`, `motion.stop()`을 호출하고,
`handleEvent()`에서 `MOVE_DONE → CONFIRMED`, `STOPPED → STOPPED ACK`, `FAULT_* → FAILED`로 notify 하면
앱의 RECEIVED→SENT→CONFIRMED/FAILED 흐름과 맞습니다. 누름 장치는 `MOVE_DONE` 자리에 붙이면 됩니다.
