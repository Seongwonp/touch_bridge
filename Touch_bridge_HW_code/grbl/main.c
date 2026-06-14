// main.c - rs274/ngc (g-code) 지원 임베디드 CNC 컨트롤러

#include "grbl.h"

// 시스템 전역 변수 구조체 선언
system_t sys;
int32_t sys_position[N_AXIS]; // 스텝(Step) 단위의 실시간 머신(홈) 위치 벡터
int32_t sys_probe_position[N_AXIS]; // 머신 좌표계 및 스텝 단위의 마지막
                                    // 프로빙(Probe) 위치
volatile uint8_t
    sys_probe_state; // 프로빙 상태 값. 스텝 모터 ISR(인터럽트 서비스 루틴)과
                     // 프로빙 주기를 조정하는 데 사용됩니다.
volatile uint8_t
    sys_rt_exec_state; // 상태 관리를 위한 전역 실시간 실행기(Executor)
                       // 비트플래그 변수. EXEC 비트마스크 참조.
volatile uint8_t sys_rt_exec_alarm; // 다양한 시스템 알람 설정을 위한 전역
                                    // 실시간 실행기 비트플래그 변수.
volatile uint8_t
    sys_rt_exec_motion_override; // 모션 기반 오버라이드(이동 속도 등)를 위한
                                 // 전역 실시간 실행기 비트플래그 변수.
volatile uint8_t
    sys_rt_exec_accessory_override; // 스핀들/냉각수(쿨런트) 오버라이드를 위한
                                    // 전역 실시간 실행기 비트플래그 변수.

int main(void) {
  // 전원 투입(Power-up) 시 시스템 초기화 진행
  serial_init();   // 시리얼 보레이트 및 인터럽트 설정
  settings_init(); // EEPROM으로부터 Grbl 설정값 로드
  stepper_init();  // 스텝 모터 핀 및 타이머 인터럽트 구성
  system_init();   // 핀아웃 핀 및 핀 변경 인터럽트(PCI) 구성

  memset(sys_position, 0, sizeof(sys_position)); // 머신 위치 벡터 초기화
  sei();                                         // 글로벌 인터럽트 활성화

// 시스템 초기 상태 설정
#ifdef FORCE_INITIALIZATION_ALARM
         // 전원 리셋 또는 하드 리셋 시 Grbl을 강제로 ALARM(알람) 상태로
         // 진입시킵니다.
  sys.state = STATE_ALARM;
#else
  sys.state = STATE_IDLE;
#endif

// 전원이 켜졌을 때 호밍(Homing)이 활성화되어 있다면 알람 상태로 설정하여 호밍
// 사이클 수행을 강제합니다. 알람 상태에서는 초기 시작 스크립트를 포함한 모든
// G-code 명령어 실행이 차단되며, 오직 설정 변경 및 일부 내부 명령어 접근만
// 허용됩니다. 이 알람 잠금 상태는 호밍 사이클($H)을 완료하거나 알람 강제
// 해제($X) 명령을 통해서만 해제됩니다. 주의: 호밍 사이클이 성공적으로 끝났을
// 때만 기동 스크립트가 실행됩니다. 알람 잠금 해제($X)만 수행한 경우에는 모션
// 시작 블록이 예기치 않게 주변 장치와 충돌하는 위험을 방지하기 위해 기동
// 스크립트가 실행되지 않습니다.
#ifdef HOMING_INIT_LOCK
  if (bit_istrue(settings.flags, BITFLAG_HOMING_ENABLE)) {
    sys.state = STATE_ALARM;
  }
#endif

  bool is_first_run = true;

  // 전원 투입 또는 시스템 중단(Abort) 시 구동되는 Grbl 초기화 루프.
  // 중단 시 모든 프로세스는 이 루프로 돌아와 시스템을 안전하고 깨끗하게
  // 재초기화합니다.
  for (;;) {

    // 시스템 변수 재설정
    uint8_t prior_state = sys.state;
    memset(&sys, 0, sizeof(system_t)); // 시스템 상태 구조체 변수 초기화
    sys.state = prior_state;
    sys.f_override = DEFAULT_FEED_OVERRIDE; // 피드 레이트(이동 속도)
                                            // 오버라이드를 100%로 설정
    sys.r_override =
        DEFAULT_RAPID_OVERRIDE; // 급속 이송(G0) 오버라이드를 100%로 설정
    sys.spindle_speed_ovr =
        DEFAULT_SPINDLE_SPEED_OVERRIDE; // 스핀들 속도 오버라이드를 100%로 설정
    memset(sys_probe_position, 0,
           sizeof(sys_probe_position)); // 프로브 위치 초기화
    sys_probe_state = 0;
    sys_rt_exec_state = 0;
    sys_rt_exec_alarm = 0;
    sys_rt_exec_motion_override = 0;
    sys_rt_exec_accessory_override = 0;

    // Grbl의 주요 하위 시스템 리셋
    serial_reset_read_buffer(); // 시리얼 수신 버퍼 비우기
    gc_init();                  // G-code 파서를 기본 상태로 초기화
    spindle_init();             // 스핀들 초기화
    coolant_init();             // 냉각수 제어 초기화
    limits_init();              // 리미트(한계 스위치) 초기화
    probe_init();               // 프로브(Probe) 센서 초기화
    plan_reset();               // 모션 블록 버퍼 및 플래너(Planner) 변수 초기화
    st_reset();                 // 스텝 모터 구동 하위 시스템 변수 초기화

    // 동기화된 G-code 파서 및 플래너의 위치를 현재 시스템 실질 위치와 동기화
    plan_sync_position();
    gc_sync_position();

    // 초기화 완료 및 부팅 환영 메시지 전송 (전원 온 또는 시스템 리셋이
    // 발생했음을 나타냄)
    report_init_message();

    if (is_first_run) {
      is_first_run = false;
      if (bit_istrue(settings.flags, BITFLAG_HOMING_ENABLE)) {
        sys.state = STATE_HOMING;
        mc_homing_cycle(0);
      }
    }

    // Grbl의 메인 루프 시작. 들어오는 사용자 명령 입력을 분석하고 실행합니다.
    protocol_main_loop();
  }
  return 0; /* 절대 도달하지 않음 */
}
