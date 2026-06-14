# ESP32 BLE 연결 테스트 가이드 (Arduino IDE)

목적: **폰 ↔ ESP32 BLE 연결 및 Write/Notify 동작**만 빠르게 검증한다.  
이 가이드는 UART/AVR 연동을 다루지 않는다.

## 준비물
- ESP32 DevKitC WROOM-32D
- Arduino IDE
- BLE 테스트 앱 (예: nRF Connect)

## Arduino IDE 설정
1. Boards Manager에 **ESP32 by Espressif Systems** 설치
2. 보드 선택: `ESP32 Dev Module` (또는 사용 보드에 맞는 항목)
3. 포트 선택: USB 연결 포트

## 업로드용 스케치
아래 코드를 그대로 업로드한다.  
연결되면 1초마다 `PING`을 Notify로 보내고, 앱에서 Write하면 시리얼에 출력된다.

```cpp
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

static const char* SERVICE_UUID = "0000FFE0-0000-1000-8000-00805F9B34FB";
static const char* CHAR_UUID    = "0000FFE1-0000-1000-8000-00805F9B34FB";

BLECharacteristic* pChar = nullptr;
bool deviceConnected = false;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    deviceConnected = true;
    Serial.println("BLE connected");
  }
  void onDisconnect(BLEServer*) override {
    deviceConnected = false;
    Serial.println("BLE disconnected");
  }
};

class CharCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    std::string v = c->getValue();
    if (!v.empty()) {
      Serial.print("RX: ");
      Serial.println(v.c_str());
    }
  }
};

void setup() {
  Serial.begin(115200);
  BLEDevice::init("TouchBridge-ESP32");

  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(SERVICE_UUID);

  pChar = service->createCharacteristic(
      CHAR_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY
  );
  pChar->addDescriptor(new BLE2902());
  pChar->setCallbacks(new CharCallbacks());

  service->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("BLE advertising started");
}

void loop() {
  if (deviceConnected) {
    pChar->setValue("PING");
    pChar->notify();
    delay(1000);
  } else {
    delay(200);
  }
}
```

## 테스트 절차
1. 업로드 후 시리얼 모니터(115200)에서 `BLE advertising started` 확인
2. BLE 앱에서 **TouchBridge-ESP32** 연결
3. `0000FFE1` 특성에서 **Notify** 활성화 → `PING` 수신 확인
4. 같은 특성에 Write 전송 → 시리얼에 `RX: ...` 출력 확인

## 기대 결과
- 연결 성공 시 1초 주기로 `PING` 알림 수신
- 앱에서 Write한 문자열이 시리얼 모니터에 출력됨

## 문제 해결
- 기기가 안 보이면: 전원/케이블 확인 후 보드 리셋
- Notify가 안 오면: 특성의 Notify 토글 확인
- Write가 안 찍히면: 앱에서 Write 타입(Write/Write Without Response) 변경 시도
