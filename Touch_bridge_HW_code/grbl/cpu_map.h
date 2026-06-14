// cpu_map.h - CPU 및 핀 매핑 구성 파일

/* cpu_map.h 파일은 다양한 프로세서 유형 또는 대체 핀 레이아웃을 위한 중앙 핀
   매핑 선택 파일 역할을 합니다. 이 버전의 Grbl은 공식적으로 Arduino
   Uno/Mega328p만을 지원합니다. */

#ifndef cpu_map_h
#define cpu_map_h

#ifdef CPU_MAP_ATMEGA328P // (아두이노 우노) Grbl에 의해 공식적으로 지원되는
                          // 매핑입니다.

// 28BYJ-48 모터 수정을 위한 가상 포트 정의 (기존 하드웨어 레지스터 제어를
// 대체/우회할 수 있도록 지원)
uint8_t VPORTB;
uint8_t VPORTC;
uint8_t VPORTD;
uint8_t VDDRB;
uint8_t VDDRC;
uint8_t VDDRD;
uint8_t VPINB;
uint8_t VPINC;
uint8_t VPIND;

// 시리얼 통신(UART) 포트 핀 및 인터럽트 벡터 정의
#define SERIAL_RX USART_RX_vect
#define SERIAL_UDRE USART_UDRE_vect

// 스텝(Step) 펄스 출력 핀 정의. 주의: 모든 축의 스텝 비트 핀은 반드시 동일한
// 포트(Port)에 있어야 합니다.
#define STEP_DDR VDDRD
#define STEP_PORT VPORTD
#define X_STEP_BIT 2 // 우노 디지털 핀 2 (PD2)
#define Y_STEP_BIT 3 // 우노 디지털 핀 3 (PD3)
#define Z_STEP_BIT 4 // 우노 디지털 핀 4 (PD4)
#define STEP_MASK                                                              \
  ((1 << X_STEP_BIT) | (1 << Y_STEP_BIT) |                                     \
   (1 << Z_STEP_BIT)) // 전체 스텝 비트 마스크

// 스텝 모터 방향(Direction) 출력 핀 정의. 주의: 모든 방향 제어 핀은 반드시
// 동일한 포트에 있어야 합니다.
#define DIRECTION_DDR VDDRD
#define DIRECTION_PORT VPORTD
#define X_DIRECTION_BIT 5 // 우노 디지털 핀 5 (PD5)
#define Y_DIRECTION_BIT 6 // 우노 디지털 핀 6 (PD6)
#define Z_DIRECTION_BIT 7 // 우노 디지털 핀 7 (PD7)
#define DIRECTION_MASK                                                         \
  ((1 << X_DIRECTION_BIT) | (1 << Y_DIRECTION_BIT) |                           \
   (1 << Z_DIRECTION_BIT)) // 전체 방향 비트 마스크

// 스텝 모터 드라이버 활성화/비활성화(Enable/Disable) 제어 출력 핀 정의.
#define STEPPERS_DISABLE_DDR VDDRB
#define STEPPERS_DISABLE_PORT VPORTB
#define STEPPERS_DISABLE_BIT 0 // 우노 디지털 핀 8 (PB0)
#define STEPPERS_DISABLE_MASK (1 << STEPPERS_DISABLE_BIT)

// 호밍 및 하드 리미트(한계 스위치) 입력 핀과 리미트 인터럽트 벡터 정의.
// 주의: 모든 리미트 감지 핀은 동일한 포트에 속해야 하며, 사용자 제어(CONTROL)
// 등 타 입력 핀과 포트를 공유하지 않아야 오작동을 방지합니다.
#define LIMIT_DDR VDDRB
#define LIMIT_PIN VPINB
#define LIMIT_PORT VPORTB
#define X_LIMIT_BIT 2 // 우노 디지털 핀 10 (PB2)로 이설됨
#define Y_LIMIT_BIT 3 // 우노 디지털 핀 11 (PB3)로 이설됨
#define Z_LIMIT_BIT 5 // 우노 아날로그 핀 5 (PC5)로 이설 (가상 비트 할당)
#define LIMIT_MASK                                                             \
  ((1 << X_LIMIT_BIT) |                                                        \
   (1 << Y_LIMIT_BIT))  // 포트 B 리미트 핀 마스크 (PB2, PB3)
#define LIMIT_INT PCIE0 // 핀 변경 인터럽트(PCI) 활성화 핀
#define LIMIT_INT_vect PCINT0_vect
#define LIMIT_PCMSK PCMSK0 // 핀 변경 인터럽트 마스크 레지스터

// 스핀들 구동(Enable) 및 회전 방향(Direction) 제어 출력 핀 정의.
#define SPINDLE_ENABLE_DDR VDDRB
#define SPINDLE_ENABLE_PORT VPORTB
// 핀 11의 하드웨어 타이머 PWM 기능을 온전히 사용하기 위해 기존 Z축 리미트 핀과
// 스핀들 PWM/인에이블 핀이 서로 맞교환되었습니다.
#ifdef VARIABLE_SPINDLE
#ifdef USE_SPINDLE_DIR_AS_ENABLE_PIN
// 활성화 시 스핀들 방향 제어 핀을 스핀들 구동(Enable) 핀으로 대신 사용하며, PWM
// 출력은 D11 핀을 유지합니다.
#define SPINDLE_ENABLE_BIT                                                     \
  5 // 우노 디지털 핀 13 (주의: D13은 내장 LED 회로 연결로 인해 풀업 입력으로
    // 사용할 수 없습니다.)
#else
#define SPINDLE_ENABLE_BIT 3 // 우노 디지털 핀 11
#endif
#else
#define SPINDLE_ENABLE_BIT 4 // 우노 디지털 핀 12
#endif
#ifndef USE_SPINDLE_DIR_AS_ENABLE_PIN
#define SPINDLE_DIRECTION_DDR VDDRB
#define SPINDLE_DIRECTION_PORT VPORTB
#define SPINDLE_DIRECTION_BIT                                                  \
  5 // 우노 디지털 핀 13 (주의: D13은 내장 LED 회로 연결로 인해 풀업 입력으로
    // 사용할 수 없습니다.)
#endif

// 절삭유(Coolant) Flood 및 Mist 활성화 제어 출력 핀 정의.
#define COOLANT_FLOOD_DDR VDDRC
#define COOLANT_FLOOD_PORT VPORTC
#define COOLANT_FLOOD_BIT 3 // 우노 아날로그 핀 3 (PC3)
#define COOLANT_MIST_DDR VDDRC
#define COOLANT_MIST_PORT VPORTC
#define COOLANT_MIST_BIT 4 // 우노 아날로그 핀 4 (PC4)

// 사용자 제어 스위치(사이클 시작, 리셋, 피드 홀드) 입력 핀 정의.
// 주의: 모든 사용자 제어(CONTROL) 입력 핀들은 동일한 포트에 있어야 하며 리미트
// 스위치 등 다른 목적의 입력 포트와 분리되어야 합니다.
#define CONTROL_DDR VDDRC
#define CONTROL_PIN VPINC
#define CONTROL_PORT VPORTC
#define CONTROL_RESET_BIT 0       // 우노 아날로그 핀 0 (PC0)
#define CONTROL_FEED_HOLD_BIT 1   // 우노 아날로그 핀 1 (PC1)
#define CONTROL_CYCLE_START_BIT 2 // 우노 아날로그 핀 2 (PC2)
#define CONTROL_SAFETY_DOOR_BIT                                                \
  1 // 우노 아날로그 핀 1 주의: 안전 도어(Safety Door) 기능은 피드 홀드와 핀을
    // 공유하며, 설정 활성화 시에 구동됩니다.
#define CONTROL_INT PCIE1 // 핀 변경 인터럽트(PCI) 활성화 핀
#define CONTROL_INT_vect PCINT1_vect
#define CONTROL_PCMSK PCMSK1 // 핀 변경 인터럽트 마스크 레지스터
#define CONTROL_MASK                                                           \
  ((1 << CONTROL_RESET_BIT) | (1 << CONTROL_FEED_HOLD_BIT) |                   \
   (1 << CONTROL_CYCLE_START_BIT) | (1 << CONTROL_SAFETY_DOOR_BIT))
#define CONTROL_INVERT_MASK                                                    \
  CONTROL_MASK // 특정 제어 핀의 논리만 반전시키기 위해 별도로 재정의될 수
               // 있습니다.

// 프로브(Probe) 스위치 센서 입력 핀 정의.
#define PROBE_DDR VDDRC
#define PROBE_PIN VPINC
#define PROBE_PORT VPORTC
#define PROBE_BIT 5 // 우노 아날로그 핀 5 (PC5)
#define PROBE_MASK (1 << PROBE_BIT)

// 가변 스핀들(Variable Spindle) PWM 타이머 설정. 구조 및 동작 원리를 완벽히
// 파악한 후에만 수정하십시오. 주의: 가변 스핀들 설정이 컴파일 정의에서 활성화된
// 경우에만 적용됩니다.
#define SPINDLE_PWM_MAX_VALUE                                                  \
  255 // 변경 불가. ATmega328p의 고속 PWM(Fast PWM) 모드 한계값은 255로
      // 고정됩니다.
#ifndef SPINDLE_PWM_MIN_VALUE
#define SPINDLE_PWM_MIN_VALUE 1 // 0보다 큰 값이어야 합니다.
#endif
#define SPINDLE_PWM_OFF_VALUE 0
#define SPINDLE_PWM_RANGE (SPINDLE_PWM_MAX_VALUE - SPINDLE_PWM_MIN_VALUE)
#define SPINDLE_TCCRA_REGISTER TCCR2A
#define SPINDLE_TCCRB_REGISTER TCCR2B
#define SPINDLE_OCR_REGISTER OCR2A
#define SPINDLE_COMB_BIT COM2A1

// 분주기(Prescaler)가 지정된 8비트 고속 PWM 모드 초기화 마스크.
#define SPINDLE_TCCRA_INIT_MASK                                                \
  ((1 << WGM20) | (1 << WGM21)) // 고속 PWM(Fast PWM) 모드 구성
// #define SPINDLE_TCCRB_INIT_MASK   (1<<CS20)               // 분주기 사용 안
// 함 -> 62.5kHz #define SPINDLE_TCCRB_INIT_MASK   (1<<CS21)               //
// 1/8 분주기 적용 -> 7.8kHz (Grbl v0.9 버전에서 주로 사용) #define
// SPINDLE_TCCRB_INIT_MASK   ((1<<CS21) | (1<<CS20)) // 1/32 분주기 적용
// -> 1.96kHz
#define SPINDLE_TCCRB_INIT_MASK                                                \
  (1 << CS22) // 1/64 분주기 적용 -> 0.98kHz (J-tech 레이저 가공기 등 권장)

// 주의: ATmega328p 아두이노 우노 하드웨어 상에서 이 설정들은 반드시
// SPINDLE_ENABLE과 동일한 핀을 참조해야 합니다.
#define SPINDLE_PWM_DDR VDDRB
#define SPINDLE_PWM_PORT VPORTB
#define SPINDLE_PWM_BIT 3 // 우노 디지털 핀 11 (PB3)

#endif

/*
#ifdef CPU_MAP_CUSTOM_PROC
  // 커스텀 핀 매핑 또는 다른 종류의 MCU/프로세서를 사용하는 경우, 본 핀 매핑
파일 중 하나를 복사하여
  // 알맞게 수정하여 사용하십시오. 이때 정의된 고유 매핑 이름이 config.h에도
반영되었는지 확인해야 합니다. #endif
*/

#endif
