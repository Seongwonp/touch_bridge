// =====================================================================
//  SwitchBot Bot - BLE 직접 제어 (허브 없이) / ESP32 Arduino (Bluedroid BLE)
//  프로토콜: OpenWonderLabs/SwitchBotAPI-BLE  devicetypes/bot.md
//    서비스  cba20d00-224d-11e6-9fb8-0002a5d5c51b
//    쓰기    cba20002-...  (ESP32 → Bot)
//    응답    cba20003-...  (Bot → ESP32, notify)
//    명령    57 01 00 = 누름(press) / 57 01 01 = 켜기 / 57 01 02 = 끄기
//    응답 1바이트째: 0x01 OK, 0x02 실행 오류, 0x03 바쁨, 0x05 미지원(모드 확인),
//                   0x06 배터리 부족, 0x07 암호화됨(앱에서 비밀번호 해제 필요), 0x09 비밀번호 오류
//
//  Touch Bridge 펌웨어와 같은 BLEDevice(Bluedroid)를 쓰므로 그대로 같이 넣을 수 있음.
//  ESP32는 앱 쪽 서버(peripheral) 역할을 유지한 채로 Bot에 클라이언트(central)로 붙는다.
//
//  연결·쓰기·응답 대기는 수백 ms~수 초가 걸리므로 별도 FreeRTOS 태스크에서 실행하고,
//  loop()는 sbble::poll()로 결과만 확인한다 (loop/비상 정지를 막지 않음).
//
//  사용:
//    BLEDevice::init(...) 이후  sbble::begin("AA:BB:CC:DD:EE:FF");
//    sbble::request(sbble::PRESS);          // false면 이전 명령이 아직 진행 중
//    int r; if (sbble::poll(r)) { r == sbble::SB_OK ? 성공 : 실패 }
// =====================================================================
#pragma once
#include <BLEDevice.h>
#include <BLEClient.h>

namespace sbble {

static const char* SVC_UUID = "cba20d00-224d-11e6-9fb8-0002a5d5c51b";
static const char* TX_UUID  = "cba20002-224d-11e6-9fb8-0002a5d5c51b";
static const char* RX_UUID  = "cba20003-224d-11e6-9fb8-0002a5d5c51b";

enum Cmd : uint8_t { PRESS = 0x00, TURN_ON = 0x01, TURN_OFF = 0x02 };

// 양수 = Bot이 돌려준 상태 바이트 그대로, 음수 = ESP32 쪽 오류
enum Result : int {
  SB_OK          = 0x01,
  SB_ERR_CONNECT = -1,   // 연결 실패 (MAC 오류, 거리, Bot이 다른 기기와 연결 중)
  SB_ERR_SERVICE = -2,   // 서비스/특성 없음
  SB_ERR_TIMEOUT = -3,   // 쓰기는 했는데 응답 notify가 안 옴
  SB_ERR_CANCELLED = -4, // 쓰기 전에 cancel()로 취소됨 (Bot은 누르지 않음)
};

constexpr uint32_t ACK_TIMEOUT_MS = 3000;

static BLEClient*    client   = nullptr;
static QueueHandle_t reqQ     = nullptr;
static QueueHandle_t resQ     = nullptr;
static char          mac[18]  = "";
static volatile bool inFlight = false;
static volatile bool cancelReq = false;
static volatile bool gotAck   = false;
static volatile uint8_t ackByte = 0;

static void onNotify(BLERemoteCharacteristic*, uint8_t* data, size_t len, bool) {
  if (len) { ackByte = data[0]; gotAck = true; }
}

static int doCommand(uint8_t cmd) {
  gotAck = false;
  // SwitchBot은 random static 주소를 씀
  if (!client->connect(BLEAddress(mac), BLE_ADDR_TYPE_RANDOM)) return SB_ERR_CONNECT;
  if (cancelReq) {   // 연결 대기 중 정지가 들어옴
    client->disconnect();
    delay(150);
    return SB_ERR_CANCELLED;
  }

  int res = SB_ERR_SERVICE;
  BLERemoteService* svc = client->getService(BLEUUID(SVC_UUID));
  BLERemoteCharacteristic* tx = svc ? svc->getCharacteristic(BLEUUID(TX_UUID)) : nullptr;
  BLERemoteCharacteristic* rx = svc ? svc->getCharacteristic(BLEUUID(RX_UUID)) : nullptr;

  if (tx) {
    const bool canAck = rx && rx->canNotify();
    if (canAck) rx->registerForNotify(onNotify);
    if (cancelReq) {   // 쓰기 직전 마지막 확인. 이 뒤로는 되돌릴 수 없다
      client->disconnect();
      delay(150);
      return SB_ERR_CANCELLED;
    }
    uint8_t pkt[3] = {0x57, 0x01, cmd};
    tx->writeValue(pkt, sizeof(pkt), true);

    if (canAck) {
      const uint32_t t0 = millis();
      while (!gotAck && millis() - t0 < ACK_TIMEOUT_MS) delay(10);
      res = gotAck ? (int)ackByte : SB_ERR_TIMEOUT;
    } else {
      res = SB_OK;   // 응답 채널이 없으면 쓰기 성공을 완료로 간주
    }
  }
  client->disconnect();
  delay(150);        // 다음 연결 전에 끊김 처리가 끝나도록
  return res;
}

static void worker(void*) {
  uint8_t cmd;
  for (;;) {
    if (xQueueReceive(reqQ, &cmd, portMAX_DELAY) == pdTRUE) {
      int r = doCommand(cmd);
      xQueueOverwrite(resQ, &r);
      inFlight = false;
    }
  }
}

// BLEDevice::init() 이후에 호출
inline void begin(const char* botMac) {
  strncpy(mac, botMac, sizeof(mac) - 1);
  client = BLEDevice::createClient();
  reqQ = xQueueCreate(1, sizeof(uint8_t));
  resQ = xQueueCreate(1, sizeof(int));
  // 1kHz 모션 제어가 코어 1을 쓰므로 BLE 작업은 코어 0, 낮은 우선순위
  xTaskCreatePinnedToCore(worker, "sbble", 6144, nullptr, 2, nullptr, 0);
}

// 명령 요청. 이전 명령이 진행 중이면 false
inline bool request(uint8_t cmd) {
  if (!client || inFlight) return false;
  xQueueReset(resQ);          // 타임아웃 뒤 늦게 도착한 이전 결과는 버림
  cancelReq = false;
  inFlight = true;
  if (xQueueSend(reqQ, &cmd, 0) != pdTRUE) { inFlight = false; return false; }
  return true;
}

// 결과가 나왔으면 true + result
inline bool poll(int& result) {
  return resQ && xQueueReceive(resQ, &result, 0) == pdTRUE;
}

inline bool busy() { return inFlight; }

// 진행 중인 명령을 취소 요청한다. 아직 쓰지 않았으면 Bot은 누르지 않지만,
// 이미 쓴 누름은 Bot이 실행하며 되돌릴 수 없다.
inline void cancel() { if (inFlight) cancelReq = true; }

inline const char* resultName(int r) {
  switch (r) {
    case SB_OK:          return "OK";
    case 0x02:           return "BOT_EXEC_ERROR";
    case 0x03:           return "BOT_BUSY";
    case 0x05:           return "BOT_UNSUPPORTED";
    case 0x06:           return "BOT_LOW_BATTERY";
    case 0x07:           return "BOT_ENCRYPTED";
    case 0x09:           return "BOT_PASSWORD";
    case SB_ERR_CONNECT: return "CONNECT_FAIL";
    case SB_ERR_SERVICE: return "NO_SERVICE";
    case SB_ERR_TIMEOUT: return "ACK_TIMEOUT";
    case SB_ERR_CANCELLED: return "CANCELLED";
    default:             return "BOT_STATUS_UNKNOWN";
  }
}

}  // namespace sbble
