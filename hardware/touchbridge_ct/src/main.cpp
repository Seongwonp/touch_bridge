// touchbridge_ct — SEN0211 전력 측정 노드. 실기기에서 실행한 적 없다.
//
// 샘플링: esp_timer가 SAMPLE_HZ로 깨우는 전용 태스크가 CT를 읽어 1초 창에 누적하고, 창이 차면
//   전력 추정을 우편함에 넣는다. 시리얼에는 쓰지 않는다.
// loop: 우편함의 값을 한 줄 JSON으로 보낸다. 선(Serial2)과 무선(ESP-NOW 브로드캐스트)에 같은 줄을
//   보내므로 모터 ESP32는 어느 쪽으로든 받을 수 있다.
//   {"t":"ct","w":<float>,"a":<float>,"seq":<n>}
// 창 샘플이 모자라거나 CT 초기화에 실패하면 보내지 않는다. 받는 쪽은 끊김을 "모름"으로 처리한다.
// 0 W를 지어내지 않는다.
#include <Arduino.h>
#include <esp_task_wdt.h>
#include <esp_timer.h>
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>

#include "config.h"
#include "ct.h"

namespace {

bool g_ct_ok = false;
portMUX_TYPE g_mail_mux = portMUX_INITIALIZER_UNLOCKED;
PowerReport g_mail;
bool g_mail_full = false;

StaticTask_t g_tcb;
StackType_t g_stack[SAMPLE_TASK_STACK];
TaskHandle_t g_task = nullptr;
esp_timer_handle_t g_timer = nullptr;

void on_sample_timer(void*) {
  if (g_task != nullptr) xTaskNotifyGive(g_task);
}

void sample_task(void*) {
  ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
  esp_task_wdt_add(nullptr);
  CtWindow windows[OUTLET_CT_CHANNELS];
  ct_window_reset(&windows[0]);
  uint32_t seq = 0;
  uint32_t ticks = 0;
  const uint32_t per_window = SAMPLE_HZ / REPORT_HZ;
  const uint32_t expected = ct_expected_samples(per_window);
  for (;;) {
    if (g_ct_ok) ct_sample_tick(windows);
    if (++ticks >= per_window) {
      PowerReport report;
      const bool enough = windows[0].n * 100u >= expected * CT_MIN_WINDOW_PCT;
      if (g_ct_ok && !enough) {
        ++seq;  // 받는 쪽이 빠짐을 볼 수 있게 번호만 늘린다
      } else if (g_ct_ok && ct_window_finish(windows[0], 0, &report)) {
        report.t_ms = millis();
        report.seq = seq++;
        portENTER_CRITICAL(&g_mail_mux);
        g_mail = report;  // loop가 못 가져갔으면 최신 값으로 덮어쓴다
        g_mail_full = true;
        portEXIT_CRITICAL(&g_mail_mux);
      }
      ct_window_reset(&windows[0]);
      ticks = 0;
    }
    esp_task_wdt_reset();
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
  }
}

void setup_task_watchdog() {
  esp_task_wdt_config_t cfg = {};
  cfg.timeout_ms = MCU_TASK_WDT_MS;
  cfg.idle_core_mask = (1u << 0);
  cfg.trigger_panic = true;
  if (esp_task_wdt_reconfigure(&cfg) == ESP_ERR_INVALID_STATE) esp_task_wdt_init(&cfg);
  esp_task_wdt_add(nullptr);
}

bool start_sampling() {
  g_task = xTaskCreateStaticPinnedToCore(sample_task, "ct_smp", SAMPLE_TASK_STACK, nullptr,
                                         SAMPLE_TASK_PRIORITY, g_stack, &g_tcb, SAMPLE_TASK_CORE);
  if (g_task == nullptr) return false;
  esp_timer_create_args_t args = {};
  args.callback = on_sample_timer;
  args.name = "ct_smp";
  if (esp_timer_create(&args, &g_timer) != ESP_OK) return false;
  return esp_timer_start_periodic(g_timer, SAMPLE_PERIOD_US) == ESP_OK;
}

void send_report(const PowerReport& r) {
  char line[CT_LINE_MAX];
  const int n = snprintf(line, sizeof(line), "{\"t\":\"ct\",\"w\":%.1f,\"a\":%.2f,\"seq\":%lu}\n",
                         r.watts, r.irms_a, static_cast<unsigned long>(r.seq));
  if (n <= 0 || n >= static_cast<int>(sizeof(line))) return;
  Serial2.write(reinterpret_cast<const uint8_t*>(line), n);
  Serial.write(reinterpret_cast<const uint8_t*>(line), n);
#if CT_LINK_ESPNOW
  static const uint8_t kBroadcast[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
  esp_now_send(kBroadcast, reinterpret_cast<const uint8_t*>(line), n);  // 실패해도 다음 초에 다시 보낸다
#endif
}

#if CT_LINK_ESPNOW
// 공유기에 붙지 않고 고정 채널에서 브로드캐스트한다. 받는 쪽도 같은 채널이어야 한다.
bool start_espnow() {
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  esp_wifi_set_channel(CT_ESPNOW_CHANNEL, WIFI_SECOND_CHAN_NONE);
  if (esp_now_init() != ESP_OK) return false;
  esp_now_peer_info_t peer = {};
  memset(peer.peer_addr, 0xFF, 6);
  peer.channel = CT_ESPNOW_CHANNEL;
  peer.encrypt = false;
  return esp_now_add_peer(&peer) == ESP_OK;
}
#endif

}  // namespace

void setup() {
  Serial.setTxBufferSize(DEBUG_TX_BUFFER_BYTES);
  Serial.begin(DEBUG_SERIAL_BAUD);
  Serial2.setTxBufferSize(CT_LINK_TX_BUFFER_BYTES);
  Serial2.begin(CT_LINK_BAUD, SERIAL_8N1, PIN_CT_LINK_RX, PIN_CT_LINK_TX);
  g_ct_ok = ct_init();
#if CT_LINK_ESPNOW
  if (!start_espnow()) Serial.println("touchbridge_ct: ESP-NOW start failed (wire only)");
#endif
  setup_task_watchdog();
  if (!start_sampling()) {
    Serial.println("touchbridge_ct: sampling start failed");
    Serial.flush();
    esp_restart();
  }
  Serial.printf("touchbridge_ct ready ct=%s ok=%d\n", ct_source_name(), g_ct_ok ? 1 : 0);
}

void loop() {
  PowerReport report;
  bool have = false;
  portENTER_CRITICAL(&g_mail_mux);
  if (g_mail_full) {
    report = g_mail;
    g_mail_full = false;
    have = true;
  }
  portEXIT_CRITICAL(&g_mail_mux);
  if (have) send_report(report);
  esp_task_wdt_reset();
  vTaskDelay(1);
}
