# 앱–펌웨어 약속 (2026-11-10 초안)

앱(SW)과 모터 ESP32 펌웨어(HW)가 같은 응답을 같은 뜻으로 읽도록 정리한다. 코드가 기준이다. 이 문서와 코드가 어긋나면 코드를 믿고 이 문서를 고친다. 펌웨어를 바꾸는 사람과 앱을 바꾸는 사람이 함께 고친다.

작성 근거: `hardware/touchbridge_corexy/touchbridge_corexy.ino`(v4, `fw/bot-link-not-app-disconnect` 브랜치 포함), `lib/services/ble_service.dart`, `lib/services/mapping_execution_service.dart`.

## 1. 펌웨어가 스스로 멈추는 경우

| 조건 | 펌웨어 동작 | 앱에 보내는 것 |
|---|---|---|
| 앱 BLE 연결 끊김 | 비상 정지(모터 정지, 아직 쓰지 않은 Bot 누름 취소, 큐 비움) | 연결이 끊겨 보낼 수 없음 |
| JSON에 `"stop"`이 든 쓰기, 텍스트 `!`·`S`·`STOP` | 즉시 비상 정지 | JSON이면 `{"commandId":…, "state":"STOPPED"}`, 텍스트면 `STOPPED` |
| 모터 추종 오차 | 실패 처리, 큐 비움 | JSON `ERROR_STALL` / 텍스트 `FAULT FOLLOW_ERROR` |
| 목표 위치에 못 멈춤 | 실패 처리, 큐 비움 | JSON `ERROR_POSITION` / 텍스트 `FAULT SETTLE` |
| 원점 복귀 실패 | 실패 처리 | JSON `ERROR_TIMEOUT` / 텍스트 `FAULT HOME_NOT_FOUND` |
| 원점 없이 이동, 범위 밖 이동 | 그 이동 실패 처리, 큐 비움 | JSON `ERROR_LIMIT` / 텍스트 `FAULT NOT_HOMED`, `FAULT OUT_OF_RANGE` |
| Bot 연결·누름 실패, 8초 초과 | 실패 처리 | JSON `ERROR_TIMEOUT`·`ERROR_PROTOCOL` / 텍스트 `FAULT …` |

**2026-11-10에 고친 오인 정지**: ESP32가 Bot에 연결했다 끊을 때도 BLE 라이브러리가 "앱 연결 끊김" 이벤트를 냈다. 그래서 누를 때마다 위 첫 줄의 비상 정지가 일어나 `PRESSED` 대신 `STOPPED`가 나갔다. 상대 주소가 Bot이면 무시하도록 고쳤다(`fw/bot-link-not-app-disconnect`, 실기 확인).

## 2. 응답의 뜻

| 응답 | 뜻 | 뜻이 아닌 것 |
|---|---|---|
| G-code `ok` | 명령을 큐에 받았다 | 움직였다, 눌렀다 |
| 텍스트 `OK` | 명령을 큐에 받았다 | 실행했다 |
| `DONE x y` | 이동이 목표에 도착했다고 펌웨어가 판정 | — |
| `PRESSED` / JSON `COMPLETED`(누름) | **Bot이 누름 명령을 받아들였다** | 패널 버튼이 실제로 눌렸다, 가전이 동작했다 |
| `STOPPED` | 펌웨어가 정지 처리를 했다 | 물리적으로 멈췄다는 측정, **앱이 요청한 정지**(펌웨어가 스스로 멈춰도 같은 말을 쓴다) |
| `STATE … q=0 bot=0` | 큐가 비었고 Bot이 쉬고 있다 | 앞선 명령이 모두 성공했다 |

## 3. 앱이 읽는 방식 (현재 코드)

- `FAULT`·`ERROR:`(대소문자 무관)로 시작하는 줄은 기기 실패로 센다. 실행 중이면 남은 명령을 보내지 않고 실패로 안내한다.
- 정지 ACK는 정지 명령의 `commandId`와 맞는 `STOPPED`·`COMPLETED`, 또는 레거시 `OK`·`STOPPED`다.
- 음성 경로는 시퀀스를 보낸 뒤 `P`로 `q=0`, `bot=0`을 기다린다(드레인).

## 4. 아직 맞추지 못한 것

1. **펌웨어가 스스로 낸 `STOPPED`를 앱이 구분하지 못한다.** 드레인은 `STATE`가 `FAULT`일 때만 실패로 보고, `STOPPED`이면서 `q=0 bot=0`이면 완료로 본다. 펌웨어가 중간에 스스로 멈추고 큐를 비우면, 남은 버튼을 누르지 않았는데도 앱이 완료로 안내할 수 있다. 앱이 정지를 요청하지 않았는데 `STOPPED`가 오면 "기기가 동작을 멈췄습니다. 확인해 주세요"로 다뤄야 하는지 같이 정한다. `STATE STOPPED`가 다음 이동 전까지 남는 시점은 실기로 확인한 뒤 앱을 고친다.
2. **누름 완료 감지가 없다.** Bot의 OK는 명령 수락이다. 앱은 "누르도록 보냈습니다"까지만 말한다(재설계 제안 4절).
3. **페어링 키 미등록 상태에서는 누구나 동작시킬 수 있다(`key=none`).** 시연 전에 키를 등록한다.

## 5. 바꿀 때의 규칙

- 펌웨어에 새 정지 조건이나 응답을 추가하면 이 문서 1·2절에 한 줄을 추가하고 앱 담당에게 알린다.
- 앱이 응답 해석을 바꾸면 3절을 고치고 펌웨어 담당에게 알린다.
- "응답이 왔다"와 "물리적으로 됐다"를 구분해 적는다.
