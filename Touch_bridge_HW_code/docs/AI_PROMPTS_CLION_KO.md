CLion에서 ESP32 브리지 작업을 AI에게 맡길 때 사용할 프롬프트 모음

목표
- ESP32 DevKitC WROOM-32D에 NimBLE 기반 BLE GATT 서버를 구현해 앱(서비스 UUID 0000FFE0, CHAR 0000FFE1)로부터 WRITE를 수신하고, UNO(AVR/GRBL)로 UART 전송, AVR 응답을 BLE NOTIFY로 전달.

작업 1: 전체 구현 개요 요청
프롬프트:
"프로젝트: Touch Bridge의 ESP32 브리지 펌웨어를 작성할 예정입니다. 보드: ESP32 DevKitC WROOM-32D, UART: Serial2(GPIO16 RX, GPIO17 TX), BLE Service UUID: 0000FFE0, Char UUID: 0000FFE1(WRITE+NOTIFY). 요구사항: BLE로 명령 수신 후 UART로 전송, UART의 각 라인 응답을 BLE로 notify, timeout 5초. C++ Arduino(NimBLE) 예제로 전체 코드를 작성해줘. 디버깅 로그는 USB 시리얼로 찍고, 전송되는 문자열에 CRLF 추가. 코드 주석과 빌드/업로드 명령 포함" 

작업 2: writeCallback 세부 구현
프롬프트:
"BLE characteristic write callback을 안전하게 구현하는 예제를 보여줘. callback에서 직접 긴 연산을 하면 안됨. payload를 FreeRTOS queue에 넣고 worker task가 Serial2.println(payload) 하도록 설계. 코드 예제 요청." 

작업 3: UART->BLE notification loop
프롬프트:
"UART에서 readStringUntil('\n')로 줄 단위 응답을 파싱하고 BLE notify로 보내는 루프를 만들어줘. BLE 연결 유무 확인 로직 포함. 또한, 애플리케이션 ACK 패턴(TOUCH_OK:/GRID_CONFIG_UPDATED 등)을 필터링하여 notify payload를 그대로 전달하는 예제." 

작업 4: 리셋/EMERGENCY_STOP 처리
프롬프트:
"BLE로 'stop' 또는 'EMERGENCY_STOP' 명령을 받으면 Serial2로 'BT-06' 또는 'BTN_6'을 전송하고, 즉시 notify로 'EMERGENCY_STOP_EXECUTED'를 보낼 것. 이 흐름을 보장하는 코드 스니펫 제공." 

작업 5: 테스트 시나리오 스텝
프롬프트:
"CLion에서 ESP32 빌드/업로드 후 테스트 절차를 적어줘: 1) 전원/핀 결선 확인, 2) Serial2 모니터로 UART 패킷 감시, 3) BLE 연결 (nRF Connect 등)로 SET_GRID 테스트, 4) BTN_5 전송 및 TOUCH_OK 수신 확인." 

참고
- 하드웨어/펌웨어 프로토콜은 docs/APP_HW_PROTOCOL_KO.md와 grbl/touch_bridge.c에 정의되어 있음.
- UNO는 5V TTL. ESP32 RX에 연결 시 레벨 시프터 또는 분압 권장.

사용법
- CLion에서 새 이슈/스크립트에 넣거나, AI 파트너(예: GitHub Copilot Chat/GitHub Codespaces)에게 복사해 붙여넣어 요청할 것.

