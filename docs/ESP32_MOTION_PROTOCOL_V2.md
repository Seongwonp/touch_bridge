# Touch Bridge ESP32 모션 프로토콜 v2

> 상태: 앱 측 계약 확정, **ESP32 펌웨어 v4 구현 완료**(`hardware/touchbridge_corexy/`),
> 실기 검증 전. 아래 원칙 중 v4에서 아직 구현되지 않은 항목은 그 자리에 표시했다.
> 적용 대상: FIT0482 엔코더 DC 모터 X/Y (CoreXY) + SwitchBot Bot 누름 액추에이터
> (v3의 솔레노이드를 대체했다)

## 안전 원칙

1. 앱은 PWM이나 엔코더 카운트를 직접 제어하지 않고 mm 단위 목표만 보낸다.
2. ESP32는 부팅·연결 끊김·비상정지·스톨·리미트 오류 뒤 `homed=false`로 전환한다.
3. `homed=false`에서는 `move_only`와 `press`를 거부한다.
4. `POSITIONED`는 실제 엔코더 오차가 `toleranceMm` 이하일 때만 보낸다.
5. `POSITIONED` 응답의 `positionToken`은 한 번만 사용할 수 있으며, 이동·홈·정지·연결 끊김 시 즉시 폐기한다.
6. `press`는 유효한 `positionToken`이 없으면 절대로 누름부를 작동시키지 않는다.
   (v4: 토큰 발급 뒤 위치가 `toleranceMm` 이상 밀렸으면 토큰이 있어도 거부한다.)
7. 같은 `commandId` 재전송은 물리 동작을 반복하지 않고 저장된 현재/최종 상태만 다시 보낸다.
   > ⚠️ **펌웨어 v4 미구현.** v4는 `commandId`를 되돌려 줄 뿐 결과를 저장하지 않는다.
   > 같은 명령이 다시 오면 `press`는 1회용 토큰이 이미 소모돼 `ERROR_INVALID_TOKEN`으로
   > **누름 반복은 막히지만**, `move_only`는 다시 이동하고 `home`은 원점 복귀를 다시 한다.
   > 현재 앱은 명령마다 새 `commandId`를 만들고 재전송하지 않으므로(`motion_controller.dart`)
   > 지금은 영향이 없다. **앱에 같은 ID 재전송을 넣기 전에 펌웨어에 먼저 구현할 것.**
8. 비상정지는 일반 명령 큐와 인증 대기보다 우선하며 모터 PWM을 즉시 0으로 만든다.

## 공통 명령 필드

### 앱 측 취소·연결 수명 계약 (2026-09-05)

- 모션 컨트롤러는 명령 사이의 대기 시간에도 연결 끊김을 감시한다. 원점
  확인은 해당 기기에만 유효하며 재연결 후 자동 복원하지 않는다.
- 정지 요청 시 안전 세대(`safetyEpoch`)를 바꾸고 진행 중 응답 대기와 이전
  세대의 대기 작업을 취소한다. 지연된 `COMPLETED`가 원점을 복원하거나
  후속 누름을 실행하지 못하도록 누름 전·후에도 세대를 확인한다.
- 공통 비상 버튼의 BLE 정지 요청도 동일한 취소 이벤트를 발행한다. v2
  인증/전송 큐에서 기다리던 명령은 정지·연결 변경 후 실제 write 전에 폐기한다.
- 로컬 타임아웃/잘못된 상태 순서는 정지 확인이 아니다. 별도 정지를
  best-effort로 요청하고, 사용자에게 응답·실제 멈춤을 확인하지 못했다고 안내한다.
- 화면 종료 시 컨트롤러의 연결/정지 구독을 해제한다. 이 앱 측 취소는
  이미 BLE로 전달된 물리 동작의 정지를 보증하지 않는다. 펌웨어 STOP,
  위치 토큰 폐기 및 물리 안전장치는 위 안전 원칙대로 별도 구현·검증해야 한다.

```json
{
  "version": 2,
  "commandId": "cmd-unique-id",
  "action": "home | move_only | press | stop | status",
  "deviceId": "microwave-1"
}
```

- `version`: 정수 `2` 고정
- `commandId`: 기기 세션에서 고유한 문자열. 완료 결과는 최소 5분간 캐시한다.
- `deviceId`: 앱에 저장된 장치 식별자
- 알 수 없는 필드가 있어도 무시할 수 있지만 필수 필드 누락은 `ERROR_PROTOCOL`이다.

## 명령

### 원점 설정

```json
{"version":2,"commandId":"home-1","action":"home","deviceId":"microwave-1"}
```

정상 상태 순서: `RECEIVED -> HOMING -> HOMED -> COMPLETED`

### 위치 이동

```json
{
  "version": 2,
  "commandId": "move-1",
  "action": "move_only",
  "deviceId": "microwave-1",
  "target": {"xMm": 42.5, "yMm": 18.25},
  "toleranceMm": 0.7
}
```

정상 상태 순서: `RECEIVED -> MOVING -> POSITIONED -> COMPLETED`

`target`은 유한한 0 이상의 mm 값이어야 하고 펌웨어 작업영역 안에 있어야 한다.
`toleranceMm`은 0보다 큰 유한값이어야 한다. 공모전 기본값은 `0.7mm`이다.

### 누름

```json
{
  "version": 2,
  "commandId": "press-1",
  "action": "press",
  "deviceId": "microwave-1",
  "pressActuator": "switchbot",
  "positionToken": "opaque-single-use-token"
}
```

정상 상태 순서: `RECEIVED -> PRESSING -> COMPLETED`

펌웨어 v4는 ESP32가 **SwitchBot Bot에 BLE central로 직접 연결해** 누름 명령을 쓴다(허브 불필요).
앱은 `"pressActuator": "switchbot"`을 보내지만 v4는 이 필드를 읽지 않고 항상 Bot으로 누른다.
연결·쓰기·응답 대기의 상한은 펌웨어 8초(`BOT_PRESS_TIMEOUT_MS`)이고, 앱의 누름 타임아웃
12초는 이보다 길어야 한다.
누름 장치가 다시 바뀌어도 앱의 `PressActuator` 인터페이스는 유지하되, 위치 토큰 검증과
단일 사용 규칙은 누름 직전의 로컬 안전 계층(펌웨어)에서 지켜야 한다 — v4는 이 규칙을
펌웨어 안에서 지킨다.

### 비상정지

```json
{"version":2,"commandId":"stop-1","action":"stop","deviceId":"microwave-1"}
```

`STOPPED` 또는 오류를 1초 안에 응답한다. 진행 중 명령은 `STOPPED`로 끝내고,
모터 출력을 끄고 대기 큐를 버리며, 아직 쓰지 않은 Bot 누름을 취소하고 원점 및 모든 위치
토큰을 폐기한다. `STOPPED`는 모터가 멈췄고 대기 큐를 버렸다는 뜻이다. 이미 Bot에 쓴 누름은 취소되지 않는다
(Bot이 그대로 실행한다).

## 상태 응답

```json
{
  "version": 2,
  "commandId": "move-1",
  "state": "POSITIONED",
  "homed": true,
  "target": {"xMm": 42.5, "yMm": 18.25},
  "position": {"xMm": 42.4, "yMm": 18.2},
  "errorMm": 0.12,
  "positionToken": "opaque-single-use-token",
  "message": "optional developer detail"
}
```

앱은 `version=2`, 동일한 `commandId`, 정의된 상태 전이 순서를 모두 확인한다.
`move_only`는 `POSITIONED`의 `errorMm`과 `positionToken`이 모두 유효하고 뒤이어
`COMPLETED`가 와야 성공이다. 무관한 알림이나 다른 명령의 상태는 무시한다.

## 전력 이벤트 (선택, 실기기 미검증)

`CT_LINK_ENABLED`를 켠 펌웨어는 명령과 무관하게 1초마다 아래 줄을 notify로 보낸다.
기본값은 꺼짐이고 실제 하드웨어에서 확인한 적 없다.

```json
{"event":"power","w":812.5,"state":"on"}
{"event":"power","w":null,"state":"unknown"}
```

| 필드 | 의미 |
|---|---|
| `w` | 5초 이동 평균 전력 추정값[W]. `state`가 `unknown`이면 `null`이며 0으로 대신하지 않는다 |
| `state` | `on`, `off`, `unknown`. CT 보고가 3초 넘게 끊기면 `unknown` |

`commandId`가 없는 정보성 줄이므로 명령 응답이 아니다. 앱은 응답 대기와 v2 상태 추적에서 제외하고,
5초 동안 받지 못하면 `unknown`으로 본다. 켜짐 문턱값 `CT_ON_WATTS`는 측정하지 않은 자리표시자다.
전력 값은 안전 판단이나 동작 완료 판정에 쓰지 않는다.

## 오류 상태

| 상태 | 의미 | 앱/펌웨어 조치 |
|---|---|---|
| `ERROR_NOT_HOMED` | 홈 미완료 | 이동·누름 금지, 홈 요구 |
| `ERROR_POSITION` | 허용 오차 내 정착 실패 | 누름 금지 |
| `ERROR_STALL` | 엔코더 변화 없이 출력 지속 | PWM 0, 홈 폐기 |
| `ERROR_LIMIT` | 작업영역(`X_MAX_MM`/`Y_MAX_MM`) 밖 목표, 또는 예상하지 않은 리미트 입력(리밋 스위치 사용 시) | PWM 0, 홈 폐기 |
| `ERROR_PRESS` | 누름 실행 또는 확인 실패 | 재누름 자동 실행 금지. **v4는 보내지 않는다** — Bot 실패는 `ERROR_TIMEOUT`(연결·응답 실패) 또는 `ERROR_PROTOCOL`(Bot 상태 오류)에 `message`를 실어 보낸다. Bot의 OK는 명령 수락이며 패널 눌림 감지가 아니다 |
| `ERROR_TIMEOUT` | 명령 제한시간 초과 | PWM 0, 상태 조회 전 재실행 금지 |
| `ERROR_INVALID_TOKEN` | 없거나 만료·사용된 위치 토큰 | 누름 금지 |
| `ERROR_PROTOCOL` | 버전·필드·상태 순서 오류 | 물리 동작 금지 |

## PID·펌웨어 통과 조건

- X/Y 각각 목표 카운트는 캘리브레이션된 `countsPerMm`로 계산한다.
- 제어 주기, PID 게인, 최소/최대 PWM, 가감속 제한은 펌웨어 설정이며 앱 명령으로 임의 변경하지 않는다.
- `POSITIONED`는 두 축이 허용 오차 안에서 연속 안정 시간 이상 유지된 뒤 발행한다.
- 스톨은 일정 PWM 이상인데 엔코더 변화가 임계값 미만인 상태가 지정 시간 지속될 때 검출한다.
- 버튼별 30회 반복 측정에서 95% 이상 중심 `±0.7mm`, 오동작 0회를 실기 통과 기준으로 한다.
