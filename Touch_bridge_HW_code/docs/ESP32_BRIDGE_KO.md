# ESP32 BLE↔UART 브리지 구현 가이드 (ESP32 DevKitC WROOM-32D)

요약
- 목적: Flutter 앱(라이브)에서 보내는 BLE 쓰기 요청을 ESP32에서 수신해 AVR/GRBL(Arduino Uno)로 UART 전송, AVR 응답을 BLE NOTIFY로 앱에 전달.
- 추천 보드: ESP32 DevKitC WROOM-32D (CH9102X)
- BLE UUID: Service 0000FFE0..., Char 0000FFE1... (WRITE+NOTIFY)

역할 분리
- ESP32는 Android/Flutter 앱과 Arduino Uno 사이의 통신 징검다리다.
- ESP32는 BLE GATT 연결, Write 수신, UART 전달, Notify 응답 전달만 맡는다.
- 실제 모터/서보/터치 동작은 Arduino Uno의 GRBL/Touch Bridge 펌웨어가 수행한다.
- 이 구조를 쓰는 이유는 기존 GRBL 모션 제어 로직을 유지하고, 무선 통신 문제와 하드웨어 제어 문제를 분리해서 디버깅하기 위해서다.

전체 데이터 흐름
```text
Android/Flutter 앱
  -> BLE GATT Write
ESP32 BLE bridge
  -> Serial2 UART
Arduino Uno / GRBL
  -> 모터, 서보, 리밋, 터치 동작
  -> UART 응답
ESP32 BLE bridge
  -> BLE Notify
Android/Flutter 앱
```

하드웨어 결선
- ESP32 TX2 (예: GPIO17) -> Uno RX (RX0 또는 소프트웨어 시리얼 수신 핀)
- ESP32 RX2 (예: GPIO16) -> Uno TX
- 공통 GND 연결 필수
- 전압: Uno는 5V, ESP32는 3.3V. Arduino RX/TX 레벨 매칭 필요(레벨시프터 권장). Uno의 TX(5V) -> ESP32 RX는 분압 추천.

UART 설정
- ESP32 Serial2 예시: Serial2.begin(115200, SERIAL_8N1, RX_PIN, TX_PIN);
- AVR/GRBL 기본 보드 속도: 115200 (확인 필요)

BLE 서비스 계약
- Service UUID: 0000FFE0-0000-1000-8000-00805F9B34FB
- Characteristic UUID: 0000FFE1-0000-1000-8000-00805F9B34FB
- Property: Write (from app) + Notify (from ESP32)
- Bluetooth Classic/SPP가 아니라 BLE GATT다. Classic 전용 터미널 앱 목록에는 장치가 안 보일 수 있다.

앱↔브리지 페이로드 규약 (권장)
- UART 토큰 기반 간단 텍스트: BTN_<n>, BT-<n>, PRESS x y, SET_GRID r c ox10 oy10 px10 py10, SET_SERVO up down press_ms, GET_SERVO
- 이유: AVR 연산 부담 최소화, 파싱 단순화

ESP32 동작 로직(요구사항)
1) BLE WRITE 수신
  - 수신 페이로드가 JSON이면 파싱(권장 아님). 권장: 앱에서 토큰 텍스트 전송.
2) 수신 명령을 UART로 전송(끝에 CR/LF 포함)
3) UART에서 한 줄 응답을 읽고 BLE NOTIFY로 앱에 전달
4) ACK/타임아웃: 앱이 ACK를 가정하면 ESP32는 AVR 응답을 그대로 notify. 타임아웃(예: 5s) 이내 무응답 시 "ERROR:TIMEOUT" notify
5) 재전송 정책: 단순히 앱이 재전송하거나 ESP32가 내부 큐 재시도 (초기 버전에서는 앱 재전송 권장)

시스템 아키텍처(간단)
- BLE Write -> BLE RX Callback -> enqueue UART write -> read UART lines -> BLE notify
- 스레딩: FreeRTOS task 또는 loop 기반 폴링 가능

샘플 코드(Arduino style, NimBLE 권장):
- 초기화: BLEDevice::init("TouchBridge-ESP32"); createService(UUID); createCharacteristic(UUID, BLECharacteristic::PROPERTY_WRITE | PROPERTY_NOTIFY);
- writeCallback: Serial2.println(payload);
- UART read loop: if (Serial2.available()) { String line = Serial2.readStringUntil('\n'); notify(line); }

테스트 절차
1. ESP32와 Uno를 UART로 연결(전원 및 GND 포함)
2. 시리얼 모니터(ESP32)에서: send "SET_GRID 3 3 0 0 200 200" -> Uno가 "GRID_CONFIG_UPDATED" 응답
3. BLE 앱(테스트 유틸)로 advertise/conn -> write "BTN_5" -> ESP32가 UART 전송 -> UNO가 동작 -> ESP32가 "TOUCH_OK:BTN_5" notify

디버그 팁
- Serial2 모니터 로그를 USB 시리얼로 출력 (보드의 기본 USB 포트). 혹은 BLE에 "LOG:..." notify 전송.
- AVR->ESP32 TTL 레벨: 반드시 분압 혹은 레벨시프터 사용
- `BLE connected`까지만 보이면 연결만 된 상태다.
- `WRITE_CB`, `RX`, `UART_TX`가 찍히면 Android -> ESP32 -> Uno 방향 송신까지 성공한 것이다.
- `ERROR:TIMEOUT`은 ESP32가 명령을 보냈지만 Uno/GRBL 응답을 받지 못했다는 뜻이다. Uno/모터가 아직 연결되지 않았거나 UART 배선/baud가 맞지 않으면 발생한다.

향후 개선
- 명령 재시도/큐 우선순위
- 보안: BLE pairing / encryption (초기엔 오프)
- 펌웨어 OTA

참고: GRBL 쪽 프로토콜은 docs/APP_HW_PROTOCOL_KO.md 및 grbl/touch_bridge.c를 참조
