# Touch Bridge CoreXY 펌웨어 v4

**상태: 이 폴더의 v4 코드와 CT 수신 코드는 실제 하드웨어에서 실행한 적 없다.**

ESP32 + JMOD-MOTOR-1(TB6612FNG) + DFRobot FIT0482 x2, 엔코더 폐루프 CoreXY.
누름부는 SwitchBot Bot이며 ESP32가 BLE로 직접 제어한다(허브 불필요, `SwitchBotBLE.h`).

## SwitchBot Bot 설정

1. `config_local.h.example`을 `config_local.h`로 복사하고 `SWITCHBOT_MAC`에 Bot 주소를
   소문자로 넣는다. 이 파일은 gitignore 대상이며, 없으면 컴파일이 `#error`로 멈춘다.
   주소는 SwitchBot 앱의 기기 정보나 BLE 스캐너 앱으로 확인한다.
2. SwitchBot 앱에서 Bot을 **누름(Press) 모드**로 둔다. 스위치 모드면 `BOT_UNSUPPORTED`가 날 수 있다.
3. Bot **비밀번호를 해제**한다. 켜져 있으면 `BOT_ENCRYPTED`로 실패한다(암호화 명령은 미지원).
4. 누름 시간은 Bot 앱 설정을 따른다. 스마트폰 앱이 Bot에 붙어 있으면 ESP32가 연결하지 못한다.

한 번의 누름은 연결·쓰기·응답 대기를 합쳐 최대 8초(`BOT_PRESS_TIMEOUT_MS`)다.
실패하면 JSON 경로는 `ERROR_TIMEOUT`/`ERROR_PROTOCOL`, G-code 경로는 `FAULT <사유>`를 보내고
남은 큐를 버린다.

**정지의 의미:** `STOPPED`는 모터가 멈췄고 큐를 버렸다는 뜻이다. 정지는 아직 쓰지 않은 Bot
누름을 취소하지만, 이미 쓴 누름은 되돌릴 수 없다.

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

## CT 노드 수신 (기본 꺼짐)

`config.h`의 `CT_LINK_ENABLED`가 0이면 UART를 열지 않으며 기존 빌드와 동작이 같다. 배선한 뒤에만 1로 바꾼다.
결선과 활선 안전 경고는 [`hardware/touchbridge_ct/README.md`](../touchbridge_ct/README.md)를 따른다.

- `Serial2` 기본 핀 16/17은 이 보드의 **엔코더 입력**이다. 그래서 RX를 **GPIO21**, TX를 **GPIO22**로 옮겼다.
- 작동 판정은 `CT_ON_WATTS`(100 W) 이상이 5초 이어지면 작동, `CT_OFF_WATTS`(15 W) 이하가 3초 이어지면 종료다. 2026-11-02 전자레인지 1분 가열 측정(별도 ESP32 장치)에서 쓴 기준이며, 가전마다 다시 잴 수 있다. 보고의 `w`는 5초 이동 평균이다.
- 보고가 3초 넘게 끊기면 `unknown`이고 `w`는 `null`이다. 0W로 보지 않는다.
- 전력 값은 표시 전용이다. 정지·누름 허용·완료 판정에 쓰지 않는다.

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

앱 연동은 스케치에 구현되어 있다. 명령 3종은 `touchbridge_corexy.ino` 머리말, 앱 JSON 계약은
[`docs/ESP32_MOTION_PROTOCOL_V2.md`](../../docs/ESP32_MOTION_PROTOCOL_V2.md)를 따른다.
