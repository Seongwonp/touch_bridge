// =====================================================================
//  Touch Bridge - CT 노드 수신기 (실기기에서 실행한 적 없음)
//  CT_LINK_ENABLED가 1일 때만 포함한다.
//
//  CT 노드가 1초마다 보내는 {"t":"ct","w":..,"a":..,"seq":..} 줄을 loop()에서 읽어
//  5초 이동 평균과 ON/OFF/UNKNOWN 상태를 만든다. ON/OFF는 측정에서 쓴 유지 시간
//  판정(CT_ON_WATTS 이상 CT_ON_HOLD_MS → 작동, CT_OFF_WATTS 이하 CT_OFF_HOLD_MS → 종료)이다.
//  대기 없이 도착한 바이트만 처리해 모션 루프와 BLE를 막지 않는다.
//
//  표시 전용이다. 안전 판단(정지, 누름 허용, 완료 판정)에 쓰지 말 것.
// =====================================================================
#pragma once
#include <Arduino.h>
#include <ArduinoJson.h>
#include <math.h>
#include <string.h>
#include "config.h"

namespace ctlink {

enum class State : uint8_t { UNKNOWN, OFF, ON };

struct Report {
  State state;
  bool  hasAvg;   // UNKNOWN이면 false. 평균이 없을 때 0W로 대신하지 않는다
  float avgW;
};

struct Sample {
  uint32_t atMs;
  float    w;
};

constexpr int kSampleSlots = 8;   // 1초 주기 보고의 5초 창보다 넉넉하게

static char     lineBuf[CT_LINE_MAX + 1];
static size_t   lineLen = 0;
static bool     lineOverflow = false;
static Sample   samples[kSampleSlots];
static int      sampleHead = 0;
static int      sampleCount = 0;
static bool     everReceived = false;
static uint32_t lastRxMs = 0;
static uint32_t lastEmitMs = 0;
// 유지 시간 판정 상태. 두 문턱 사이에서는 직전 판정을 유지한다(켜짐·꺼짐 깜빡임 방지).
static State    judged = State::OFF;
static bool     above = false, below = false;
static uint32_t aboveSince = 0, belowSince = 0;

inline void begin() {
  Serial2.setRxBufferSize(CT_LINK_RX_BUFFER_BYTES);
  // 기본 핀 16/17은 엔코더다. 반드시 핀을 지정해서 연다.
  Serial2.begin(CT_LINK_BAUD, SERIAL_8N1, PIN_CT_LINK_RX, PIN_CT_LINK_TX);
  lastEmitMs = millis();
}

inline void addSample(uint32_t now, float w) {
  samples[sampleHead] = {now, w};
  sampleHead = (sampleHead + 1) % kSampleSlots;
  if (sampleCount < kSampleSlots) sampleCount++;
  lastRxMs = now;
  everReceived = true;

  if (w >= CT_ON_WATTS) {
    if (!above) { above = true; aboveSince = now; }
  } else {
    above = false;
  }
  if (w <= CT_OFF_WATTS) {
    if (!below) { below = true; belowSince = now; }
  } else {
    below = false;
  }
  if (above && now - aboveSince >= CT_ON_HOLD_MS) judged = State::ON;
  if (below && now - belowSince >= CT_OFF_HOLD_MS) judged = State::OFF;
}

// 잘못된 줄은 버리고 신선도도 갱신하지 않는다.
inline void parseLine(char* line, size_t len, uint32_t now) {
  JsonDocument doc;
  if (deserializeJson(doc, line, len)) return;
  const char* t = doc["t"];
  if (!t || strcmp(t, "ct") != 0) return;
  JsonVariant wv = doc["w"];
  if (!wv.is<float>()) return;
  const float w = wv.as<float>();
  if (!isfinite(w) || w < 0.0f) return;
  addSample(now, w);
}

// loop()에서 호출한다. 한 번에 CT_POLL_BUDGET 바이트까지만 처리한다.
inline void poll() {
  int budget = CT_POLL_BUDGET;
  while (budget-- > 0 && Serial2.available() > 0) {
    const int c = Serial2.read();
    if (c < 0) break;
    if (c == '\n') {
      if (!lineOverflow && lineLen > 0) {
        lineBuf[lineLen] = '\0';
        parseLine(lineBuf, lineLen, millis());
      }
      lineLen = 0;
      lineOverflow = false;
    } else if (c == '\r') {
      continue;
    } else if (lineLen < CT_LINE_MAX) {
      lineBuf[lineLen++] = static_cast<char>(c);
    } else {
      lineOverflow = true;   // 줄바꿈까지 버린다
    }
  }
}

inline Report current(uint32_t now) {
  if (!everReceived || now - lastRxMs > CT_STALE_MS) return {State::UNKNOWN, false, 0.0f};
  float sum = 0.0f;
  int n = 0;
  for (int i = 0; i < sampleCount; i++) {
    if (now - samples[i].atMs <= CT_AVG_WINDOW_MS) {
      sum += samples[i].w;
      n++;
    }
  }
  if (n == 0) return {State::UNKNOWN, false, 0.0f};
  const float avg = sum / n;
  return {judged, true, avg};
}

// 보고할 시각이면 true.
inline bool takeReport(Report& r) {
  const uint32_t now = millis();
  if (now - lastEmitMs < CT_EMIT_MS) return false;
  lastEmitMs = now;
  r = current(now);
  return true;
}

inline const char* stateName(State s) {
  switch (s) {
    case State::ON:  return "on";
    case State::OFF: return "off";
    default:         return "unknown";
  }
}

}  // namespace ctlink
