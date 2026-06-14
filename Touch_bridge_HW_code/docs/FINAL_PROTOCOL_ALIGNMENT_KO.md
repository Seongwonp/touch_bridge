# 최종 앱-하드웨어 통신 정렬 (Protocol Alignment)

> **날짜:** 2026-05-20  
> **상태:** 앱 측 구현 완료 (BleService v2.0)

## 1. 통신 핵심 메커니즘: ACK 기반 신뢰성 확보
- **기존:** 앱에서 명령(Write)만 하고 끝남. 하드웨어가 받았는지 알 수 없음.
- **변경:** 앱이 명령을 보낸 후, 하드웨어의 `Notify` 응답(ACK)을 최대 5초간 대기함.
  - 하드웨어는 명령 처리 성공 시 `ok` 또는 `TOUCH_OK`를 포함한 문자열을 송신해야 함.
  - 앱은 응답이 없거나 `error` 포함 시 TTS로 사용자에게 알림.

## 2. 하드웨어 설정 (Servo Configuration)
앱의 '하드웨어 디버깅' 메뉴 및 API를 통해 아래 설정을 하드웨어로 전송할 수 있음.
- **SET_SERVO:** `up_angle`, `down_angle`, `press_ms` 커스텀 설정 가능.
- **GET_SERVO:** 현재 하드웨어에 저장된 서보 파라미터 조회.

## 3. 수치 단위 규격화 (Scale: mm*10)
하드웨어의 정수 연산 처리를 위해 모든 물리적 거리 수치는 `float` 대신 `int(mm * 10)` 단위를 사용함.
- 예: `pitchX: 20.5mm` -> 앱에서 `px10: 205`로 변환하여 전송.
- 적용 대상: `ox10`, `oy10`, `px10`, `py10`.

## 4. 디버깅 도구 추가
- **하드웨어 통신 로그 화면:** 실시간으로 전송(SEND) 및 수신(RECV)되는 데이터와 타임아웃 오류를 확인할 수 있는 전용 UI 추가. (설정 > 하드웨어 디버깅 > 통신 로그 확인)

## 5. BLE 명령 JSON 상세 (v2)

### SET_GRID (그리드 설정)
```json
{
  "action": "set_grid",
  "rows": 3,
  "cols": 3,
  "ox10": 0,
  "oy10": 0,
  "px10": 200,
  "py10": 200,
  "deviceId": "..."
}
```

### PRESS (버튼 누름)
```json
{
  "action": "press",
  "x": 1,
  "y": 0,
  "deviceId": "..."
}
```

### SET_SERVO (서보 설정)
```json
{
  "action": "set_servo",
  "up": 60,
  "down": 110,
  "ms": 300
}
```

## 6. 권장 하드웨어 응답(ACK) 포맷
- 성공: `ok`, `ok:done`, `TOUCH_OK`
- 실패: `error:out_of_range`, `error:invalid_cmd`
- 조회 응답: `SERVO_CFG U60 D110 P300`
