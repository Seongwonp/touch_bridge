// =====================================================================
//  Touch Bridge - CoreXY 모션 + 솔레노이드 누름 펌웨어 (ESP32)  v3
//  모터: DFRobot FIT0482 (6V, 50:1, 홀 엔코더) x2
//  드라이버: JMOD-MOTOR-1 (TB6612FNG)
//  누름: SparkFun ROB-11015 솔레노이드 5V (N-MOSFET 로우사이드 + 플라이백 다이오드)
//
//  필요 라이브러리: ArduinoJson v7 (라이브러리 매니저에서 설치)
//
//  ── 연결 ────────────────────────────────────────────────────────────
//  BLE 이름 "Touch Bridge"
//   - 서비스 FFE0 / 특성 FFE1 (write + notify)  ← Touch Bridge 앱이 쓰는 경로
//   - Nordic UART(NUS)                           ← 일반 BLE 터미널 앱 디버깅용
//  USB 시리얼 115200 도 같은 명령을 받음 (시리얼은 인증 없이 항상 허용)
//
//  ── 받는 명령 3종 ──────────────────────────────────────────────────
//  1) 앱 v2 JSON (사진 매핑 경로, SafePressCoordinator)
//     {"version":2,"commandId":..,"action":"home|move_only|press|stop|status",...}
//     → 상태를 JSON으로 notify: RECEIVED → MOVING → POSITIONED(+positionToken)
//       → COMPLETED / PRESSING → COMPLETED / STOPPED / ERROR_*
//     인증용: {"action":"challenge"|"auth"|"provision"} → NONCE:.. / AUTH_OK / PROVISION_OK
//
//  2) GRBL 호환 G-code (앱 음성 경로, MappingExecutionService)
//     G90 G91 G21 G92 X0 Y0 G92.1  G0/G1 X Y Z F  G4 P(초)  $H  $$  STOP
//     BTN_n   SET_GRID rows cols ox10 oy10 px10 py10
//     Z는 솔레노이드로 해석: 상대(G91) Z- / 절대(G90) Z<0 → 누름, 그 반대 → 뗌
//
//  3) 기존 텍스트 명령 (직접 테스트용)
//     G x y [f]      절대 좌표[mm] 이동, f = mm/s
//     GT x y [f]     이동 후 한 번 누름
//     T [ms]         현재 위치에서 한 번 누름
//     H              원점 복귀       S 또는 !   비상 정지
//     Z              현재 위치를 원점(0,0)으로      P  상태 출력
//     M a b [ms]     모터 PWM 직접 인가 (-1~1)      K kp ki kd kff  게인 변경
//     KEYRESET       (시리얼 전용) BLE 페어링 키 삭제
//     ?              도움말
//
//  모든 물리 동작은 하나의 큐에서 순서대로 실행됨. 이동이 끝나기 전에는
//  누름을 시작하지 않고, 이동/원점 실패나 정지가 오면 남은 큐를 전부 버림.
// =====================================================================
#include <stdarg.h>
#include <math.h>
#include <esp_arduino_version.h>
#include <esp_system.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include "mbedtls/md.h"
#include "config.h"
#include "CoreXYMotion.h"

// ---------------- 공용 타입 ----------------
// Arduino IDE는 첫 함수 정의 바로 앞에 함수 선언을 자동으로 넣는다.
// 함수 인자로 쓰는 타입은 반드시 첫 함수보다 위(여기)에 정의해야 한다.
constexpr size_t CMD_LINE_MAX = 256;   // v2 JSON 한 줄이 200바이트 가까이 됨

enum Source : uint8_t { SRC_SERIAL, SRC_BLE };
struct LineMsg { char text[CMD_LINE_MAX]; };

enum Origin : uint8_t { ORG_TEXT, ORG_GCODE, ORG_JSON };   // 응답 형식 결정
enum class StepType : uint8_t { MOVE, HOME, SET_ORIGIN, SOL_DOWN, SOL_UP, DWELL, TAP };

struct Step {
  StepType type;
  Origin org;
  float x, y, f, tol;   // MOVE
  uint32_t ms;          // DWELL / TAP
  char id[48];          // JSON commandId
};

enum class Phase : uint8_t { WAIT_RELEASE, WAIT_MOTION, WAIT_TIME, TAP_HOLD, TAP_RELEASE };

CoreXYMotion motion;
QueueHandle_t motionEvents;

// =====================================================================
//  솔레노이드
// =====================================================================
// config.h에서 이미 쓰는 핀: 4(STBY) 25/26/27(모터A) 32/33/13(모터B)
//   16/17(엔코더A) 18/19(엔코더B). 남는 출력 핀 중 부팅 영향 없는 23을 사용.
//   바꾸려면 config.h에 #define SOLENOID_PIN 22 처럼 넣으면 그 값이 우선 적용됨.
//   피해야 할 핀: 6~11(플래시), 34~39(입력 전용), 0/2/5/12/15(부팅 스트래핑)
#ifndef SOLENOID_PIN
#define SOLENOID_PIN 23
#endif
#ifndef SOLENOID_LEDC_CH          // Arduino-ESP32 2.x에서만 사용
#define SOLENOID_LEDC_CH 7        // 모터가 0/1 채널을 쓰므로 다른 타이머의 7번
#endif

constexpr uint32_t SOL_PWM_FREQ  = 20000;  // 20kHz (가청 소음 없음)
constexpr uint8_t  SOL_PWM_BITS  = 8;
constexpr uint32_t SOL_HIT_MS    = 60;     // 처음엔 100%로 당기고
constexpr uint8_t  SOL_HOLD_DUTY = 90;     // 이후 약 35%로 유지 (발열 감소)
constexpr uint32_t SOL_MAX_ON_MS = 3000;   // 이보다 오래 켜져 있으면 강제 해제
constexpr uint32_t SOL_SETTLE_MS = 60;     // 플런저가 끝까지 나가거나 돌아오는 시간
uint32_t tapMs = 150;                      // 한 번 누를 때 유지 시간 (set_servo ms로 변경 가능)

volatile bool solOn = false;
bool solHolding = false;
uint32_t solOnAt = 0;

static void solWrite(uint32_t duty) {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(SOLENOID_PIN, duty);
#else
  ledcWrite(SOLENOID_LEDC_CH, duty);
#endif
}

void solBegin() {
  pinMode(SOLENOID_PIN, OUTPUT);
  digitalWrite(SOLENOID_PIN, LOW);
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcAttach(SOLENOID_PIN, SOL_PWM_FREQ, SOL_PWM_BITS);
#else
  ledcSetup(SOLENOID_LEDC_CH, SOL_PWM_FREQ, SOL_PWM_BITS);
  ledcAttachPin(SOLENOID_PIN, SOLENOID_LEDC_CH);
#endif
  solWrite(0);
}

void solenoidOn() {
  solWrite((1u << SOL_PWM_BITS) - 1);
  solOnAt = millis();
  solHolding = false;
  solOn = true;
}

void solenoidOff() {   // BLE 콜백에서도 호출됨 (비상 정지)
  solWrite(0);
  solOn = false;
  solHolding = false;
}

// =====================================================================
//  BLE
// =====================================================================
#define BLE_DEVICE_NAME  "Touch Bridge"   // 앱 스캔 필터가 "touch bridge"를 찾음
#define APP_SERVICE_UUID "0000FFE0-0000-1000-8000-00805F9B34FB"
#define APP_CHAR_UUID    "0000FFE1-0000-1000-8000-00805F9B34FB"
#define NUS_SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_RX_UUID      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_TX_UUID      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

BLEServer* bleServer = nullptr;
BLECharacteristic* bleIo = nullptr;       // FFE1 (앱)
BLECharacteristic* bleTx = nullptr;       // NUS TX (터미널)
volatile bool bleConnected = false;
volatile bool stopRequested = false;      // BLE 콜백 → loop 로 비상 정지 전달
QueueHandle_t bleLines;


static size_t bleChunk() {
  uint16_t mtu = 23;
  if (bleServer) {
    uint16_t m = bleServer->getPeerMTU(bleServer->getConnId());
    if (m >= 23) mtu = m;
  }
  return mtu - 3;
}

// 앱은 notify 1번 = 메시지 1개로 파싱하므로 MTU 안에서는 절대 자르지 않는다.
// (Android는 앱이 MTU 512를 요청, iOS는 보통 185 → JSON 상태는 180바이트 이하로 유지)
static void bleNotify(BLECharacteristic* c, const char* buf, int n) {
  if (!c) return;
  const int chunk = (int)bleChunk();
  for (int i = 0; i < n; i += chunk) {
    int len = (n - i < chunk) ? (n - i) : chunk;
    c->setValue((uint8_t*)buf + i, len);
    c->notify();
    delay(3);
  }
}

// 시리얼 + BLE(앱 특성, NUS) 모두로 출력. loop 태스크에서만 호출할 것.
void out(const char* fmt, ...) {
  char buf[256];
  va_list ap;
  va_start(ap, fmt);
  int n = vsnprintf(buf, sizeof(buf), fmt, ap);
  va_end(ap);
  if (n <= 0) return;
  if (n >= (int)sizeof(buf)) n = sizeof(buf) - 1;
  Serial.print(buf);
  if (bleConnected) {
    bleNotify(bleIo, buf, n);
    bleNotify(bleTx, buf, n);
  }
}

// ---------------- 페어링 키 / HMAC 세션 (앱 BleSecuritySession 대응) ----------------
Preferences prefs;
String pairKey;
char nonceHex[33] = "";
bool bleAuthed = false;
uint32_t authExpireMs = 0;
constexpr uint32_t AUTH_SESSION_MS = 5UL * 60UL * 1000UL;   // 앱과 동일 5분

bool keyProvisioned() { return pairKey.length() > 0; }
bool bleSessionValid() { return bleAuthed && (int32_t)(authExpireMs - millis()) > 0; }

// 키가 등록된 기기는 BLE로 오는 물리 동작에 유효한 세션이 필요 (시리얼은 항상 허용)
bool physicalAllowed(Source src) {
  return src == SRC_SERIAL || !keyProvisioned() || bleSessionValid();
}

static void toHex(const uint8_t* in, size_t n, char* outHex) {
  static const char* d = "0123456789abcdef";
  for (size_t i = 0; i < n; i++) { outHex[2 * i] = d[in[i] >> 4]; outHex[2 * i + 1] = d[in[i] & 15]; }
  outHex[2 * n] = 0;
}

static void hmacHex(const String& key, const char* msg, char* outHex /*65*/) {
  uint8_t mac[32];
  mbedtls_md_hmac(mbedtls_md_info_from_type(MBEDTLS_MD_SHA256),
                  (const uint8_t*)key.c_str(), key.length(),
                  (const uint8_t*)msg, strlen(msg), mac);
  toHex(mac, 32, outHex);
}

static bool constEq(const char* a, const char* b) {
  size_t la = strlen(a), lb = strlen(b);
  uint8_t diff = la != lb;
  for (size_t i = 0; i < la && i < lb; i++) diff |= (uint8_t)(tolower(a[i]) ^ tolower(b[i]));
  return diff == 0;
}

// ---------------- BLE 콜백 ----------------
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    bleConnected = true;
    bleAuthed = false;
  }
  void onDisconnect(BLEServer* server) override {
    bleConnected = false;
    bleAuthed = false;
    stopRequested = true;          // 앱이 끊기면 진행 중 동작을 멈춤 (앱 안전 계약과 동일)
    server->startAdvertising();
  }
};

class RxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String v = c->getValue().c_str();
    LineMsg m;
    size_t len = 0;

    // JSON은 한 번의 write = 한 메시지
    if (v.length() && v[0] == '{') {
      if (v.indexOf("\"stop\"") >= 0) {   // 비상 정지는 큐를 기다리지 않고 즉시
        motion.stop();
        solenoidOff();
        stopRequested = true;
        xQueueReset(bleLines);           // 정지 전에 도착해 대기 중인 명령은 버림
      }
      for (size_t i = 0; i < v.length() && len < CMD_LINE_MAX - 1; i++)
        if (v[i] != '\r' && v[i] != '\n') m.text[len++] = v[i];
      m.text[len] = 0;
      xQueueSend(bleLines, &m, 0);
      return;
    }

    // 텍스트/G-code: 줄 단위
    for (size_t i = 0; i < v.length(); i++) {
      char ch = v[i];
      if (ch == '!') {
        motion.stop(); solenoidOff(); stopRequested = true;
        xQueueReset(bleLines);
        len = 0;
        continue;
      }
      if (ch == '\r') continue;
      if (ch == '\n') {
        if (len) { m.text[len] = 0; xQueueSend(bleLines, &m, 0); }
        len = 0;
        continue;
      }
      if (len < CMD_LINE_MAX - 1) m.text[len++] = ch;
    }
    if (len) { m.text[len] = 0; xQueueSend(bleLines, &m, 0); }   // 줄바꿈 없이 보내는 앱 대응
  }
};

void bleBegin() {
  bleLines = xQueueCreate(8, sizeof(LineMsg));
  BLEDevice::init(BLE_DEVICE_NAME);
  BLEDevice::setMTU(517);          // 앱 JSON(최대 ~200B)을 한 패킷으로 주고받기 위함
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new ServerCallbacks());
  auto* rxCb = new RxCallbacks();

  // 앱용 FFE0 / FFE1 (write + notify 한 특성)
  BLEService* app = bleServer->createService(APP_SERVICE_UUID);
  bleIo = app->createCharacteristic(
      APP_CHAR_UUID, BLECharacteristic::PROPERTY_WRITE |
                         BLECharacteristic::PROPERTY_WRITE_NR |
                         BLECharacteristic::PROPERTY_NOTIFY);
  bleIo->addDescriptor(new BLE2902());
  bleIo->setCallbacks(rxCb);
  app->start();

  // 디버그용 NUS
  BLEService* nus = bleServer->createService(NUS_SERVICE_UUID);
  bleTx = nus->createCharacteristic(NUS_TX_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  bleTx->addDescriptor(new BLE2902());
  BLECharacteristic* rx = nus->createCharacteristic(
      NUS_RX_UUID, BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  rx->setCallbacks(rxCb);
  nus->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(APP_SERVICE_UUID);   // 앱은 이 UUID 또는 이름으로 기기를 찾음
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
}

// ---------------- 1kHz 제어 태스크 ----------------
void controlTask(void*) {
  TickType_t last = xTaskGetTickCount();
  const TickType_t period = 1;
  int64_t prev = esp_timer_get_time();
  for (;;) {
    vTaskDelayUntil(&last, period);
    int64_t now = esp_timer_get_time();
    float dt = (now - prev) * 1e-6f;
    prev = now;
    dt = constrain(dt, 0.0005f, 0.005f);
    motion.controlStep(dt);
  }
}

// =====================================================================
//  동작 큐
// =====================================================================

constexpr int QMAX = 32;
Step q[QMAX];
int qHead = 0, qCount = 0;

bool qPush(const Step& s) {
  if (qCount >= QMAX) return false;
  q[(qHead + qCount) % QMAX] = s;
  qCount++;
  return true;
}
bool qPop(Step& s) {
  if (!qCount) return false;
  s = q[qHead];
  qHead = (qHead + 1) % QMAX;
  qCount--;
  return true;
}
void qClear() { qHead = qCount = 0; }

bool active = false;
Step cur;
Phase phase;
uint32_t phaseAt = 0, phaseMs = 0;

bool busy() { return active || qCount > 0; }

// G-code 파싱 시점의 "계획 위치" (상대 이동 G91 계산용)
float planX = 0, planY = 0;
bool planValid = false;
void syncPlan() {
  if (!planValid && !busy()) {
    auto st = motion.status();
    planX = st.x;
    planY = st.y;
    planValid = true;
  }
}

// ---------------- positionToken (move_only → press 안전 연결) ----------------
char posToken[17] = "";
bool tokValid = false;
float tokX = 0, tokY = 0, tokTol = 0;

void invalidateToken() { tokValid = false; posToken[0] = 0; }
void issueToken(float x, float y, float tol) {
  uint32_t r[2] = {esp_random(), esp_random()};
  toHex((uint8_t*)r, 8, posToken);
  tokX = x; tokY = y; tokTol = tol;
  tokValid = true;
}

// ---------------- JSON 상태 출력 ----------------
static void sanitizeId(const char* in, char* outId) {
  size_t n = 0;
  for (; *in && n < 47; in++) {
    char c = *in;
    if (isalnum((unsigned char)c) || c == '-' || c == '_' || c == '.' || c == ':') outId[n++] = c;
  }
  outId[n] = 0;
}

void emitState(const char* id, const char* state, const char* extra = "") {
  out("{\"version\":2,\"commandId\":\"%s\",\"state\":\"%s\"%s}\n", id, state, extra);
}

// ---------------- 실행 ----------------
void endActive() { active = false; }

// 실패: 응답 후 남은 큐를 전부 버림 (이동 실패 뒤에 누름이 이어지면 안 됨)
void failActive(const char* jsonState, const char* text) {
  if (active) {
    if (cur.org == ORG_JSON) emitState(cur.id, jsonState);
    else out("FAULT %s\n", text);
  }
  qClear();
  active = false;
  planValid = false;
  invalidateToken();
  solenoidOff();
}

void emergencyStop() {
  stopRequested = false;
  motion.stop();
  solenoidOff();
  qClear();
  if (active && cur.org == ORG_JSON) emitState(cur.id, "STOPPED");
  active = false;
  planValid = false;
  invalidateToken();
}

void beginMove() {
  invalidateToken();
  if (cur.org == ORG_JSON) emitState(cur.id, "MOVING");
  const char* err = motion.moveTo(cur.x, cur.y, cur.f);
  if (err) { failActive("ERROR_LIMIT", err); return; }
  phase = Phase::WAIT_MOTION;
}

void waitFor(uint32_t ms) {
  phase = Phase::WAIT_TIME;
  phaseAt = millis();
  phaseMs = ms;
}

void startStep() {
  active = true;
  switch (cur.type) {
    case StepType::MOVE:
      if (solOn) {                 // 누른 채로 끌고 다니지 않도록 먼저 뗌
        solenoidOff();
        phase = Phase::WAIT_RELEASE;
        phaseAt = millis();
      } else {
        beginMove();
      }
      break;
    case StepType::HOME: {
      invalidateToken();
      solenoidOff();
      if (cur.org == ORG_JSON) emitState(cur.id, "HOMING");
      const char* err = motion.home();
      if (err) { failActive("ERROR_LIMIT", err); return; }
      phase = Phase::WAIT_MOTION;
      break;
    }
    case StepType::SET_ORIGIN:
      motion.setOrigin();
      invalidateToken();
      endActive();
      break;
    case StepType::SOL_DOWN:
      solenoidOn();
      waitFor(SOL_SETTLE_MS);
      break;
    case StepType::SOL_UP:
      solenoidOff();
      waitFor(SOL_SETTLE_MS);
      break;
    case StepType::DWELL:
      waitFor(cur.ms);
      break;
    case StepType::TAP:
      if (cur.org == ORG_JSON) emitState(cur.id, "PRESSING");
      solenoidOn();
      phase = Phase::TAP_HOLD;
      phaseAt = millis();
      phaseMs = cur.ms;
      break;
  }
}

void pump() {
  if (!active) {
    if (qPop(cur)) startStep();
    return;
  }
  const uint32_t t = millis() - phaseAt;
  switch (phase) {
    case Phase::WAIT_RELEASE:
      if (t >= SOL_SETTLE_MS) beginMove();
      break;
    case Phase::WAIT_TIME:
      if (t >= phaseMs) endActive();
      break;
    case Phase::TAP_HOLD:
      if (t >= phaseMs) {
        solenoidOff();
        phase = Phase::TAP_RELEASE;
        phaseAt = millis();
      }
      break;
    case Phase::TAP_RELEASE:
      if (t >= SOL_SETTLE_MS) {
        if (cur.org == ORG_JSON) emitState(cur.id, "COMPLETED");
        else if (cur.org == ORG_TEXT) out("PRESSED\n");
        endActive();
      }
      break;
    case Phase::WAIT_MOTION:
      break;   // 모션 이벤트에서 처리
  }
}

void solService() {
  if (!solOn) return;
  uint32_t t = millis() - solOnAt;
  if (!solHolding && t >= SOL_HIT_MS) {
    solWrite(SOL_HOLD_DUTY);
    solHolding = true;
  }
  if (t >= SOL_MAX_ON_MS) {   // 앱이 Z 상승을 못 보내고 끊긴 경우 등 안전장치
    solenoidOff();
    out("WARN SOLENOID_TIMEOUT\n");
  }
}

// ---------------- 모션 이벤트 ----------------
static void legacyEventText(MotionEvent e) {
  auto st = motion.status();
  switch (e) {
    case MotionEvent::MOVE_DONE:    out("DONE %.2f %.2f\n", st.x, st.y); break;
    case MotionEvent::HOME_DONE:    out("HOMED\n"); break;
    case MotionEvent::STOPPED:      out("STOPPED\n"); break;
    case MotionEvent::FAULT_FOLLOW: out("FAULT FOLLOW_ERROR\n"); break;
    case MotionEvent::FAULT_SETTLE: out("FAULT SETTLE\n"); break;
    case MotionEvent::FAULT_HOME:   out("FAULT HOME_NOT_FOUND\n"); break;
  }
}

void handleEvent(MotionEvent e) {
  const bool waiting = active && phase == Phase::WAIT_MOTION;
  if (!waiting) {               // 큐 밖 동작(M 명령 등) 또는 정지 직후 이벤트
    legacyEventText(e);
    return;
  }

  switch (e) {
    case MotionEvent::MOVE_DONE: {
      if (cur.type != StepType::MOVE) break;
      if (cur.org == ORG_JSON) {
        auto st = motion.status();
        float err = hypotf(st.x - cur.x, st.y - cur.y);
        char extra[160];
        if (err > cur.tol) {
          snprintf(extra, sizeof(extra), ",\"position\":{\"xMm\":%.2f,\"yMm\":%.2f},\"errorMm\":%.3f",
                   st.x, st.y, err);
          emitState(cur.id, "ERROR_POSITION", extra);
          qClear();
          planValid = false;
          endActive();
          break;
        }
        issueToken(cur.x, cur.y, cur.tol);
        snprintf(extra, sizeof(extra),
                 ",\"position\":{\"xMm\":%.2f,\"yMm\":%.2f},\"errorMm\":%.3f,\"positionToken\":\"%s\"",
                 st.x, st.y, err, posToken);
        emitState(cur.id, "POSITIONED", extra);
        emitState(cur.id, "COMPLETED");
      } else if (cur.org == ORG_TEXT) {
        legacyEventText(e);
      }
      endActive();
      break;
    }
    case MotionEvent::HOME_DONE:
      if (cur.type != StepType::HOME) break;
      planValid = false;
      if (cur.org == ORG_JSON) {
        emitState(cur.id, "HOMED", ",\"homed\":true");
        emitState(cur.id, "COMPLETED", ",\"homed\":true");
      } else {
        out("HOMED\n");
      }
      endActive();
      break;
    case MotionEvent::STOPPED:
      emergencyStop();
      out("STOPPED\n");
      break;
    case MotionEvent::FAULT_FOLLOW: failActive("ERROR_STALL", "FOLLOW_ERROR"); break;
    case MotionEvent::FAULT_SETTLE: failActive("ERROR_POSITION", "SETTLE"); break;
    case MotionEvent::FAULT_HOME:   failActive("ERROR_TIMEOUT", "HOME_NOT_FOUND"); break;
  }
}

// =====================================================================
//  명령 처리
// =====================================================================
Step makeStep(StepType t, Origin o) {
  Step s{};
  s.type = t;
  s.org = o;
  return s;
}

bool enqueueMove(float x, float y, float fMmS, Origin o, const char* id = "", float tol = 0) {
  Step s = makeStep(StepType::MOVE, o);
  s.x = x; s.y = y; s.f = fMmS; s.tol = tol;
  strncpy(s.id, id, sizeof(s.id) - 1);
  if (!qPush(s)) return false;
  planX = x; planY = y; planValid = true;
  return true;
}

bool enqueueTap(uint32_t ms, Origin o, const char* id = "") {
  Step s = makeStep(StepType::TAP, o);
  s.ms = ms;
  strncpy(s.id, id, sizeof(s.id) - 1);
  return qPush(s);
}

void printHelp() {
  out("G x y [f] | GT x y [f] | T [ms] | H | S/! | Z | P | M a b [ms] | K kp ki kd kff | ?\n");
  out("G-code: G0/G1 X Y Z F, G4 P, G90/G91, G92 X0 Y0, $H, $$, STOP, BTN_n, SET_GRID\n");
}

void reply(const char* err) {
  if (err) out("ERR %s\n", err);
  else out("OK\n");
}

void printStatus() {
  auto st = motion.status();
  out("STATE %s homed=%d pos=(%.2f, %.2f) ref=(%.2f, %.2f) enc=(%ld, %ld) sol=%d q=%d auth=%s\n",
      motionStateName(st.state), st.homed, st.x, st.y, st.xRef, st.yRef,
      (long)st.countA, (long)st.countB, solOn ? 1 : 0, qCount + (active ? 1 : 0),
      !keyProvisioned() ? "none" : (bleSessionValid() ? "ok" : "locked"));
}

int parseFloats(const char* s, float* outv, int maxN) {
  int n = 0;
  char* end;
  while (n < maxN) {
    float v = strtof(s, &end);
    if (end == s) break;
    outv[n++] = v;
    s = end;
  }
  return n;
}

// ---------------- SET_GRID / BTN_n (구버전 앱 수동 매핑 화면) ----------------
struct Grid { int rows, cols; float ox, oy, px, py; bool set; } grid{};

// ---------------- G-code ----------------
bool gRelative = false;
float gFeedMmS = 0;   // 0 = 펌웨어 기본 속도

// 반환: nullptr = ok, 그 외 에러 문자열
const char* handleGcode(const char* line) {
  // 단어 수집
  float gList[6];
  int gN = 0;
  bool hasX = false, hasY = false, hasZ = false, hasF = false, hasP = false;
  float X = 0, Y = 0, Z = 0, F = 0, P = 0;
  const char* s = line;
  while (*s) {
    char c = toupper(*s);
    if (c == ' ' || c == '\t') { s++; continue; }
    if (c == '(' || c == ';') break;   // 주석
    char* end;
    float v = strtof(s + 1, &end);
    if (end == s + 1) return "BAD_WORD";
    switch (c) {
      case 'G': if (gN < 6) gList[gN++] = v; break;
      case 'X': hasX = true; X = v; break;
      case 'Y': hasY = true; Y = v; break;
      case 'Z': hasZ = true; Z = v; break;
      case 'F': hasF = true; F = v; break;
      case 'P': hasP = true; P = v; break;
      case 'N': break;                  // 줄 번호 무시
      default: return "UNSUPPORTED_WORD";
    }
    s = end;
  }
  // G-code F는 mm/min. Z(솔레노이드) 줄의 느린 F150이 XY 속도를 덮지 않도록
  // XY 이동이 있는 줄에서만 반영한다.
  if (hasF && F > 0 && (hasX || hasY)) gFeedMmS = F / 60.0f;

  for (int i = 0; i < gN; i++) {
    const float g = gList[i];
    if (fabsf(g - 90) < 0.01f) gRelative = false;
    else if (fabsf(g - 91) < 0.01f) gRelative = true;
    else if (fabsf(g - 21) < 0.01f) { /* mm, 기본 */ }
    else if (fabsf(g - 20) < 0.01f) return "INCH_UNSUPPORTED";
    else if (fabsf(g - 92.1f) < 0.01f) { /* 오프셋 취소: 별도 오프셋 없음 */ }
    else if (fabsf(g - 92) < 0.01f) {
      if ((hasX && X != 0) || (hasY && Y != 0)) return "G92_ONLY_ZERO";
      if (!hasX && !hasY) continue;
      // 앱 음성 경로는 누를 때마다 "G92 X0 Y0"(현재 위치 = 원점)을 보낸다.
      // 비상 정지로 중간에 멈춘 뒤라면 엉뚱한 곳이 원점이 되어 다른 버튼을
      // 누르게 되므로, 원점 복귀(H/$H)로 기준이 잡힌 상태에서는 무시한다.
      if (motion.status().homed) return nullptr;
      if (!qPush(makeStep(StepType::SET_ORIGIN, ORG_GCODE))) return "QUEUE_FULL";
      planX = planY = 0;
      planValid = true;
      return nullptr;                   // 같은 줄의 X/Y는 G92 인자로 소비됨
    }
    else if (fabsf(g - 4) < 0.01f) {
      Step d = makeStep(StepType::DWELL, ORG_GCODE);
      d.ms = (uint32_t)(constrain(hasP ? P : 0.0f, 0.0f, 10.0f) * 1000.0f);   // GRBL: P = 초
      if (!qPush(d)) return "QUEUE_FULL";
    }
    else if (fabsf(g - 0) < 0.01f || fabsf(g - 1) < 0.01f) {
      // Z → 솔레노이드. 상대 모드는 부호, 절대 모드는 0보다 작으면 누름
      bool zDown = false, zUp = false;
      if (hasZ) {
        if (gRelative) { zDown = Z < 0; zUp = Z > 0; }
        else           { zDown = Z < 0; zUp = !zDown; }
      }
      if (zUp && !qPush(makeStep(StepType::SOL_UP, ORG_GCODE))) return "QUEUE_FULL";
      if (hasX || hasY) {
        syncPlan();
        float tx = hasX ? (gRelative ? planX + X : X) : planX;
        float ty = hasY ? (gRelative ? planY + Y : Y) : planY;
        if (!enqueueMove(tx, ty, gFeedMmS, ORG_GCODE)) return "QUEUE_FULL";
      }
      if (zDown && !qPush(makeStep(StepType::SOL_DOWN, ORG_GCODE))) return "QUEUE_FULL";
    }
    else return "UNSUPPORTED_G";
  }
  return nullptr;
}

// ---------------- JSON (앱 v2 + 인증 + 레거시 액션) ----------------
void handleJson(const char* line, Source src) {
  JsonDocument doc;
  if (deserializeJson(doc, line)) { out("ERROR:JSON\n"); return; }
  const char* action = doc["action"] | "";
  char id[48];
  sanitizeId(doc["commandId"] | "", id);
  const bool v2 = (doc["version"] | 0) == 2 && id[0];

  // ---- 인증 (응답은 앱이 첫 notify로 받는 평문) ----
  if (!strcmp(action, "challenge")) {
    uint8_t r[16];
    for (int i = 0; i < 16; i += 4) { uint32_t x = esp_random(); memcpy(r + i, &x, 4); }
    toHex(r, 16, nonceHex);
    out("NONCE:%s\n", nonceHex);
    return;
  }
  if (!strcmp(action, "auth")) {
    const char* mac = doc["mac"] | "";
    char expect[65];
    bool ok = keyProvisioned() && nonceHex[0];
    if (ok) { hmacHex(pairKey, nonceHex, expect); ok = constEq(mac, expect); }
    nonceHex[0] = 0;                    // nonce는 1회용
    if (ok && src == SRC_BLE) { bleAuthed = true; authExpireMs = millis() + AUTH_SESSION_MS; }
    out(ok ? "AUTH_OK\n" : "AUTH_FAIL\n");
    return;
  }
  if (!strcmp(action, "provision")) {
    const char* secret = doc["secret"] | "";
    // 키가 이미 있으면 유효 세션(또는 USB 시리얼)에서만 교체 가능
    if (keyProvisioned() && !physicalAllowed(src)) { out("PROVISION_DENIED\n"); return; }
    if (strlen(secret) < 8) { out("PROVISION_TOO_SHORT\n"); return; }
    pairKey = secret;
    prefs.putString("pairkey", pairKey);
    bleAuthed = false;
    out("PROVISION_OK\n");
    return;
  }

  // ---- 정지: 인증 없이 항상 ----
  if (!strcmp(action, "stop")) {
    emergencyStop();
    if (id[0]) emitState(id, "STOPPED");
    else out("STOPPED\n");
    return;
  }

  if (!strcmp(action, "status")) {
    auto st = motion.status();
    if (v2) {
      char extra[120];
      snprintf(extra, sizeof(extra), ",\"homed\":%s,\"position\":{\"xMm\":%.2f,\"yMm\":%.2f}",
               st.homed ? "true" : "false", st.x, st.y);
      emitState(id, "COMPLETED", extra);
    } else {
      printStatus();
    }
    return;
  }

  if (!strcmp(action, "get_servo")) {   // 레거시: 서보 대신 솔레노이드 누름 시간
    out("SERVO up=0 down=1 ms=%u\n", (unsigned)tapMs);
    return;
  }

  // ---- 이하 물리 동작: 인증 필요 ----
  if (!physicalAllowed(src)) {
    if (v2) emitState(id, "ERROR_PROTOCOL", ",\"message\":\"AUTH_REQUIRED\"");
    else out("ERROR:AUTH_REQUIRED\n");
    return;
  }

  if (!strcmp(action, "set_servo")) {
    tapMs = constrain((int)(doc["ms"] | (int)tapMs), 30, 2000);
    out("OK\n");
    return;
  }

  if (!strcmp(action, "home")) {
    if (!v2) {                          // 구버전 sendHoming(): commandId 없음
      qPush(makeStep(StepType::HOME, ORG_TEXT));
      out("OK\n");
      return;
    }
    if (busy()) { emitState(id, "ERROR_PROTOCOL", ",\"message\":\"BUSY\""); return; }
    emitState(id, "RECEIVED");
    Step s = makeStep(StepType::HOME, ORG_JSON);
    strncpy(s.id, id, sizeof(s.id) - 1);
    qPush(s);
    return;
  }

  if (!v2) { out("ERROR:UNKNOWN_ACTION\n"); return; }

  if (!strcmp(action, "move_only")) {
    JsonVariant tgt = doc["target"];
    if (!tgt["xMm"].is<float>() || !tgt["yMm"].is<float>()) { emitState(id, "ERROR_PROTOCOL"); return; }
    float x = tgt["xMm"], y = tgt["yMm"];
    float tol = doc["toleranceMm"] | 0.7f;
    if (!isfinite(x) || !isfinite(y) || x < 0 || y < 0 || !(tol > 0)) { emitState(id, "ERROR_LIMIT"); return; }
    if (!motion.status().homed) { emitState(id, "ERROR_NOT_HOMED"); return; }
    if (busy()) { emitState(id, "ERROR_PROTOCOL", ",\"message\":\"BUSY\""); return; }
    emitState(id, "RECEIVED");
    enqueueMove(x, y, 0, ORG_JSON, id, tol);
    return;
  }

  if (!strcmp(action, "press")) {
    const char* tok = doc["positionToken"] | "";
    bool ok = tokValid && tok[0] && !strcmp(tok, posToken) && !busy() && !solOn;
    if (ok) {                           // 토큰 발급 이후 위치가 밀렸는지 재확인
      auto st = motion.status();
      ok = hypotf(st.x - tokX, st.y - tokY) <= tokTol;
    }
    if (!ok) { invalidateToken(); emitState(id, "ERROR_INVALID_TOKEN"); return; }
    invalidateToken();                  // 토큰 1회용: 다시 누르려면 다시 이동
    emitState(id, "RECEIVED");
    enqueueTap(tapMs, ORG_JSON, id);
    return;
  }

  emitState(id, "ERROR_PROTOCOL", ",\"message\":\"UNKNOWN_ACTION\"");
}

// ---------------- 한 줄 분배 ----------------
static bool isWord(const char* line, const char* w) {   // 대소문자 무시, 뒤가 공백/끝
  size_t n = strlen(w);
  return !strncasecmp(line, w, n) && (line[n] == 0 || line[n] == ' ');
}

void handleLine(char* line, Source src) {
  while (*line == ' ') line++;
  if (!*line) return;

  if (line[0] == '{') { handleJson(line, src); return; }

  // ---- 인증 없이 허용되는 명령 ----
  if (isWord(line, "STOP") || isWord(line, "S") || isWord(line, "!")) {
    emergencyStop();
    out("STOPPED\n");
    return;
  }
  if (isWord(line, "P") || isWord(line, "$$")) { printStatus(); return; }
  if (isWord(line, "?")) { printHelp(); return; }
  if (isWord(line, "KEYRESET")) {
    if (src != SRC_SERIAL) { out("ERR SERIAL_ONLY\n"); return; }
    pairKey = "";
    prefs.remove("pairkey");
    bleAuthed = false;
    out("OK key cleared\n");
    return;
  }

  if (!physicalAllowed(src)) { out("ERROR:AUTH_REQUIRED\n"); return; }

  float a[4];

  // ---- GRBL 호환 ----
  if (isWord(line, "$H")) { qPush(makeStep(StepType::HOME, ORG_GCODE)); out("ok\n"); return; }
  if (isWord(line, "$X")) { out("ok\n"); return; }
  if (!strncasecmp(line, "SET_GRID", 8)) {
    float g[6];
    if (parseFloats(line + 8, g, 6) < 6 || g[0] < 1 || g[1] < 1) {
      out("ERR USAGE: SET_GRID rows cols ox10 oy10 px10 py10\n");
      return;
    }
    grid = {(int)g[0], (int)g[1], g[2] / 10, g[3] / 10, g[4] / 10, g[5] / 10, true};
    out("GRID_CONFIG_UPDATED\n");
    return;
  }
  if (!strncasecmp(line, "BTN_", 4)) {
    int btn = atoi(line + 4);
    if (!grid.set) { out("ERR GRID_NOT_SET\n"); return; }
    if (btn < 1 || btn > grid.rows * grid.cols) { out("ERR BTN_RANGE\n"); return; }
    int row = (btn - 1) / grid.cols, col = (btn - 1) % grid.cols;
    float x = grid.ox + col * grid.px, y = grid.oy + row * grid.py;
    if (!enqueueMove(x, y, 0, ORG_TEXT) || !enqueueTap(tapMs, ORG_TEXT)) { out("ERR QUEUE_FULL\n"); return; }
    out("OK\n");
    return;
  }
  if ((line[0] == 'G' || line[0] == 'g') && isdigit((unsigned char)line[1])) {
    const char* err = handleGcode(line);
    if (err) out("error:%s\n", err);
    else out("ok\n");
    return;
  }

  // ---- 기존 텍스트 명령 ----
  if (!strncasecmp(line, "GT", 2) && (line[2] == ' ' || line[2] == 0)) {
    int n = parseFloats(line + 2, a, 3);
    if (n < 2) { reply("USAGE: GT x y [f]"); return; }
    if (!enqueueMove(a[0], a[1], n >= 3 ? a[2] : 0, ORG_TEXT) || !enqueueTap(tapMs, ORG_TEXT)) {
      reply("QUEUE_FULL");
      return;
    }
    reply(nullptr);
    return;
  }

  const char cmd = toupper(line[0]);
  if (line[1] != 0 && line[1] != ' ') { reply("UNKNOWN"); return; }
  const int n = parseFloats(line + 1, a, 4);

  switch (cmd) {
    case 'G':
      if (n < 2) { reply("USAGE: G x y [f]"); return; }
      reply(enqueueMove(a[0], a[1], n >= 3 ? a[2] : 0, ORG_TEXT) ? nullptr : "QUEUE_FULL");
      break;
    case 'T':
      reply(enqueueTap(n >= 1 ? (uint32_t)constrain(a[0], 30.0f, 2000.0f) : tapMs, ORG_TEXT)
                ? nullptr : "QUEUE_FULL");
      break;
    case 'H':
      reply(qPush(makeStep(StepType::HOME, ORG_TEXT)) ? nullptr : "QUEUE_FULL");
      break;
    case 'Z':
      reply(qPush(makeStep(StepType::SET_ORIGIN, ORG_TEXT)) ? nullptr : "QUEUE_FULL");
      planX = planY = 0;
      planValid = true;
      break;
    case 'M':
      if (n < 2) { reply("USAGE: M a b [ms]"); return; }
      if (busy()) { reply("BUSY"); return; }
      planValid = false;
      invalidateToken();
      reply(motion.rawPwm(a[0], a[1], n >= 3 ? (uint32_t)a[2] : 500));
      break;
    case 'K':
      if (n < 4) { reply("USAGE: K kp ki kd kff"); return; }
      motion.setGains(a[0], a[1], a[2], a[3]);
      reply(nullptr);
      break;
    default:
      reply("UNKNOWN");
      break;
  }
}

void pollSerial() {
  static char buf[CMD_LINE_MAX];
  static uint16_t len = 0;
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '!') { motion.stop(); solenoidOff(); stopRequested = true; len = 0; continue; }
    if (c == '\r') continue;
    if (c == '\n') { buf[len] = 0; handleLine(buf, SRC_SERIAL); len = 0; continue; }
    if (len < sizeof(buf) - 1) buf[len++] = c;
  }
}

// ---------------------------------------------------------------------
void setup() {
  solBegin();                 // 가장 먼저: 부팅 중 솔레노이드가 켜지지 않게
  Serial.begin(115200);
  delay(200);

  prefs.begin("touchbridge", false);
  pairKey = prefs.getString("pairkey", "");

  motionEvents = xQueueCreate(16, sizeof(MotionEvent));
  motion.begin(motionEvents);
  xTaskCreatePinnedToCore(controlTask, "corexy", 4096, nullptr,
                          configMAX_PRIORITIES - 2, nullptr, 1);
  bleBegin();
  out("Touch Bridge CoreXY v3 ready (BLE: " BLE_DEVICE_NAME ", key=%s)\n",
      keyProvisioned() ? "set" : "none");
  printHelp();
}

void loop() {
  if (stopRequested) emergencyStop();

  MotionEvent e;
  while (xQueueReceive(motionEvents, &e, 0) == pdTRUE) handleEvent(e);

  LineMsg m;
  while (xQueueReceive(bleLines, &m, 0) == pdTRUE) {
    if (stopRequested) emergencyStop();
    handleLine(m.text, SRC_BLE);
  }

  pollSerial();
  pump();
  solService();
  delay(1);
}
