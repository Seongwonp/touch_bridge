#pragma once
// touchbridge_ct 설정. 보정 값은 측정값이 아니라 기본값이며, 이 노드와 대상 가전으로 재야 한다.

// ─── CT 입력 선택(platformio.ini env가 정한다) ───────────────────────────────
// ct.cpp를 수정하지 않고 쓰기 위해 원본의 선택 매크로를 유지한다. 이 노드는 내장 ADC만 쓴다.
#define OUTLET_CT_ADS1115 1
#define OUTLET_CT_ESP32_ADC 2
#ifndef OUTLET_CT_SOURCE
#define OUTLET_CT_SOURCE OUTLET_CT_ESP32_ADC
#endif

// ─── CT 채널 ────────────────────────────────────────────────────────────────
// 보고 형식이 값 하나이므로 한 채널(GPIO36)만 읽는다. GPIO39는 쓰지 않는다.
#define OUTLET_CT_CHANNELS     1
#define OUTLET_CT_MAX_CHANNELS 4       // 아래 채널별 표의 길이

// ─── 모터 ESP32 링크(Serial2, 3.3V UART) ────────────────────────────────────
#define CT_LINK_BAUD           115200
// 무선(ESP-NOW) 전송. 선과 함께 보낸다. 채널은 모터 ESP32의 CT_ESPNOW_CHANNEL과 같아야 한다.
#define CT_LINK_ESPNOW         1
#define CT_ESPNOW_CHANNEL      1
#define PIN_CT_LINK_TX         17      // → 모터 ESP32 GPIO21(RX)
#define PIN_CT_LINK_RX         16      // ← 모터 ESP32 GPIO22(TX). 예비선, 받은 데이터는 읽지 않는다
#define CT_LINK_TX_BUFFER_BYTES 256    // 버퍼를 두어 쓰기가 샘플링·워치독을 막지 않게 한다
#define CT_LINE_MAX            64      // 보고 한 줄 최대 바이트

// ─── USB 시리얼(점검용) ─────────────────────────────────────────────────────
#define DEBUG_SERIAL_BAUD      115200
#define DEBUG_TX_BUFFER_BYTES  512

// MCU 태스크 워치독: loop·샘플링 태스크가 이 시간 동안 돌지 않으면 패닉 → 재부팅.
#define MCU_TASK_WDT_MS        1000

// ─── 샘플링 ──────────────────────────────────────────────────────────────────
#define SAMPLE_HZ              2000
#define SAMPLE_PERIOD_US       (1000000 / SAMPLE_HZ)
#define SAMPLE_TASK_PRIORITY   5
#define SAMPLE_TASK_CORE       1
#define SAMPLE_TASK_STACK      4096
#define REPORT_HZ              1       // 창 하나 = 1초
// 창 샘플이 기대치의 이 비율(%) 미만이면 보고하지 않는다(샘플 몇 개로 0 W처럼 보이지 않게).
#define CT_MIN_WINDOW_PCT      50

// ─── CT 보정(채널별, 전부 측정 필요) ─────────────────────────────────────────
// 표 길이는 OUTLET_CT_MAX_CHANNELS이고 쓰는 것은 앞 칸이다. CT_AMPS_PER_VOLT_CH는 내장 ADC 빌드에서 쓰지 않는다.
#define CT_AMPS_PER_VOLT_CH    {30.0f, 30.0f, 30.0f, 30.0f}
#define CT_CAL_GAIN_CH         {1.0f, 1.0f, 1.0f, 1.0f}   // 아는 부하로 맞춘다. 1.0 = 보정 안 함
#define CT_NOISE_FLOOR_A_CH    {0.0f, 0.0f, 0.0f, 0.0f}
#define MAINS_VRMS_EST         220.0f                     // 재지 않은 추정 전압
#define POWER_FACTOR_EST_CH    {1.0f, 1.0f, 1.0f, 1.0f}   // 저항성 부하 가정

// ─── ESP32 내장 ADC ──────────────────────────────────────────────────────────
// ADC1만 쓴다(ADC2는 무선과 충돌). 표의 두 번째 칸은 ct.cpp 배열 길이를 맞추기 위한 값이다.
#define PIN_CT_ADC_CH          {36, 39}
#define OUTLET_CT_ADC_MAX_CHANNELS 2

// ─── 정적 검사 ───────────────────────────────────────────────────────────────
#if OUTLET_CT_SOURCE != OUTLET_CT_ESP32_ADC
#error "touchbridge_ct는 내장 ADC 빌드(OUTLET_CT_SOURCE=2)만 지원한다"
#endif
#if (SAMPLE_HZ % REPORT_HZ) != 0
#error "REPORT_HZ는 SAMPLE_HZ를 나누어떨어지게 해야 한다"
#endif
