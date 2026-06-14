# ESP32 BLE↔UART 브리지 펌웨어 가이드 (Arduino IDE)

목적: **앱의 BLE(GATT) 명령을 UART로 전달하고, AVR 응답을 BLE Notify로 되돌리는 브리지 펌웨어**를 업로드한다.

## 스케치 위치
- `esp32/TouchBridgeBLEBridge/TouchBridgeBLEBridge.ino`

## 핵심 동작
- BLE Service/Char: `FFE0/FFE1` (Write + Notify)
- BLE Write 수신 → UART(Serial2)로 전송 + `CRLF` 추가
- UART 줄 단위 응답(`\n`) → BLE Notify로 전달
- 5초 내 응답 없으면 `ERROR:TIMEOUT` Notify

## 역할 분리
현재 구조에서 ESP32는 모터를 직접 구동하지 않는다. ESP32는 Android 앱과 Arduino Uno/GRBL 사이의 **BLE↔UART 통신 브리지** 역할만 담당한다.

```text
Android 앱
  -> BLE GATT Write
ESP32
  -> Serial2 UART로 명령 전달
Arduino Uno / GRBL
  -> 명령 해석, 모터/서보/터치 동작 수행
  -> UART 응답
ESP32
  -> BLE Notify로 앱에 응답 전달
```

이렇게 나누는 이유:
- Uno/GRBL 쪽에 이미 스텝 모터, 서보, 리밋, 터치 좌표 처리 로직이 있다.
- ESP32에는 BLE 연결, 앱 연동, UART 중계만 맡겨 디버깅 범위를 줄인다.
- BLE 처리와 실시간 모터 제어를 한 보드에 섞지 않아 구조가 단순하다.
- ESP32로 전체 제어를 옮기려면 GRBL 제어 로직, 핀맵, 타이머, 스텝 펄스 처리를 다시 맞춰야 한다.

따라서 `UART_TX BT-05` 로그가 찍히면 ESP32는 Android 명령을 Uno 방향으로 전달한 것이다. 이후 실제 동작 여부는 Uno 펌웨어, UART 배선, 모터/서보 결선 상태에 달려 있다.

## 배선
- ESP32 TX2(GPIO17) → Uno RX
- ESP32 RX2(GPIO16) ← Uno TX
- GND 공통
- **레벨 시프터/분압 필수** (Uno TX=5V → ESP32 RX=3.3V)

## Arduino IDE 설정
1. Boards Manager에서 **ESP32 by Espressif Systems** 설치
2. 보드 선택: `ESP32 Dev Module` (또는 사용 보드)
3. 포트 선택: USB 연결 포트

## 필수 라이브러리
- **ArduinoJson (v6)**: JSON 명령 파싱에 사용

## 보드 참고
- **ESP32 DevKitC WROOM-32D V4 (CH9102X)** 기준으로 작성
- CH9102X 드라이버가 없으면 포트가 보이지 않을 수 있음

## 업로드 절차
1. Arduino IDE에서 `TouchBridgeBLEBridge.ino` 열기
2. 업로드
3. 시리얼 모니터(115200)에서 `BLE advertising started` 확인

## 간단 테스트
1. BLE 앱(nRF Connect 등)에서 **TouchBridge-ESP32** 연결
2. `0000FFE1` 특성에서 Notify 활성화
3. Write로 `SET_GRID 3 3 0 0 200 200` 전송
4. Uno 응답이 오면 Notify로 수신

## 로그 해석
BLE 연결만 된 상태:

```text
000 START BLE bridge boot
001 BLE advertising started
002 BLE connected
```

이 상태는 앱이 ESP32에 연결된 것만 의미한다. 실제 명령을 보낸 것은 아니다.

BLE Write가 정상으로 들어온 상태:

```text
003 WRITE_CB len=7
004 RX BT-05
005 RAW BT-05
006 UART_TX BT-05
```

이 상태는 Android -> ESP32 BLE 수신 -> ESP32 Serial2 송신까지 성공했다는 뜻이다.

Uno 응답이 없을 때:

```text
007 NOTIFY ERROR:TIMEOUT
```

ESP32가 명령을 보냈지만 5초 안에 Uno/GRBL에서 응답이 돌아오지 않은 상태다. 모터/Uno가 아직 연결되지 않았거나, UART 배선/baud/Uno 펌웨어 수신 경로가 준비되지 않았으면 정상적으로 발생할 수 있다.

## Android 테스트 앱 주의
- 현재 펌웨어는 **BLE GATT** 방식이다.
- Android의 `Serial Bluetooth Terminal` 앱에서 **Bluetooth Classic/SPP 모드**로 찾으면 `TouchBridge-ESP32`가 안 보일 수 있다.
- 같은 앱을 쓰더라도 BLE 모드가 있는지 확인하거나, nRF Connect 같은 BLE GATT 테스트 앱에서 `FFE1` characteristic에 Write해야 한다.
- Notify 수신을 보려면 `FFE1` characteristic의 Notify를 활성화한다.

## 참고
- iOS는 Classic Bluetooth(SPP)를 지원하지 않으므로 **BLE GATT 기반**이어야 한다.
- UART 응답 포맷은 `docs/APP_HW_PROTOCOL_KO.md`를 따른다.
