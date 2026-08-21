# 하드웨어 마이그레이션 계획서: 28BYJ-48 -> NEMA17급 XYZ

이 문서는 기존 `28BYJ-48 + ULN2003` 기반 프로토타입에서, 발표/실기기 안정성을 높이기 위한 `NK1704S 42각 스텝모터 + TB6600 + Arduino Uno GRBL` 기반 XYZ 구조로 전환하는 기준 문서입니다.

---

## 1. 결정 요약

- **기존 구조**: 28BYJ-48 스텝모터 + ULN2003 드라이버
- **문제점**: 토크 부족, 감속기 백래시, Z축 누름 힘 부족, 반복 위치 정밀도 불안정
- **신규 구조**: X/Y/Z 전 축을 NK1704S 42각 스텝모터로 통일
- **드라이버**: TB6600 3개
- **모터 전원**: 12V 별도 전원, 배럴잭으로 분리 공급
- **모션 제어**: Arduino Uno + GRBL 유지
- **통신 브릿지**: ESP32가 앱 명령을 수신해 Arduino Uno GRBL로 UART 전달
- **통신 방향**: BLE는 기존 시연/복구 경로로 유지하고, 가정용 고정 장치 특성을 고려해 Wi-Fi 제어 API를 추가 검토

---

## 2. 부품 기준

| 축 | 모터 | 드라이버 | 역할 |
| :--- | :--- | :--- | :--- |
| X축 | NK1704S 42각 스텝모터 | TB6600 | 좌우 이동 |
| Y축 | NK1704S 42각 스텝모터 | TB6600 | 상하/전후 이동 |
| Z축 | NK1704S 42각 스텝모터 | TB6600 | 터치패널 누름 |

추가 필수 부품:

- 12V 모터 전원 어댑터
- 배럴잭 전원 입력부
- 리미트 스위치 최소 3개, 가능하면 각 축 양끝 6개
- GT2 벨트/풀리 또는 리드스크류/랙&피니언 구조
- Z축 스프링 완충 구조 또는 하단 리미트 스위치
- 전도성 터치팁
- 모터 전원 퓨즈 및 대용량 전해 캐패시터

---

## 3. 왜 DC 기어모터가 아닌 스텝모터인가

RB-35GM 같은 DC 기어모터는 토크가 강하지만, 기본적으로 정확한 위치 제어가 어렵습니다. Touch Bridge는 사진 매핑 좌표를 실제 기계 좌표로 반복 이동해야 하므로, 엔코더/PID 없이 DC 기어모터를 X/Y/Z 좌표축에 쓰면 앱-하드웨어 계약이 복잡해집니다.

따라서 현재 프로젝트에서는 다음 기준을 우선합니다.

- X/Y/Z 좌표 제어는 스텝모터 기반으로 유지
- 힘이 부족했던 Z축도 42각 스텝모터 + TB6600으로 강화
- 위치 보정은 GRBL의 steps/mm, max rate, acceleration, travel 설정으로 관리

---

## 4. GRBL 재설정 항목

기구부와 모터가 바뀌면 GRBL 자체를 버리는 것이 아니라, 아래 설정을 새 하드웨어 기준으로 다시 튜닝합니다.

```text
$100 X축 steps/mm
$101 Y축 steps/mm
$102 Z축 steps/mm
$110 X max rate
$111 Y max rate
$112 Z max rate
$120 X acceleration
$121 Y acceleration
$122 Z acceleration
$130 X max travel
$131 Y max travel
$132 Z max travel
```

추가 확인:

- 각 축 방향 반전 여부
- 리미트 스위치 위치와 homing 방향
- `$H` 홈 복귀 성공 여부
- Z축 안전 높이와 최대 누름 깊이

---

## 5. 앱 명령 흐름 변경 기준

앱 구조는 유지하되, 버튼 실행은 2D 인덱스 명령에서 XYZ G-code 시퀀스로 확장합니다.

기존:

```text
BT-xx -> row/col -> BTN_n 또는 PRESS x y
```

신규:

```text
BT-xx -> row/col -> X/Y mm 좌표 -> Z 누름 시퀀스 -> GRBL G-code
```

예시 G-code:

```gcode
G90
G21
G0 Z5 F600
G0 X120 Y80 F1200
G1 Z-2 F200
G4 P0.2
G0 Z5 F600
```

앱 매핑 프로필에는 기존 `originX`, `originY`, `pitchX`, `pitchY` 외에 아래 값 추가를 검토합니다.

```text
travelHeightZ
pressDepthZ
travelFeed
pressFeed
homeBeforePress
```

---

## 6. ESP32 통신 방향

현재 BLE 기반 연결은 유지합니다. 다만 가정용 고정 장치라는 특성상 Wi-Fi 제어 경로를 추가하면 상태 모니터링과 로그 수집이 쉬워집니다.

권장 구조:

```text
Flutter App
-> BLE 또는 Wi-Fi
-> ESP32 Bridge
-> UART
-> Arduino Uno GRBL
-> TB6600
-> NK1704S XYZ
```

ESP32 역할:

1. BLE GATT 또는 Wi-Fi HTTP/WebSocket으로 앱 명령 수신
2. 명령을 GRBL G-code로 변환하거나 앱에서 받은 raw G-code를 UART로 전달
3. Arduino Uno의 `ok`, `error`, alarm 상태를 앱으로 반환
4. 비상 정지 명령은 최우선으로 전달

Wi-Fi는 기본 제어 채널 후보이고, BLE는 초기 설정/복구/근거리 시연용으로 유지합니다.

---

## 7. 기구 설계 방향

처음부터 완전 신규 모델링하지 않고, NEMA17 기반 소형 CNC/플로터/XYZ 갠트리 구조를 참고해 Touch Bridge 크기에 맞게 축소/수정합니다.

권장 구조:

- X/Y: GT2 벨트 기반 갠트리 또는 소형 CNC 플로터 구조
- Z: 리드스크류, 랙&피니언, 캠 구조 중 하나로 누름 힘 확보
- 끝단: 전도성 터치팁 + 스프링 완충
- 안전: 각 축 리미트 스위치와 물리 E-STOP

---

## 8. 작업 순서

1. NK1704S 1개 + TB6600 1개로 단일 축 구동 테스트
2. Arduino Uno GRBL에서 steps/mm, 방향, 속도, 가속도 튜닝
3. X/Y축 갠트리 조립 및 homing 테스트
4. Z축 누름 구조 설계, 하단 리미트/스프링 완충 적용
5. ESP32 -> Arduino Uno UART 브릿지 안정화
6. 앱 개발자 콘솔에서 `$H`, X/Y/Z jog, raw G-code, STOP 테스트
7. 사진 매핑 좌표를 실제 X/Y/Z 시퀀스로 실행
8. Wi-Fi 제어 API 추가 여부 결정 및 보안 정책 문서화

---

## 9. 주의사항

- TB6600 1개는 모터 1개만 담당합니다. XYZ 전 축 스텝모터면 TB6600 3개가 필요합니다.
- ESP32/Arduino/모터 전원 GND는 공통 접지해야 합니다.
- 모터 전원은 MCU 전원과 분리하고, 배럴잭 입력부에 퓨즈를 추가합니다.
- Z축은 사람 손가락 대신 누르는 축이므로 과한 힘이 걸리지 않게 스프링 완충 또는 리미트 스위치를 반드시 고려합니다.
- Wi-Fi only 구조는 공유기/비밀번호 문제에 취약하므로, BLE 복구 경로 또는 물리 설정 절차를 남겨둡니다.
