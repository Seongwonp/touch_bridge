// stepper.c - 스텝 모터 드라이버: 스텝 모터를 사용하여 모션 계획을 실행합니다.

#include "grbl.h"
int costyx = 1;
int costyy = 1;
int costyz = 1;

// Some useful constants.
#define DT_SEGMENT (1.0 / (ACCELERATION_TICKS_PER_SECOND * 60.0)) // min/segment
#define REQ_MM_INCREMENT_SCALAR 1.25
#define RAMP_ACCEL 0
#define RAMP_CRUISE 1
#define RAMP_DECEL 2
#define RAMP_DECEL_OVERRIDE 3

#define PREP_FLAG_RECALCULATE bit(0)
#define PREP_FLAG_HOLD_PARTIAL_BLOCK bit(1)
#define PREP_FLAG_PARKING bit(2)
#define PREP_FLAG_DECEL_OVERRIDE bit(3)

// 적응형 다축 스텝 스무딩(AMASS, Adaptive Multi-Axis Step-Smoothing) 레벨 및
// 차단 주파수(Cutoff Frequency) 정의. 가장 높은 수준의 주파수 대역은 0Hz에서
// 시작하여 차단 주파수에서 끝남. 다음으로 낮은 레벨의 주파수 대역은 그 위의
// 차단 주파수에서 시작하는 방식임. 각 레벨의 차단 주파수는 스텝 ISR에
// 가해지는 부하, 16비트 타이머의 정밀도, 그리고 CPU 오버헤드를 세심히 고려하여
// 신중하게 결정되어야 합니다. 레벨 0(AMASS 비활성, 일반 작동) 주파수 대역은
// 레벨 1 차단 주파수에서 시작하여 CPU가 허용하는 최대 속도(제한적 테스트에서
// 30kHz 이상)까지 올라갑니다. 주의: AMASS 차단 주파수에 ISR 오버드라이브 팩터를
// 곱한 값이 최대 스텝 주파수를 초과해서는 안 됩니다. 주의: 현재 설정은 ISR
// 오버드라이브가 16kHz를 넘지 않도록 제한하여 CPU 부하와 타이머 정밀도의 균형을
// 맞추고 있습니다. 이에 대해 완벽히 이해하지 못했다면 설정을 임의로 수정하지
// 마십시오.
#ifdef ADAPTIVE_MULTI_AXIS_STEP_SMOOTHING
#define MAX_AMASS_LEVEL 3
// AMASS_LEVEL0: Normal operation. No AMASS. No upper cutoff frequency. Starts
// at LEVEL1 cutoff frequency.
#define AMASS_LEVEL1                                                           \
  (F_CPU /                                                                     \
   8000) // Over-drives ISR (x2). Defined as F_CPU/(Cutoff frequency in Hz)
#define AMASS_LEVEL2 (F_CPU / 4000) // Over-drives ISR (x4)
#define AMASS_LEVEL3 (F_CPU / 2000) // Over-drives ISR (x8)

#if MAX_AMASS_LEVEL <= 0
error "AMASS must have 1 or more levels to operate correctly."
#endif
#endif

    // 세그먼트 버퍼 내의 세그먼트들을 위한 플래너 블록 브레젠험(Bresenham)
    // 알고리즘 실행 데이터를 저장합니다. 일반적으로 이 버퍼는 일부만
    // 사용되지만, 최악의 시나리오에서도 스텝 버퍼 세그먼트
    // 수(SEGMENT_BUFFER_SIZE - 1)를 초과하지 않습니다. 주의: 이 데이터는
    // 준비된(prepped) 플래너 블록으로부터 복사되므로, 세그먼트 버퍼에서 모든
    // 단계를 소모하고 처리가 완료되면 원본 플래너 블록은 안전하게 폐기될 수
    // 있습니다. 또한, AMASS 알고리즘도 전용 제어를 위해 이 데이터를 수정해
    // 사용합니다.
    typedef struct {
  uint32_t steps[N_AXIS];
  uint32_t step_event_count;
  uint8_t direction_bits;
#ifdef VARIABLE_SPINDLE
  uint8_t is_pwm_rate_adjusted; // Tracks motions that require constant laser
                                // power/rate
#endif
} st_block_t;
static st_block_t st_block_buffer[SEGMENT_BUFFER_SIZE - 1];

// 메인 스텝 세그먼트 링 버퍼. 스텝 구동 알고리즘이 처리할 작고 짧은 선
// 세그먼트들을 포함하며, 플래너 버퍼의 첫 번째 블록에서 증분 방식으로
// 가져와("check-out") 채워집니다. 일단 가져온 스텝 세그먼트들은 플래너에 의해
// 수정될 수 없지만, 플래너 블록에 남아있는 미처리 스텝들은 여전히 수정이
// 가능합니다.
typedef struct {
  uint16_t n_step; // Number of step events to be executed for this segment
  uint16_t
      cycles_per_tick;    // Step distance traveled per ISR tick, aka step rate.
  uint8_t st_block_index; // Stepper block data index. Uses this information to
                          // execute this segment.
#ifdef ADAPTIVE_MULTI_AXIS_STEP_SMOOTHING
  uint8_t
      amass_level; // Indicates AMASS level for the ISR to execute this segment
#else
  uint8_t prescaler; // Without AMASS, a prescaler is required to adjust for
                     // slow timing.
#endif
#ifdef VARIABLE_SPINDLE
  uint8_t spindle_pwm;
#endif
} segment_t;
static segment_t segment_buffer[SEGMENT_BUFFER_SIZE];

// 스텝 모터 ISR(인터럽트 서비스 루틴) 데이터 구조체. 메인 스텝 ISR 실행에
// 사용되는 실시간 변수들을 포함합니다.
typedef struct {
  // Used by the bresenham line algorithm
  uint32_t counter_x, // Counter variables for the bresenham line tracer
      counter_y, counter_z;
#ifdef STEP_PULSE_DELAY
  uint8_t step_bits; // Stores out_bits output to complete the step pulse delay
#endif

  uint8_t execute_step;    // Flags step execution for each interrupt.
  uint8_t step_pulse_time; // Step pulse reset time after step rise
  uint8_t step_outbits;    // The next stepping-bits to be output
// uint8_t dir_outbits;
#ifdef ADAPTIVE_MULTI_AXIS_STEP_SMOOTHING
  uint32_t steps[N_AXIS];
#endif

  uint16_t step_count;      // Steps remaining in line segment motion
  uint8_t exec_block_index; // Tracks the current st_block index. Change
                            // indicates new block.
  st_block_t
      *exec_block; // Pointer to the block data for the segment being executed
  segment_t *exec_segment; // Pointer to the segment being executed
} stepper_t;
static stepper_t st;

// Step segment ring buffer indices
static volatile uint8_t segment_buffer_tail;
static uint8_t segment_buffer_head;
static uint8_t segment_next_head;

// 스텝 및 방향 포트 출력 논리 반전 마스크 (Invert Mask)
static uint8_t step_port_invert_mask;
static uint8_t dir_port_invert_mask;

// "스텝 드라이버 인터럽트(Stepper Driver Interrupt)"의 중복 진입(Nest)을
// 방지하기 위한 변수. 실제로는 거의 발생하지 않습니다.
static volatile uint8_t busy;

// 플래너 버퍼에서 가공되어 준비 중인 스텝 세그먼트를 가리키는 포인터. 메인
// 프로그램 루프에서만 액세스합니다. 현재 실행 중인 모션보다 앞서 준비 중인
// 세그먼트 또는 플래너 블록을 가리킬 수 있습니다.
static plan_block_t *pl_block; // Pointer to the planner block being prepped
static st_block_t
    *st_prep_block; // Pointer to the stepper block data being prepped

// 세그먼트 준비(Prep) 데이터 구조체. 현재 실행 중인 플래너 블록을 기반으로
// 새로운 세그먼트를 계산하기 위해 필요한 모든 정보를 담고 있습니다.
typedef struct {
  uint8_t st_block_index; // Index of stepper common data block being prepped
  uint8_t recalculate_flag;

  float dt_remainder;
  float steps_remaining;
  float step_per_mm;
  float req_mm_increment;

#ifdef PARKING_ENABLE
  uint8_t last_st_block_index;
  float last_steps_remaining;
  float last_step_per_mm;
  float last_dt_remainder;
#endif

  uint8_t ramp_type; // Current segment ramp state
  float mm_complete; // End of velocity profile from end of current planner
                     // block in (mm). NOTE: This value must coincide with a
                     // step(no mantissa) when converted.
  float
      current_speed; // Current speed at the end of the segment buffer (mm/min)
  float maximum_speed; // Maximum speed of executing block. Not always nominal
                       // speed. (mm/min)
  float exit_speed;    // Exit speed of executing block (mm/min)
  float
      accelerate_until; // Acceleration ramp end measured from end of block (mm)
  float decelerate_after; // Deceleration ramp start measured from end of block
                          // (mm)

#ifdef VARIABLE_SPINDLE
  float inv_rate; // Used by PWM laser mode to speed up segment calculations.
  uint8_t current_spindle_pwm;
#endif
} st_prep_t;
static st_prep_t prep;

/*    블록 속도 프로필 정의 (BLOCK VELOCITY PROFILE DEFINITION)
          __________________________
         /|                        |\     _________________         ^
        / |                        | \   /|               |\        |
       /  |                        |  \ / |               | \       s
      /   |                        |   |  |               |  \      p
     /    |                        |   |  |               |   \     e
    +-----+------------------------+---+--+---------------+----+    e
    |               BLOCK 1            ^      BLOCK 2          |    d
                                       |
                  시간(time) ->      예시: 블록 2 진입 속도가 최대 정크션 접합
 속도에 도달한 상태

  플래너 블록 버퍼는 등가속도 속도 프로필을 가정하여 계획되며, 위 그림과 같이
 블록 접합부에서 연속적으로 연결됩니다. 그러나 플래너는 최적의 속도 계획을 위해
 블록 진입 속도만을 능동적으로 계산할 뿐, 블록 내부의 속도 프로필은 계산하지
 않습니다. 블록 내부 속도 프로필은 스텝 구동 알고리즘에 의해 실행될 때
 실시간(Ad-hoc)으로 계산되며, 다음 7가지 프로필 유형 중 하나로 구성됩니다: 등속
 전용(Cruise-only), 등속-감속(Cruise-decel), 가속-등속(Accel-cruise), 가속
 전용(Accel-only), 감속 전용(Decel-only), 완전 사다리꼴(Full-trapezoid),
 삼각형(Triangle, 등속 구간 없음).

                                        maximum_speed (< nominal_speed) ->  +
                    +--------+ <- maximum_speed (= nominal_speed)          /|\
                   /          \                                           / | \
 current_speed -> +            \                                         /  |  +
 <- exit_speed |             + <- exit_speed                         /   |  |
                  +-------------+                     current_speed -> +----+--+
                   time -->  ^  ^                                           ^  ^
                             |  |                                           |  |
                decelerate_after(단위: mm) decelerate_after(단위: mm) ^ ^ ^  ^
                    |           |                                           |  |
                accelerate_until(단위: mm) accelerate_until(단위: mm)

  스텝 세그먼트 버퍼는 실행 중인 블록의 속도 프로필을 계산하고 스텝 알고리즘이
 프로필을 정확하게 추적할 수 있도록 임계 파라미터들을 관리합니다. 이 임계
 파라미터들은 위 그림에서 정의된 형태로 표시됩니다.
*/

// 스텝 모터 상태 초기화. 모션 사이클은 오직 st.cycle_start 플래그가
// 활성화되었을 때만 시작되어야 합니다. 시스템 부팅 초기화 및 리미트 처리 루틴이
// 이 함수를 호출하지만, 호출 즉시 모션 사이클이 시작되지는 않습니다.
void st_wake_up() {
  // 스텝 모터 드라이버 활성화(Enable)
  if (bit_istrue(settings.flags, BITFLAG_INVERT_ST_ENABLE)) {
    STEPPERS_DISABLE_PORT |= (1 << STEPPERS_DISABLE_BIT);
  } else {
    STEPPERS_DISABLE_PORT &= ~(1 << STEPPERS_DISABLE_BIT);
  }

  // 첫 번째 ISR 호출 시 오작동 스텝이 발생하지 않도록 초기 출력 비트를 설정
  st.step_outbits = step_port_invert_mask;

// 설정값으로부터 스텝 펄스 타이밍을 계산하여 초기화합니다.
#ifdef STEP_PULSE_DELAY
  // 방향(Direction) 핀 설정 후 총 스텝 펄스 구동 시간을 설정 (오실로스코프
  // 계측에 근거함)
  st.step_pulse_time = -(((settings.pulse_microseconds + STEP_PULSE_DELAY - 2) *
                          TICKS_PER_MICROSECOND) >>
                         3);
  // 방향 핀 출력 후 스텝 명령 발생 전까지의 대기 시간(Delay) 설정
  OCR0A = -(((settings.pulse_microseconds) * TICKS_PER_MICROSECOND) >> 3);
#else // 일반 동작 방식 (지연 없음)
  // 스텝 펄스 폭을 설정 (2의 보수 이용, 오실로스코프 계측 근거)
  st.step_pulse_time =
      -(((settings.pulse_microseconds - 2) * TICKS_PER_MICROSECOND) >> 3);
#endif

  // 스텝 모터 드라이버 인터럽트(Timer1) 활성화
  TIMSK1 |= (1 << OCIE1A);
}

// 스텝 모터 정지 및 대기 전환 (Shutdown)
void st_go_idle() {
  // 스텝 모터 드라이버 인터럽트 비활성화. 현재 진행 중인 포트 리셋 인터럽트가
  // 있다면 완료되도록 허용합니다.
  TIMSK1 &= ~(1 << OCIE1A); // Timer1 컴페어 인터럽트 차단
  TCCR1B =
      (TCCR1B & ~((1 << CS12) | (1 << CS11))) |
      (1 << CS10); // 분주기 없는 기본 클럭(No Prescaling)으로 타이머 재설정
  busy = false;

  // 세팅 및 시스템 상황에 근거하여 대기 시 스텝 드라이버를 인에이블로 유지할지
  // 디스에이블할지 설정합니다.
  bool pin_state = false; // 기본값: 계속 가동 상태 유지(락 고정)
  if (((settings.stepper_idle_lock_time != 0xff) || sys_rt_exec_alarm ||
       sys.state == STATE_SLEEP) &&
      sys.state != STATE_HOMING) {
    // 모션 완료 후 관성력에 의한 축 밀림 현상을 방지하고 완전 정지를 보장하기
    // 위해 설정된 시간(Idle lock time) 동안 축을 고정(Dwell Lock) 대기합니다.
    delay_ms(settings.stepper_idle_lock_time);
    pin_state = true; // 대기 시간 경과 후 드라이버 비활성화(풀림) 결정
  }
  if (bit_istrue(settings.flags, BITFLAG_INVERT_ST_ENABLE)) {
    pin_state = !pin_state;
  } // 핀 논리 반전 적용
  if (pin_state) {
    STEPPERS_DISABLE_PORT |= (1 << STEPPERS_DISABLE_BIT);
    // 터치 브리지 전용 설계: 28BYJ-48 모터 장시간 대기 시 발생하는 코일의 심한
    // 발열을 차단하기 위해 코일 전류 차단 (출력 LOW 강제)
    PORTD &= ~0x3C; // X축 관련 구동 핀(D2~D5) LOW 출력
    PORTC &= ~0x0F; // Y축 관련 구동 핀(C0~C3) LOW 출력
    PORTB &= ~0x33; // Z축 관련 구동 핀(B0, B1, B4, B5) LOW 출력
  } else {
    STEPPERS_DISABLE_PORT &= ~(1 << STEPPERS_DISABLE_BIT);
  }
}

/* "스텝 드라이버 인터럽트 (The Stepper Driver Interrupt)" - 이 타이머
   인터럽트는 Grbl의 핵심 동력원입니다. Grbl은 유서 깊은 브레젠험(Bresenham)
   라인 알고리즘을 채택하여 다축 모션을 정밀하게 동기화하고 관리합니다. 대중적인
   DDA 알고리즘과 달리 브레젠험 알고리즘은 수치 반올림 오차가 발생하지 않으며,
   오직 빠른 정수형 카운터 연산만을 필요로 하므로 계산 부하가 매우 낮고 아두이노
   MCU의 역량을 극대화합니다. 그러나 브레젠험 알고리즘의 단점은 특정 다축 이동
   시 주축(Dominant axis)이 아닌 부축(Non-dominant axes)에서 스텝 펄스가
   균일하지 않게 생성되는 앨리어싱(Aliasing) 현상이 생길 수 있으며, 이로 인해
   모터 소음이나 진동이 유발될 수 있다는 점입니다. 이는 낮은 스텝 주파수
   대역(0~5kHz)에서 두드러지게 감지될 수 있으나, 고주파수 대역에서는 가 청 소음
   외에 물리적인 제어 문제를 거의 일으키지 않습니다. 이러한 다축 제어 성능을
   개선하고자, Grbl은 "적응형 다축 스텝 스무딩(AMASS, Adaptive Multi-Axis Step
   Smoothing)" 알고리즘을 탑재했습니다. AMASS는 낮은 구동 주파수에서 알고리즘
   본연의 정밀도를 손상시키지 않으면서 브레젠험 해상도를 인위적으로
   배가시킵니다. AMASS는 모터 구동 속도(주파수)에 맞추어 해상도 레벨을 자동으로
   조절하며, 스텝 주파수가 낮아질수록 스텝 스무딩 레벨(해상도)을 더욱 높입니다.
   구현상 AMASS는 각 해상도 레벨마다 브레젠험 스텝 카운트를 비트
   시프트(Bit-shifting)하여 스텝 주파수를 곱해주는 방식으로 작동합니다. 예를
   들어 레벨 1 스무딩의 경우, 브레젠험 스텝 이벤트 수를 비트 시프트하여
   실질적으로 2배 늘리며(단 개별 축의 스텝 총량은 유지), 동시에 인터럽트(ISR)
   주기 빈도를 2배로 올립니다. 결과적으로 주축은 2회 ISR 틱마다 한 스텝씩
   전진하지만, 부축들은 그 중간의 ISR 틱에서도 유연하게 스텝을 디딜 수 있게
   됩니다. 레벨 2에서는 한 번 더 비트 시프트를 진행하여 부축들이 4회의 ISR 틱 중
   어디서든 스텝을 디딜 수 있도록 하고, 인터럽트 주기를 4배로 가속합니다.
   이 방식을 통해 브레젠험 다축 구동 시의 고질적인 진동/소음(앨리어싱) 문제를
   사실상 극복할 수 있으며, CPU의 유휴 연산 주기를 매우 효율적으로 사용하므로
   전반적인 성능 저하 또한 초래하지 않습니다. AMASS는 동작 레벨에 관계없이
   언제나 최종적으로는 정수 단위의 완전한 브레젠험 한 스텝을 모두 소화하므로
   원래의 구동 정밀도를 고스란히 유지합니다. 즉 레벨 2에서는 4개의 미세 스텝이
   완결되어야 비로소 기준 해상도의 1스텝이 완성됩니다. 레벨 3도 동일하게 8개의
   미세 스텝이 수행됩니다. 비트 시프트 연산(2의 거듭제곱)을 이용해 CPU의
   곱셈/나눗셈 부하를 최소화하였습니다. 이 인터럽트는 구조적으로 매우 단순하고
   직관적으로 설계되었습니다. 가속 계산과 같은 무거운 연산은 메인 플래너 등
   외부에서 미리 처리됩니다. 이 인터럽트는 스텝 세그먼트 버퍼에서 미리 계산된
   등속 세그먼트(일정 스텝 수 동안 등속 유지)를 하나씩 꺼내온 뒤, 브레젠험
   알고리즘에 따라 각 스텝 핀에 적절한 펄스를 발생시키는 역할만을 수행합니다. 이
   인터럽트는 펄스 출력 후 핀 상태를 복귀(Reset)해주는 "스텝 포트 리셋
   인터럽트(Stepper Port Reset Interrupt)"와 유기적으로 연동하여 동작합니다.

   주의: 이 인터럽트는 극도의 연산 효율성을 지녀야 하며 다음 ISR 틱이 발생하기
   전에 반드시 수행 완료되어야 합니다. (Grbl 기준 최대 30kHz ISR
   주파수이므로 33.3usec 이내에 끝나야 함). 오실로스코프로 계측된 실행 시간은
   평균 5usec, 최대 25usec 수준으로 충분히 안정적입니다. 주의: 본 ISR은 각
   세그먼트마다 최소 1개 이상의 실질 스텝이 구동된다고 가정합니다.
*/
// TODO: Replace direct updating of the int32 position counters in the ISR
// somehow. Perhaps use smaller int8 variables and update position counters only
// when a segment completes. This can get complicated with probing and homing
// cycles that require true real-time positions.
ISR(TIMER1_COMPA_vect) {
  if (busy) {
    return;
  } // busy 플래그를 확인하여 이 인터럽트의 중복 중첩 진입을 원천 차단합니다.

// 스텝을 인가하기 몇 나노초 전에 방향(Direction) 핀의 출력을 미리 확정시킵니다.
// DIRECTION_PORT = (DIRECTION_PORT & ~DIRECTION_MASK) | (st.dir_outbits &
// DIRECTION_MASK);

// 스텝(Step) 핀에 펄스를 출력합니다.
#ifdef STEP_PULSE_DELAY
  st.step_bits =
      (STEP_PORT & ~STEP_MASK) |
      st.step_outbits; // 핀 출력 마스크 덮어쓰기 방지를 위해 변수에 사전 기록
#else                  // 일반 동작 모드 (지연 없음)
  STEP_PORT = (STEP_PORT & ~STEP_MASK) | st.step_outbits;
#endif

  // 스텝 포트 리셋 인터럽트가 설정된 스텝 펄스 폭(settings.pulse_microseconds)
  // 직후에 펄스 신호를 복귀(Reset)시킬 수 있도록 리셋 타이머(Timer0)를
  // 시작합니다. 이는 메인 Timer1 분주기와 무관하게 작동합니다.
  TCNT0 = st.step_pulse_time; // Timer0 카운터 초깃값 적재 (2의 보수 탑재)
  TCCR0B = (1 << CS01);       // Timer0 시작 (1/8 분주율 적용)

  busy = true;
  sei(); // 포트 리셋 인터럽트가 제시간에 정확히 실행되도록 글로벌 인터럽트를
         // 조기 재활성화합니다. 주의: 이 ISR의 나머지 잔여 코드들은 메인 루프로
         // 복귀하기 전에 반드시 완료됩니다.

  // 현재 실행 중인 스텝 세그먼트가 완료되었다면 스텝 버퍼로부터 새로운
  // 세그먼트를 인출(Pop)합니다.
  if (st.exec_segment == NULL) {
    // 버퍼에 대기 중인 세그먼트가 있는지 확인 후 다음 세그먼트를 로드 및
    // 초기화합니다.
    if (segment_buffer_head != segment_buffer_tail) {
      // 새로운 스텝 세그먼트 구조체 연결 및 세그먼트 초기화
      st.exec_segment = &segment_buffer[segment_buffer_tail];

#ifndef ADAPTIVE_MULTI_AXIS_STEP_SMOOTHING
      // AMASS가 비활성화되어 있는 경우, 매우 느린 모션 속도(<250Hz) 세그먼트를
      // 위해 타이머 분주기 레지스터를 동적으로 재조정합니다.
      TCCR1B =
          (TCCR1B & ~(0x07 << CS10)) | (st.exec_segment->prescaler << CS10);
#endif

      // 틱 당 스텝 주기(속도 정보) 반영 및 구동할 스텝 이벤트 횟수 수신
      OCR1A = st.exec_segment->cycles_per_tick;
      st.step_count = st.exec_segment->n_step; // 주의: 속도가 극도로 느릴 때는
                                               // 0이 들어올 수도 있습니다.
      // 새로 시작하는 세그먼트가 신규 플래너 블록에 해당한다면, 카운터 및
      // 변수들을 새로 리셋합니다. 주의: 세그먼트의 st_block_index 정보가
      // 바뀌었다는 것은 새로운 독립적 플래너 블록에 진입했음을 의미합니다.
      if (st.exec_block_index != st.exec_segment->st_block_index) {
        st.exec_block_index = st.exec_segment->st_block_index;
        st.exec_block = &st_block_buffer[st.exec_block_index];

        // 브레젠험 라인 알고리즘 및 거리 오차 누적 카운터 초기화
        st.counter_x = st.counter_y = st.counter_z =
            (st.exec_block->step_event_count >> 1);
      }
      // st.dir_outbits = st.exec_block->direction_bits ^ dir_port_invert_mask;

#ifdef ADAPTIVE_MULTI_AXIS_STEP_SMOOTHING
      // AMASS가 활성화된 경우, 지정된 스무딩 레벨에 의거하여 브레젠험 축 증가
      // 가중치를 동적으로 시프트하여 나눕니다.
      st.steps[X_AXIS] =
          st.exec_block->steps[X_AXIS] >> st.exec_segment->amass_level;
      st.steps[Y_AXIS] =
          st.exec_block->steps[Y_AXIS] >> st.exec_segment->amass_level;
      st.steps[Z_AXIS] =
          st.exec_block->steps[Z_AXIS] >> st.exec_segment->amass_level;
#endif

#ifdef VARIABLE_SPINDLE
      // 스텝 펄스가 직접 나가기 직전에, 실시간 가변 스핀들 출력을 동적으로
      // 적용합니다.
      spindle_set_speed(st.exec_segment->spindle_pwm);
#endif

    } else {
      // 스텝 세그먼트 버퍼가 비어있습니다. 구동 시스템을 대기(Idle) 상태로
      // 전환합니다.
      st_go_idle();
#ifdef VARIABLE_SPINDLE
      // 스핀들 출력율 제어 모션이 정상적으로 끝난 뒤 스핀들이 정확히 오프되도록
      // 확실하게 보장합니다.
      if (st.exec_block->is_pwm_rate_adjusted) {
        spindle_set_speed(SPINDLE_PWM_OFF_VALUE);
      }
#endif
      system_set_exec_state_flag(
          EXEC_CYCLE_STOP); // 메인 프로그램에 전체 제어 사이클의 종료를 알림
      return;               // 빠져나갑니다.
    }
  }

  // 실시간 프로빙(Probing) 상태 확인 및 활성화 시 센서 모니터링 수행
  if (sys_probe_state == PROBE_ACTIVE) {
    probe_state_monitor();
  }

  // 다음 스텝 출력 비트 초기화
  st.step_outbits = 0;

  st.exec_block->direction_bits =
      st.exec_block->direction_bits ^ dir_port_invert_mask;

// 브레젠험(Bresenham) 라인 트레이싱 알고리즘을 사용한 다축 변위 스텝 펄스 판별
// 및 전진 제어
#ifdef ADAPTIVE_MULTI_AXIS_STEP_SMOOTHING
  st.counter_x += st.steps[X_AXIS];
#else
  st.counter_x += st.exec_block->steps[X_AXIS];
#endif
  if (st.counter_x > st.exec_block->step_event_count) {
    st.step_outbits |= (1 << X_STEP_BIT);
    st.counter_x -= st.exec_block->step_event_count;
    if (st.exec_block->direction_bits & (1 << X_DIRECTION_BIT)) {
      sys_position[X_AXIS]--;
      costyx = costyx - 1;
      if (costyx < 1)
        costyx = 8;
      if (costyx == 1)
        PORTD = 0B100000;
      if (costyx == 2)
        PORTD = 0B110000;
      if (costyx == 3)
        PORTD = 0B010000;
      if (costyx == 4)
        PORTD = 0B011000;
      if (costyx == 5)
        PORTD = 0B001000;
      if (costyx == 6)
        PORTD = 0B001100;
      if (costyx == 7)
        PORTD = 0B000100;
      if (costyx == 8)
        PORTD = 0B100100;
    } else {
      sys_position[X_AXIS]++;
      costyx = costyx + 1;
      if (costyx > 8)
        costyx = 1;
      if (costyx == 1)
        PORTD = 0B100000;
      if (costyx == 2)
        PORTD = 0B110000;
      if (costyx == 3)
        PORTD = 0B010000;
      if (costyx == 4)
        PORTD = 0B011000;
      if (costyx == 5)
        PORTD = 0B001000;
      if (costyx == 6)
        PORTD = 0B001100;
      if (costyx == 7)
        PORTD = 0B000100;
      if (costyx == 8)
        PORTD = 0B100100;
    }
  }
#ifdef ADAPTIVE_MULTI_AXIS_STEP_SMOOTHING
  st.counter_y += st.steps[Y_AXIS];
#else
  st.counter_y += st.exec_block->steps[Y_AXIS];
#endif
  if (st.counter_y > st.exec_block->step_event_count) {
    st.step_outbits |= (1 << Y_STEP_BIT);
    st.counter_y -= st.exec_block->step_event_count;
    if (st.exec_block->direction_bits & (1 << Y_DIRECTION_BIT)) {
      sys_position[Y_AXIS]--;
      costyy = costyy - 1;
      if (costyy < 1)
        costyy = 8;
      if (costyy == 1)
        PORTC = 0B1000;
      if (costyy == 2)
        PORTC = 0B1100;
      if (costyy == 3)
        PORTC = 0B0100;
      if (costyy == 4)
        PORTC = 0B0110;
      if (costyy == 5)
        PORTC = 0B0010;
      if (costyy == 6)
        PORTC = 0B0011;
      if (costyy == 7)
        PORTC = 0B0001;
      if (costyy == 8)
        PORTC = 0B1001;
    } else {
      sys_position[Y_AXIS]++;
      costyy = costyy + 1;
      if (costyy > 8)
        costyy = 1;
      if (costyy == 1)
        PORTC = 0B1000;
      if (costyy == 2)
        PORTC = 0B1100;
      if (costyy == 3)
        PORTC = 0B0100;
      if (costyy == 4)
        PORTC = 0B0110;
      if (costyy == 5)
        PORTC = 0B0010;
      if (costyy == 6)
        PORTC = 0B0011;
      if (costyy == 7)
        PORTC = 0B0001;
      if (costyy == 8)
        PORTC = 0B1001;
    }
  }
#ifdef ADAPTIVE_MULTI_AXIS_STEP_SMOOTHING
  st.counter_z += st.steps[Z_AXIS];
#else
  st.counter_z += st.exec_block->steps[Z_AXIS];
#endif
  if (st.counter_z > st.exec_block->step_event_count) {
    st.step_outbits |= (1 << Z_STEP_BIT);
    st.counter_z -= st.exec_block->step_event_count;
    if (st.exec_block->direction_bits & (1 << Z_DIRECTION_BIT)) {
      sys_position[Z_AXIS]--;
      costyz = costyz - 1;
      if (costyz < 1)
        costyz = 8;
      if (costyz == 1)
        PORTB = 0B100000;
      if (costyz == 2)
        PORTB = 0B110000;
      if (costyz == 3)
        PORTB = 0B010000;
      if (costyz == 4)
        PORTB = 0B010010;
      if (costyz == 5)
        PORTB = 0B000010;
      if (costyz == 6)
        PORTB = 0B000011;
      if (costyz == 7)
        PORTB = 0B000001;
      if (costyz == 8)
        PORTB = 0B100001;
    } else {
      sys_position[Z_AXIS]++;
      costyz = costyz + 1;
      if (costyz > 8)
        costyz = 1;
      if (costyz == 1)
        PORTB = 0B100000;
      if (costyz == 2)
        PORTB = 0B110000;
      if (costyz == 3)
        PORTB = 0B010000;
      if (costyz == 4)
        PORTB = 0B010010;
      if (costyz == 5)
        PORTB = 0B000010;
      if (costyz == 6)
        PORTB = 0B000011;
      if (costyz == 7)
        PORTB = 0B000001;
      if (costyz == 8)
        PORTB = 0B100001;
    }
  }

  // 호밍(Homing) 사이클 진행 중일 때, 지정된 호밍 대상 외의 다른 축이 연동되어
  // 움직이지 않도록 스텝 출력을 하드웨어적으로 차단(Lock)합니다.
  if (sys.state == STATE_HOMING) {
    st.step_outbits &= sys.homing_axis_lock;
  }

  st.step_count--; // 잔여 스텝 이벤트 카운터 차감
  if (st.step_count == 0) {
    // 본 스텝 세그먼트 구동이 완전히 끝났습니다. 해당 세그먼트 연결을 해제하고
    // 링 버퍼 꼬리(Tail) 인덱스를 한 칸 전진시킵니다.
    st.exec_segment = NULL;
    if (++segment_buffer_tail == SEGMENT_BUFFER_SIZE) {
      segment_buffer_tail = 0;
    }
  }

  st.step_outbits ^=
      step_port_invert_mask; // 스텝 포트 출력 논리 반전 마스크 적용
  busy = false;
}

/* "스텝 포트 리셋 인터럽트 (The Stepper Port Reset Interrupt)": Timer0
   오버플로우(OVF) 인터럽트는 스텝 펄스의 하강 엣지(Falling edge)를 제어합니다.
   이 인터럽트는 항상 다음 Timer1 COMPA 인터럽트가 발생하기 전에 구동되어야
   하며, 모션이 완료되어 Timer1이 비활성화되더라도 독립적으로 완료 처리를
   수행합니다. 주의: 시리얼 통신 인터럽트와 스텝 모터 인터럽트 간의 충돌로 인해
   수 마이크로초 정도의 실행 지연이 생길 수 있습니다. 큰 문제는 아니지만, 매우
   높은 속도로 구동 중일 때 Grbl에 고주파 비동기 인터럽트가 추가되면 영향을 미칠
   수 있습니다.
*/
// 이 인터럽트는 메인 ISR(Timer1 COMPA)이 모터 핀에 스텝 펄스를 인가할 때
// 활성화됩니다. 설정된 펄스 폭 시간(settings.pulse_microseconds)이 지나면 이
// ISR이 트리거되어 스텝 핀을 복귀(Reset)시킴으로써 1개 스텝 주기를 완료합니다.
ISR(TIMER0_OVF_vect) {
  // 스텝 핀들을 원위치로 복귀시킵니다. (방향 핀의 상태는 유지)
  STEP_PORT = (STEP_PORT & ~STEP_MASK) | (step_port_invert_mask & STEP_MASK);
  TCCR0B = 0; // 불필요한 중복 인터럽트 트리거를 막기 위해 Timer0을 즉시
              // 비활성화합니다.
}
#ifdef STEP_PULSE_DELAY
// STEP_PULSE_DELAY 옵션이 활성화된 경우에만 이 인터럽트가 빌드에 포함됩니다.
// 이 모드에서는 지정된 지연 시간이 경과한 후에 스텝 펄스가 공식적으로
// 인가됩니다. 그 후 일반 동작과 같이 설정된 펄스 폭이 끝나면 Timer0 OVF
// 인터럽트가 트리거되어 펄스를 해제합니다. 방향 결정, 스텝 펄스 시작 및 펄스
// 완료 이벤트 간의 동적 타이밍은 st_wake_up() 함수에서 셋업됩니다.
ISR(TIMER0_COMPA_vect) {
  STEP_PORT = st.step_bits; // 스텝 펄스 상승엣지 인가 시작
}
#endif

// 스텝 모터 드라이버 인터럽트에서 사용되는 스텝 및 방향 포트 출력 반전
// 마스크(Invert Mask)를 생성합니다.
void st_generate_step_dir_invert_masks() {
  uint8_t idx;
  step_port_invert_mask = 0;
  dir_port_invert_mask = 0;
  for (idx = 0; idx < N_AXIS; idx++) {
    if (bit_istrue(settings.step_invert_mask, bit(idx))) {
      step_port_invert_mask |= get_step_pin_mask(idx);
    }
    if (bit_istrue(settings.dir_invert_mask, bit(idx))) {
      dir_port_invert_mask |= get_direction_pin_mask(idx);
    }
  }
}

// 스텝 모터 하위 시스템의 실시간 동작 변수들을 초기화(리셋)하고 소거합니다.
void st_reset() {
  // 스텝 드라이버를 대기 상태(Idle)로 초기화합니다.
  st_go_idle();

  // 스텝 모터 알고리즘 제어 변수들을 리셋합니다.
  memset(&prep, 0, sizeof(st_prep_t));
  memset(&st, 0, sizeof(stepper_t));
  st.exec_segment = NULL;
  pl_block = NULL; // 세그먼트 버퍼에서 참조하는 플래너 블록 포인터 초기화
  segment_buffer_tail = 0;
  segment_buffer_head = 0; // 버퍼 비움 (Head = Tail)
  segment_next_head = 1;
  busy = false;

  st_generate_step_dir_invert_masks();
  // st.dir_outbits = dir_port_invert_mask; // 방향 제어 비트를 디폴트 마스크로
  // 초기화

  // 스텝 및 방향 포트 핀들을 초기 반전 조건에 맞추어 기본 출력 레벨로
  // 초기화합니다.
  STEP_PORT = (STEP_PORT & ~STEP_MASK) | step_port_invert_mask;
  // DIRECTION_PORT = (DIRECTION_PORT & ~DIRECTION_MASK) | dir_port_invert_mask;
}

// 스텝 모터 하위 시스템의 하드웨어 주변장치 초기화 및 구동 시작
void stepper_init() {
  // 스텝 및 방향 제어를 위한 하드웨어 핀들의 입출력 방향(DDR) 설정
  STEP_DDR |= STEP_MASK;
  STEPPERS_DISABLE_DDR |= 1 << STEPPERS_DISABLE_BIT;
  DIRECTION_DDR |= DIRECTION_MASK;

  // 타이머 1 구성: 스텝 드라이버 주기적 인터럽트 제어
  TCCR1B &= ~(1 << WGM13); // 타이머 파형 모드 = 0100 = CTC 모드 설정
  TCCR1B |= (1 << WGM12);
  TCCR1A &= ~((1 << WGM11) | (1 << WGM10));
  TCCR1A &= ~((1 << COM1A1) | (1 << COM1A0) | (1 << COM1B1) |
              (1 << COM1B0)); // 외부 OC1 핀 강제 출력 분리
  // TCCR1B = (TCCR1B & ~((1<<CS12) | (1<<CS11))) | (1<<CS10); //
  // st_go_idle()에서 분주기 셋업 처리 TIMSK1 &= ~(1<<OCIE1A);  //
  // st_go_idle()에서 초기 인터럽트 마스킹 처리

  // 타이머 0 구성: 스텝 포트 자동 리셋(Reset) 인터럽트 제어
  TIMSK0 &= ~((1 << OCIE0B) | (1 << OCIE0A) |
              (1 << TOIE0)); // 기존 OC0 및 OVF 인터럽트 마스크 해제
  TCCR0A = 0;                // 표준 타이머 모드로 운용
  TCCR0B = 0;                // 스텝 신호가 들어오기 전까지는 Timer0을 정지
  TIMSK0 |= (1 << TOIE0);    // Timer0 오버플로우 인터럽트 허용
#ifdef STEP_PULSE_DELAY
  TIMSK0 |= (1 << OCIE0A); // Timer0 컴페어 매치 A 인터럽트 허용
#endif

  // 터치 브리지 전용: 가상 핀 입출력 포트 강제 할당 (DDRB, DDRC, DDRD 구성)
  DDRB = 0B110011;
  DDRC = 0B00001111;
  DDRD = 0B111100;
}

// Called by planner_recalculate() when the executing block is updated by the
// new plan.
void st_update_plan_block_parameters() {
  if (pl_block != NULL) { // Ignore if at start of a new block.
    prep.recalculate_flag |= PREP_FLAG_RECALCULATE;
    pl_block->entry_speed_sqr =
        prep.current_speed * prep.current_speed; // Update entry speed.
    pl_block = NULL; // Flag st_prep_segment() to load and check active velocity
                     // profile.
  }
}

// Increments the step segment buffer block data ring buffer.
static uint8_t st_next_block_index(uint8_t block_index) {
  block_index++;
  if (block_index == (SEGMENT_BUFFER_SIZE - 1)) {
    return (0);
  }
  return (block_index);
}

#ifdef PARKING_ENABLE
// Changes the run state of the step segment buffer to execute the special
// parking motion.
void st_parking_setup_buffer() {
  // Store step execution data of partially completed block, if necessary.
  if (prep.recalculate_flag & PREP_FLAG_HOLD_PARTIAL_BLOCK) {
    prep.last_st_block_index = prep.st_block_index;
    prep.last_steps_remaining = prep.steps_remaining;
    prep.last_dt_remainder = prep.dt_remainder;
    prep.last_step_per_mm = prep.step_per_mm;
  }
  // Set flags to execute a parking motion
  prep.recalculate_flag |= PREP_FLAG_PARKING;
  prep.recalculate_flag &= ~(PREP_FLAG_RECALCULATE);
  pl_block = NULL; // Always reset parking motion to reload new block.
}

// Restores the step segment buffer to the normal run state after a parking
// motion.
void st_parking_restore_buffer() {
  // Restore step execution data and flags of partially completed block, if
  // necessary.
  if (prep.recalculate_flag & PREP_FLAG_HOLD_PARTIAL_BLOCK) {
    st_prep_block = &st_block_buffer[prep.last_st_block_index];
    prep.st_block_index = prep.last_st_block_index;
    prep.steps_remaining = prep.last_steps_remaining;
    prep.dt_remainder = prep.last_dt_remainder;
    prep.step_per_mm = prep.last_step_per_mm;
    prep.recalculate_flag =
        (PREP_FLAG_HOLD_PARTIAL_BLOCK | PREP_FLAG_RECALCULATE);
    prep.req_mm_increment =
        REQ_MM_INCREMENT_SCALAR / prep.step_per_mm; // Recompute this value.
  } else {
    prep.recalculate_flag = false;
  }
  pl_block = NULL; // Set to reload next block.
}
#endif

/* Prepares step segment buffer. Continuously called from main program.

   The segment buffer is an intermediary buffer interface between the execution
   of steps by the stepper algorithm and the velocity profiles generated by the
   planner. The stepper algorithm only executes steps within the segment buffer
   and is filled by the main program when steps are "checked-out" from the first
   block in the planner buffer. This keeps the step execution and planning
   optimization processes atomic and protected from each other. The number of
   steps "checked-out" from the planner buffer and the number of segments in the
   segment buffer is sized and computed such that no operation in the main
   program takes longer than the time it takes the stepper algorithm to empty it
   before refilling it. Currently, the segment buffer conservatively holds
   roughly up to 40-50 msec of steps. NOTE: Computation units are in steps,
   millimeters, and minutes.
*/
void st_prep_buffer() {
  // Block step prep buffer, while in a suspend state and there is no suspend
  // motion to execute.
  if (bit_istrue(sys.step_control, STEP_CONTROL_END_MOTION)) {
    return;
  }

  while (segment_buffer_tail !=
         segment_next_head) { // Check if we need to fill the buffer.

    // Determine if we need to load a new planner block or if the block needs to
    // be recomputed.
    if (pl_block == NULL) {

      // Query planner for a queued block
      if (sys.step_control & STEP_CONTROL_EXECUTE_SYS_MOTION) {
        pl_block = plan_get_system_motion_block();
      } else {
        pl_block = plan_get_current_block();
      }
      if (pl_block == NULL) {
        return;
      } // No planner blocks. Exit.

      // Check if we need to only recompute the velocity profile or load a new
      // block.
      if (prep.recalculate_flag & PREP_FLAG_RECALCULATE) {

#ifdef PARKING_ENABLE
        if (prep.recalculate_flag & PREP_FLAG_PARKING) {
          prep.recalculate_flag &= ~(PREP_FLAG_RECALCULATE);
        } else {
          prep.recalculate_flag = false;
        }
#else
        prep.recalculate_flag = false;
#endif

      } else {

        // Load the Bresenham stepping data for the block.
        prep.st_block_index = st_next_block_index(prep.st_block_index);

        // Prepare and copy Bresenham algorithm segment data from the new
        // planner block, so that when the segment buffer completes the planner
        // block, it may be discarded when the segment buffer finishes the
        // prepped block, but the stepper ISR is still executing it.
        st_prep_block = &st_block_buffer[prep.st_block_index];
        st_prep_block->direction_bits = pl_block->direction_bits;
        uint8_t idx;
#ifndef ADAPTIVE_MULTI_AXIS_STEP_SMOOTHING
        for (idx = 0; idx < N_AXIS; idx++) {
          st_prep_block->steps[idx] = (pl_block->steps[idx] << 1);
        }
        st_prep_block->step_event_count = (pl_block->step_event_count << 1);
#else
        // With AMASS enabled, simply bit-shift multiply all Bresenham data by
        // the max AMASS level, such that we never divide beyond the original
        // data anywhere in the algorithm. If the original data is divided, we
        // can lose a step from integer roundoff.
        for (idx = 0; idx < N_AXIS; idx++) {
          st_prep_block->steps[idx] = pl_block->steps[idx] << MAX_AMASS_LEVEL;
        }
        st_prep_block->step_event_count = pl_block->step_event_count
                                          << MAX_AMASS_LEVEL;
#endif

        // Initialize segment buffer data for generating the segments.
        prep.steps_remaining = (float)pl_block->step_event_count;
        prep.step_per_mm = prep.steps_remaining / pl_block->millimeters;
        prep.req_mm_increment = REQ_MM_INCREMENT_SCALAR / prep.step_per_mm;
        prep.dt_remainder = 0.0; // Reset for new segment block

        if ((sys.step_control & STEP_CONTROL_EXECUTE_HOLD) ||
            (prep.recalculate_flag & PREP_FLAG_DECEL_OVERRIDE)) {
          // New block loaded mid-hold. Override planner block entry speed to
          // enforce deceleration.
          prep.current_speed = prep.exit_speed;
          pl_block->entry_speed_sqr = prep.exit_speed * prep.exit_speed;
          prep.recalculate_flag &= ~(PREP_FLAG_DECEL_OVERRIDE);
        } else {
          prep.current_speed = sqrt(pl_block->entry_speed_sqr);
        }

#ifdef VARIABLE_SPINDLE
        // Setup laser mode variables. PWM rate adjusted motions will always
        // complete a motion with the spindle off.
        st_prep_block->is_pwm_rate_adjusted = false;
        if (settings.flags & BITFLAG_LASER_MODE) {
          if (pl_block->condition & PL_COND_FLAG_SPINDLE_CCW) {
            // Pre-compute inverse programmed rate to speed up PWM updating per
            // step segment.
            prep.inv_rate = 1.0 / pl_block->programmed_rate;
            st_prep_block->is_pwm_rate_adjusted = true;
          }
        }
#endif
      }

      /* ---------------------------------------------------------------------------------
       Compute the velocity profile of a new planner block based on its entry
       and exit speeds, or recompute the profile of a partially-completed
       planner block if the planner has updated it. For a commanded
       forced-deceleration, such as from a feed hold, override the planner
       velocities and decelerate to the target exit speed.
      */
      prep.mm_complete =
          0.0; // Default velocity profile complete at 0.0mm from end of block.
      float inv_2_accel = 0.5 / pl_block->acceleration;
      if (sys.step_control &
          STEP_CONTROL_EXECUTE_HOLD) { // [Forced Deceleration to Zero Velocity]
        // Compute velocity profile parameters for a feed hold in-progress. This
        // profile overrides the planner block profile, enforcing a deceleration
        // to zero speed.
        prep.ramp_type = RAMP_DECEL;
        // Compute decelerate distance relative to end of block.
        float decel_dist =
            pl_block->millimeters - inv_2_accel * pl_block->entry_speed_sqr;
        if (decel_dist < 0.0) {
          // Deceleration through entire planner block. End of feed hold is not
          // in this block.
          prep.exit_speed =
              sqrt(pl_block->entry_speed_sqr -
                   2 * pl_block->acceleration * pl_block->millimeters);
        } else {
          prep.mm_complete = decel_dist; // End of feed hold.
          prep.exit_speed = 0.0;
        }
      } else { // [Normal Operation]
        // Compute or recompute velocity profile parameters of the prepped
        // planner block.
        prep.ramp_type = RAMP_ACCEL; // Initialize as acceleration ramp.
        prep.accelerate_until = pl_block->millimeters;

        float exit_speed_sqr;
        float nominal_speed;
        if (sys.step_control & STEP_CONTROL_EXECUTE_SYS_MOTION) {
          prep.exit_speed = exit_speed_sqr =
              0.0; // Enforce stop at end of system motion.
        } else {
          exit_speed_sqr = plan_get_exec_block_exit_speed_sqr();
          prep.exit_speed = sqrt(exit_speed_sqr);
        }

        nominal_speed = plan_compute_profile_nominal_speed(pl_block);
        float nominal_speed_sqr = nominal_speed * nominal_speed;
        float intersect_distance =
            0.5 * (pl_block->millimeters +
                   inv_2_accel * (pl_block->entry_speed_sqr - exit_speed_sqr));

        if (pl_block->entry_speed_sqr >
            nominal_speed_sqr) { // Only occurs during override reductions.
          prep.accelerate_until =
              pl_block->millimeters -
              inv_2_accel * (pl_block->entry_speed_sqr - nominal_speed_sqr);
          if (prep.accelerate_until <= 0.0) { // Deceleration-only.
            prep.ramp_type = RAMP_DECEL;
            // prep.decelerate_after = pl_block->millimeters;
            // prep.maximum_speed = prep.current_speed;

            // Compute override block exit speed since it doesn't match the
            // planner exit speed.
            prep.exit_speed =
                sqrt(pl_block->entry_speed_sqr -
                     2 * pl_block->acceleration * pl_block->millimeters);
            prep.recalculate_flag |=
                PREP_FLAG_DECEL_OVERRIDE; // Flag to load next block as
                                          // deceleration override.

            // TODO: Determine correct handling of parameters in
            // deceleration-only. Can be tricky since entry speed will be
            // current speed, as in feed holds. Also, look into near-zero speed
            // handling issues with this.

          } else {
            // Decelerate to cruise or cruise-decelerate types. Guaranteed to
            // intersect updated plan.
            prep.decelerate_after =
                inv_2_accel * (nominal_speed_sqr - exit_speed_sqr);
            prep.maximum_speed = nominal_speed;
            prep.ramp_type = RAMP_DECEL_OVERRIDE;
          }
        } else if (intersect_distance > 0.0) {
          if (intersect_distance <
              pl_block->millimeters) { // 사다리꼴 또는 삼각형 프로파일 유형
            // 참고: 가속-크루즈 및 크루즈 전용 유형의 경우, 다음 계산 결과는
            // 0.0이 됩니다.
            prep.decelerate_after =
                inv_2_accel * (nominal_speed_sqr - exit_speed_sqr);
            if (prep.decelerate_after < intersect_distance) { // 사다리꼴 유형
              prep.maximum_speed = nominal_speed;
              if (pl_block->entry_speed_sqr == nominal_speed_sqr) {
                // 크루즈-감속 또는 크루즈 전용 유형
                prep.ramp_type = RAMP_CRUISE;
              } else {
                // 완전 사다리꼴 또는 가속-크루즈 유형
                prep.accelerate_until -=
                    inv_2_accel *
                    (nominal_speed_sqr - pl_block->entry_speed_sqr);
              }
            } else { // 삼각형 유형
              prep.accelerate_until = intersect_distance;
              prep.decelerate_after = intersect_distance;
              prep.maximum_speed =
                  sqrt(2.0 * pl_block->acceleration * intersect_distance +
                       exit_speed_sqr);
            }
          } else { // 감속 전용 유형
            prep.ramp_type = RAMP_DECEL;
            // prep.decelerate_after = pl_block->millimeters;
            // prep.maximum_speed = prep.current_speed;
          }
        } else { // 가속 전용 유형
          prep.accelerate_until = 0.0;
          // prep.decelerate_after = 0.0;
          prep.maximum_speed = prep.exit_speed;
        }
      }

#ifdef VARIABLE_SPINDLE
      bit_true(
          sys.step_control,
          STEP_CONTROL_UPDATE_SPINDLE_PWM); // 블록을 업데이트할 때마다 스핀들
                                            // PWM 강제 업데이트를 지시합니다.
#endif
    }

    // 새로운 세그먼트 초기화
    segment_t *prep_segment = &segment_buffer[segment_buffer_head];

    // 새로운 세그먼트가 현재 세그먼트 데이터 블록을 가리키도록 설정합니다.
    prep_segment->st_block_index = prep.st_block_index;

    /*------------------------------------------------------------------------------------
      세그먼트 시간(DT_SEGMENT) 동안 이동한 총 거리를 확인하여 이 새로운
      세그먼트의 평균 속도를 계산합니다. 아래 코드는 먼저 현재의 가속/감속(ramp)
      상태에 따라 하나의 온전한 세그먼트를 생성하려고 시도합니다. 만약 가속/감속
      상태의 전환으로 인해 세그먼트 시간이 채워지지 않은 채(incomplete)
      종료되면, 남은 세그먼트 실행 시간을 채우기 위해 다음 가속/감속 상태로
      루프를 계속 진행합니다. 그러나 불완전한 세그먼트가 전체 속도 프로파일의
      끝에서 끝나는 경우, 실행 시간이 DT_SEGMENT보다 짧더라도 해당 세그먼트는
      완료된 것으로 간주합니다.

      속도 프로파일은 항상 '가속(acceleration ramp) -> 크루즈(cruising state) ->
      감속(deceleration ramp)'의 순서로 진행되는 것으로 가정합니다. 각 단계의
      이동 거리는 0에서 해당 블록 전체 길이까지의 범위를 가질 수 있습니다. 속도
      프로파일은 일반적으로 플래너 블록의 끝에서 끝나거나, 피드 홀드 등으로 인한
      강제 감속이 끝나는 블록 중간에서 끝날 수 있습니다.
    */
    float dt_max = DT_SEGMENT; // 최대 세그먼트 시간
    float dt = 0.0;            // 세그먼트 시간 초기화
    float time_var = dt_max;   // 시간 임시 변수
    float mm_var;              // mm 단위 거리 임시 변수
    float speed_var;           // 속도 임시 변수
    float mm_remaining =
        pl_block
            ->millimeters; // 블록 끝에서부터 새로운 세그먼트까지의 남은 거리
    float minimum_mm =
        mm_remaining -
        prep.req_mm_increment; // 최소 한 스텝 이상을 보장하기 위한 최소 거리
    if (minimum_mm < 0.0) {
      minimum_mm = 0.0;
    }

    do {
      switch (prep.ramp_type) {
      case RAMP_DECEL_OVERRIDE:
        speed_var = pl_block->acceleration * time_var;
        mm_var = time_var * (prep.current_speed - 0.5 * speed_var);
        mm_remaining -= mm_var;
        if ((mm_remaining < prep.accelerate_until) || (mm_var <= 0)) {
          // 감속 오버라이드의 경우 크루즈 또는 크루즈-감속 유형만 해당됩니다.
          mm_remaining = prep.accelerate_until; // 참고: EOB(블록 끝)에서 0.0
          time_var = 2.0 * (pl_block->millimeters - mm_remaining) /
                     (prep.current_speed + prep.maximum_speed);
          prep.ramp_type = RAMP_CRUISE;
          prep.current_speed = prep.maximum_speed;
        } else { // 감속 오버라이드 램프 도중
          prep.current_speed -= speed_var;
        }
        break;
      case RAMP_ACCEL:
        // 참고: 가속 램프는 첫 번째 do-while 루프 동안에만 계산됩니다.
        speed_var = pl_block->acceleration * time_var;
        mm_remaining -= time_var * (prep.current_speed + 0.5 * speed_var);
        if (mm_remaining < prep.accelerate_until) { // 가속 램프 끝
          // 가속-크루즈, 가속-감속 램프 접점 또는 블록 끝
          mm_remaining = prep.accelerate_until; // 참고: EOB(블록 끝)에서 0.0
          time_var = 2.0 * (pl_block->millimeters - mm_remaining) /
                     (prep.current_speed + prep.maximum_speed);
          if (mm_remaining == prep.decelerate_after) {
            prep.ramp_type = RAMP_DECEL;
          } else {
            prep.ramp_type = RAMP_CRUISE;
          }
          prep.current_speed = prep.maximum_speed;
        } else { // 가속 전용
          prep.current_speed += speed_var;
        }
        break;
      case RAMP_CRUISE:
        // 참고: mm_var는 불완전한 세그먼트의 time_var 계산을 위해 마지막
        // mm_remaining 값을 유지하는 데 사용됩니다. 참고: maximum_speed *
        // time_var 값이 너무 작으면, 반올림 오차로 인해 mm_var가 변경되지 않을
        // 수 있습니다.
        //       이를 방지하기 위해 플래너에서 최소 속도 임계값을 적용해야
        //       합니다.
        mm_var = mm_remaining - prep.maximum_speed * time_var;
        if (mm_var < prep.decelerate_after) { // 크루즈 끝
          // 크루즈-감속 접점 또는 블록 끝
          time_var =
              (mm_remaining - prep.decelerate_after) / prep.maximum_speed;
          mm_remaining = prep.decelerate_after; // 참고: EOB(블록 끝)에서 0.0
          prep.ramp_type = RAMP_DECEL;
        } else { // 크루즈 전용
          mm_remaining = mm_var;
        }
        break;
      default: // case RAMP_DECEL:
        // 참고: mm_var는 속도가 0에 가까울 때 오류를 방지하기 위한 임시 변수로
        // 사용됩니다.
        speed_var =
            pl_block->acceleration * time_var; // 속도 변화량(mm/min)으로 사용
        if (prep.current_speed > speed_var) {  // 속도가 0 이하인지 확인합니다.
          // 세그먼트 끝에서 블록 끝까지의 거리를 계산합니다.
          mm_var = mm_remaining -
                   time_var * (prep.current_speed - 0.5 * speed_var); // (mm)
          if (mm_var > prep.mm_complete) { // 일반적인 경우. 감속 램프에 있음.
            mm_remaining = mm_var;
            prep.current_speed -= speed_var;
            break; // 세그먼트 완료. switch-case 문을 종료하고 do-while 루프를
                   // 계속 진행합니다.
          }
        }
        // 그렇지 않으면, 블록의 끝이거나 강제 감속의 끝입니다.
        time_var = 2.0 * (mm_remaining - prep.mm_complete) /
                   (prep.current_speed + prep.exit_speed);
        mm_remaining = prep.mm_complete;
        prep.current_speed = prep.exit_speed;
      }
      dt += time_var; // 계산된 램프 시간을 총 세그먼트 시간에 더합니다.
      if (dt < dt_max) {
        time_var = dt_max - dt;
      } // **불완전함** 램프 접점 부근.
      else {
        if (mm_remaining >
            minimum_mm) { // 스텝이 0인 매우 느린 세그먼트가 있는지 확인합니다.
          // 세그먼트 내에 최소 한 스텝이 포함되도록 세그먼트 시간을 늘립니다.
          // minimum_mm 또는 mm_complete에 도달할 때까지 거리 계산을
          // 오버라이드하고 루프를 반복합니다.
          dt_max += DT_SEGMENT;
          time_var = dt_max - dt;
        } else {
          break; // **완료** 루프 탈출. 세그먼트 실행 시간이 최대치에
                 // 도달했습니다.
        }
      }
    } while (mm_remaining > prep.mm_complete); // **완료** 루프 탈출. 속도
                                               // 프로파일이 완료되었습니다.

#ifdef VARIABLE_SPINDLE
    /* -----------------------------------------------------------------------------------
       스텝 세그먼트에 대한 스핀들 속도 PWM 출력을 계산합니다.
    */

    if (st_prep_block->is_pwm_rate_adjusted ||
        (sys.step_control & STEP_CONTROL_UPDATE_SPINDLE_PWM)) {
      if (pl_block->condition &
          (PL_COND_FLAG_SPINDLE_CW | PL_COND_FLAG_SPINDLE_CCW)) {
        float rpm = pl_block->spindle_speed;
        // 참고: 피드레이트(Feed) 및 급속 이송(Rapid) 오버라이드는 PWM 값과
        // 무관하며 레이저 출력/비율을 변경하지 않습니다.
        if (st_prep_block->is_pwm_rate_adjusted) {
          rpm *= (prep.current_speed * prep.inv_rate);
        }
        // 만약 current_speed가 0이면 rpm_min * (100 /
        // MAX_SPINDLE_SPEED_OVERRIDE)가 되어야 할 수 있으나, 이는 이송 중에
        // 일시적으로만 발생하므로 거의 영향을 미치지 않습니다.
        prep.current_spindle_pwm = spindle_compute_pwm_value(rpm);
      } else {
        sys.spindle_speed = 0.0;
        prep.current_spindle_pwm = SPINDLE_PWM_OFF_VALUE;
      }
      bit_false(sys.step_control, STEP_CONTROL_UPDATE_SPINDLE_PWM);
    }
    prep_segment->spindle_pwm =
        prep.current_spindle_pwm; // 세그먼트 PWM 값 재로드

#endif

    /* -----------------------------------------------------------------------------------
       세그먼트 스텝 레이트, 실행할 스텝 수를 계산하고 필요한 레이트 보정을
       적용합니다.

       참고: 스텝 수는 각 세그먼트마다 실행된 스텝을 누적하여 합산하는 방식이
       아니라, 블록에 남아 있는 밀리미터 거리를 스텝 단위로 직접 변환(scalar
       conversion)하여 계산합니다. 이는 여러 번의 덧셈 과정에서 발생할 수 있는
       부동소수점 반올림 오차 문제를 방지하는 데 도움이 됩니다. 그러나 float
       형식은 7.2 자리의 유효숫자만을 가지므로, 매우 높은 스텝 수를 가진 장거리
       이동의 경우 float의 정밀도를 초과하여 스텝 유실이 발생할 수 있습니다.
       다행히 Grbl이 지원하는 일반적인 CNC 장비(예: 200 step/mm 설정에서 축 이동
       거리가 10미터를 초과하는 경우)에서는 이러한 시나리오가 발생할 가능성이
       극히 희박하며 비현실적입니다.
    */
    float step_dist_remaining =
        prep.step_per_mm * mm_remaining; // mm_remaining을 스텝 단위로 변환
    float n_steps_remaining =
        ceil(step_dist_remaining); // 현재 남은 스텝 수를 올림 처리
    float last_n_steps_remaining =
        ceil(prep.steps_remaining); // 이전 남은 스텝 수를 올림 처리
    prep_segment->n_step =
        last_n_steps_remaining - n_steps_remaining; // 실행할 스텝 수 계산

    // 피드 홀드(일시정지) 끝부분이고 실행할 스텝이 없는 경우 처리를
    // 취소합니다(Bail).
    if (prep_segment->n_step == 0) {
      if (sys.step_control & STEP_CONTROL_EXECUTE_HOLD) {
        // 감속하여 정지 상태에 이르기까지 1스텝 미만으로 남았으나 이미 매우
        // 근접했습니다. AMASS는 실행을 위해 온전한 스텝이 필요하므로 처리를
        // 중단(bail)합니다.
        bit_true(sys.step_control, STEP_CONTROL_END_MOTION);
#ifdef PARKING_ENABLE
        if (!(prep.recalculate_flag & PREP_FLAG_PARKING)) {
          prep.recalculate_flag |= PREP_FLAG_HOLD_PARTIAL_BLOCK;
        }
#endif
        return; // 세그먼트는 생성되지 않았지만 현재 스텝 데이터는 여전히
                // 보존됩니다.
      }
    }

    // 세그먼트 스텝 레이트를 계산합니다. 스텝 수는 정수이고 이동한 mm 거리는
    // 실수이므로, 각 세그먼트의 끝에는 실행되지 않고 남은 다양한 크기의 소수점
    // 단위 부분 스텝(partial step)이 존재할 수 있습니다. 스텝 타이머
    // 인터럽트(ISR)는 AMASS 알고리즘으로 인해 온전한 정수 스텝 단위를
    // 요구하므로, 이를 보정하기 위해 이전 세그먼트의 부분 스텝을 실행하는 데
    // 걸린 시간을 추적하여 현재 세그먼트에 해당 거리와 함께 적용합니다. 이를
    // 통해 전체 세그먼트 레이트를 미세하게 조정하여 스텝 출력을 정확하게 유지할
    // 수 있습니다. 이러한 레이트 조정은 보통 매우 작아서 성능에 악영향을 미치지
    // 않으면서도, Grbl이 플래너가 계산한 정확한 가속 및 속도 프로파일을 출력할
    // 수 있도록 보장합니다.
    dt +=
        prep.dt_remainder; // 이전 세그먼트의 부분 스텝 실행 시간을 적용합니다.
    float inv_rate =
        dt / (last_n_steps_remaining -
              step_dist_remaining); // 조정된 스텝 레이트의 역수(스텝당 시간)를
                                    // 계산합니다.

    // 준비된 세그먼트에 대한 스텝당 CPU 사이클 수(타이머 주기)를 계산합니다.
    uint32_t cycles = ceil(
        (TICKS_PER_MICROSECOND * 1000000 * 60) *
        inv_rate); // (cycles/step)

#ifdef ADAPTIVE_MULTI_AXIS_STEP_SMOOTHING
                   // 스텝 타이밍과 다축 평활화(smoothing) 단계를 계산합니다.
    // 참고: AMASS는 각 단계마다 타이머 오버드라이브를 수행하므로 하나의
    // 분주비(prescaler)만 필요합니다.
    if (cycles < AMASS_LEVEL1) {
      prep_segment->amass_level = 0;
    } else {
      if (cycles < AMASS_LEVEL2) {
        prep_segment->amass_level = 1;
      } else if (cycles < AMASS_LEVEL3) {
        prep_segment->amass_level = 2;
      } else {
        prep_segment->amass_level = 3;
      }
      cycles >>= prep_segment->amass_level;
      prep_segment->n_step <<= prep_segment->amass_level;
    }
    if (cycles < (1UL << 16)) {
      prep_segment->cycles_per_tick = cycles;
    } // < 65536 (16MHz 클럭 기준 4.1ms)
    else {
      prep_segment->cycles_per_tick = 0xffff;
    } // 가능한 가장 느린 속도로 설정합니다.
#else
                   // 일반 스텝 생성을 위한 스텝 타이밍과 타이머
                   // 분주비(prescaler)를 계산합니다.
    if (cycles < (1UL << 16)) {    // < 65536 (16MHz 클럭 기준 4.1ms)
      prep_segment->prescaler = 1; // 분주비: 1
      prep_segment->cycles_per_tick = cycles;
    } else if (cycles < (1UL << 19)) { // < 524288 (16MHz 클럭 기준 32.8ms)
      prep_segment->prescaler = 2;     // 분주비: 8
      prep_segment->cycles_per_tick = cycles >> 3;
    } else {
      prep_segment->prescaler = 3; // 분주비: 64
      if (cycles < (1UL << 22)) {  // < 4194304 (16MHz 클럭 기준 262ms)
        prep_segment->cycles_per_tick = cycles >> 6;
      } else { // 가능한 가장 느린 속도로 설정합니다. (초당 약 4스텝 수준)
        prep_segment->cycles_per_tick = 0xffff;
      }
    }
#endif

    // Segment complete! Increment segment buffer indices, so stepper ISR can
    // immediately execute it.
    segment_buffer_head = segment_next_head;
    if (++segment_next_head == SEGMENT_BUFFER_SIZE) {
      segment_next_head = 0;
    }

    // Update the appropriate planner and segment data.
    pl_block->millimeters = mm_remaining;
    prep.steps_remaining = n_steps_remaining;
    prep.dt_remainder = (n_steps_remaining - step_dist_remaining) * inv_rate;

    // Check for exit conditions and flag to load next planner block.
    if (mm_remaining == prep.mm_complete) {
      // End of planner block or forced-termination. No more distance to be
      // executed.
      if (mm_remaining > 0.0) { // At end of forced-termination.
        // Reset prep parameters for resuming and then bail. Allow the stepper
        // ISR to complete the segment queue, where realtime protocol will set
        // new state upon receiving the cycle stop flag from the ISR.
        // Prep_segment is blocked until then.
        bit_true(sys.step_control, STEP_CONTROL_END_MOTION);
#ifdef PARKING_ENABLE
        if (!(prep.recalculate_flag & PREP_FLAG_PARKING)) {
          prep.recalculate_flag |= PREP_FLAG_HOLD_PARTIAL_BLOCK;
        }
#endif
        return; // Bail!
      } else {  // End of planner block
        // The planner block is complete. All steps are set to be executed in
        // the segment buffer.
        if (sys.step_control & STEP_CONTROL_EXECUTE_SYS_MOTION) {
          bit_true(sys.step_control, STEP_CONTROL_END_MOTION);
          return;
        }
        pl_block =
            NULL; // Set pointer to indicate check and load next planner block.
        plan_discard_current_block();
      }
    }
  }
}

// Called by realtime status reporting to fetch the current speed being
// executed. This value however is not exactly the current speed, but the speed
// computed in the last step segment in the segment buffer. It will always be
// behind by up to the number of segment blocks (-1) divided by the ACCELERATION
// TICKS PER SECOND in seconds.
float st_get_realtime_rate() {
  if (sys.state & (STATE_CYCLE | STATE_HOMING | STATE_HOLD | STATE_JOG |
                   STATE_SAFETY_DOOR)) {
    return prep.current_speed;
  }
  return 0.0f;
}
