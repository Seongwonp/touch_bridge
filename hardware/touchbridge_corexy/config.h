// =====================================================================
//  Touch Bridge - CoreXY 모션 설정
//  하드웨어: ESP32 DevKit + JMOD-MOTOR-1(TB6612FNG) + DFRobot FIT0482 x2
// =====================================================================
#pragma once
#include <Arduino.h>

// ---------------- 핀 배치 (ESP32 DevKit V1 기준) ----------------
// 스트래핑 핀(0, 2, 12, 15)과 입력 전용 핀(34~39)은 출력에 쓰지 않음
constexpr int PIN_STBY  = 4;    // TB6612 STBY (HIGH = 동작)

constexpr int PIN_A_PWM = 25;   // 모터 A (CoreXY 왼쪽 모터)
constexpr int PIN_A_IN1 = 26;
constexpr int PIN_A_IN2 = 27;

constexpr int PIN_B_PWM = 32;   // 모터 B (CoreXY 오른쪽 모터)
constexpr int PIN_B_IN1 = 33;
constexpr int PIN_B_IN2 = 13;

constexpr int PIN_ENC_A_A = 16; // 모터 A 엔코더 A/B상
constexpr int PIN_ENC_A_B = 17;
constexpr int PIN_ENC_B_A = 18; // 모터 B 엔코더 A/B상
constexpr int PIN_ENC_B_B = 19;

// 리밋 스위치(선택). false면 스톨(벽에 닿음) 감지로 원점 복귀
constexpr bool USE_LIMIT_SWITCHES = false;
constexpr int  PIN_LIMIT_X = 30;  // NO 스위치, GND로 단락 = 눌림
constexpr int  PIN_LIMIT_Y = 100;

// ---------------- CT 노드 수신 (기본 꺼짐) ----------------
// 배선 전에는 0으로 둔다. 0이면 UART를 열지 않아 기존 빌드와 동작이 같다.
// 표시 전용 데이터이며 어떤 안전 판단에도 쓰지 않는다.
#define CT_LINK_ENABLED 0

// Serial2 기본 핀 16/17은 위의 엔코더 입력이므로 빈 핀으로 옮긴다.
constexpr int      PIN_CT_LINK_RX = 21;  // <- CT 노드 GPIO17(TX)
constexpr int      PIN_CT_LINK_TX = 22;  // -> CT 노드 GPIO16(RX), 예비선
constexpr uint32_t CT_LINK_BAUD   = 115200;
constexpr size_t   CT_LINK_RX_BUFFER_BYTES = 256;
constexpr size_t   CT_LINE_MAX     = 96;      // 넘는 줄은 버린다
constexpr int      CT_POLL_BUDGET  = 64;      // loop 1회당 처리할 최대 바이트
constexpr uint32_t CT_AVG_WINDOW_MS = 5000;   // 이동 평균 창
constexpr uint32_t CT_STALE_MS      = 3000;   // 이보다 오래 끊기면 UNKNOWN (0W로 보지 않음)
constexpr uint32_t CT_EMIT_MS       = 1000;   // 앱 보고 주기
// 자리표시자: 측정값이 아니다. 대상 가전마다 대기 전력과 동작 전력을 재서 정해야 한다.
// 작동 판정: CT_ON_WATTS 이상이 CT_ON_HOLD_MS 동안 이어지면 작동, CT_OFF_WATTS 이하가
// CT_OFF_HOLD_MS 동안 이어지면 종료. 2026-11-02 전자레인지 1분 가열 측정(별도 ESP32
// 측정 장치)에서 이 기준으로 설정 60초를 60.7초로 판정했다. 가전마다 다시 잴 수 있다.
constexpr float    CT_ON_WATTS      = 100.0f;
constexpr float    CT_OFF_WATTS     = 15.0f;
constexpr uint32_t CT_ON_HOLD_MS    = 5000;
constexpr uint32_t CT_OFF_HOLD_MS   = 3000;

// ---------------- 방향 보정 ----------------
// 'M' 명령으로 시험해서 맞춤 (README.md의 '처음 켤 때 순서' 참고)
constexpr bool MOTOR_A_INVERT = false;
constexpr bool MOTOR_B_INVERT = false;
constexpr bool ENC_A_INVERT   = true;
constexpr bool ENC_B_INVERT   = true;

// ---------------- PWM ----------------
constexpr uint32_t PWM_FREQ_HZ  = 20000;  // 20kHz: 가청 대역 밖
constexpr uint8_t  PWM_RES_BITS = 10;
constexpr uint32_t PWM_MAX      = (1u << PWM_RES_BITS) - 1;
constexpr uint8_t  PWM_CH_A = 0;          // ESP32 core 2.x에서만 사용
constexpr uint8_t  PWM_CH_B = 1;

// ---------------- 기구 ----------------
// FIT0482: 홀센서 7극쌍 -> 모터축 1회전당 7펄스/상, 쿼드러처 x4 = 28카운트
constexpr float ENC_COUNTS_PER_MOTOR_REV = 7.0f * 4.0f;
constexpr float GEAR_RATIO      = 50.0f;
constexpr float COUNTS_PER_REV  = ENC_COUNTS_PER_MOTOR_REV * GEAR_RATIO; // 1400
// GT2 벨트 + 20T 풀리 가정 -> 실제 풀리에 맞게 수정
constexpr float PULLEY_TEETH    = 20.0f;
constexpr float BELT_PITCH_MM   = 2.0f;
constexpr float MM_PER_REV      = PULLEY_TEETH * BELT_PITCH_MM;          // 40mm
constexpr float COUNTS_PER_MM   = COUNTS_PER_REV / MM_PER_REV;           // 35

// 작업 영역 (원점 = 좌하단, 리밋/벽 위치)
constexpr float X_MAX_MM = 200.0f;
constexpr float Y_MAX_MM = 200.0f;

// ---------------- 모션 ----------------
// FIT0482 정격 180rpm x 40mm = 120mm/s 벨트 속도. 여유를 두고 제한
constexpr float MOTOR_BELT_VMAX = 80.0f;   // 모터 하나의 벨트 속도 상한 [mm/s]
constexpr float MOTOR_BELT_AMAX = 400.0f;  // [mm/s^2]
constexpr float DEFAULT_SPEED   = 50.0f;   // XY 기본 이송 속도 [mm/s]
constexpr float DEFAULT_ACCEL   = 300.0f;  // XY 가속도 [mm/s^2]

constexpr float HOMING_SPEED     = 10.0f;  // [mm/s]
constexpr float HOMING_PWM_LIMIT = 0.40f;  // 원점 복귀 중 출력 제한 (벽 충돌 보호)
constexpr float HOMING_BACKOFF   = 3.0f;   // 원점에서 떨어질 거리 [mm]
constexpr float STALL_ERR_MM     = 1.5f;   // 스톨 판정 추종 오차
constexpr float STALL_ARM_S      = 0.30f;  // 출발 직후 이 시간 동안은 스톨 판정 안 함

// ---------------- 제어기 ----------------
constexpr float CONTROL_HZ = 1000.0f;

// 출력 단위: PWM 비율(-1~1), 오차 단위: 엔코더 카운트
constexpr float DEFAULT_KP  = 0.020f;     // 50카운트(약 1.4mm) 오차 = 최대 출력
constexpr float DEFAULT_KI  = 0.050f;
constexpr float DEFAULT_KD  = 0.00005f;   // 속도 오차 [count/s] 기준
constexpr float DEFAULT_KFF = 0.00012f;   // 속도 피드포워드 (6V 무부하 ~7200 count/s)
constexpr float I_LIMIT     = 0.30f;      // 적분항 상한
constexpr float PWM_MIN     = 0.08f;      // 정지 마찰 보상 (데드밴드)
constexpr float D_FILTER_ALPHA = 0.10f;   // 측정 속도 저역통과

constexpr int32_t POS_TOL_COUNTS  = 3;    // 도착 허용 오차 (~0.09mm)
constexpr float   SETTLE_S        = 0.05f;
constexpr float   SETTLE_TIMEOUT_S = 1.0f;

// ---------------- 안전 ----------------
constexpr float FOLLOW_ERR_MAX_MM = 4.0f;   // 추종 오차 한계 (걸림·탈조 감지)
constexpr float FOLLOW_ERR_TIME_S = 0.20f;  // 이 시간 이상 지속되면 FAULT
