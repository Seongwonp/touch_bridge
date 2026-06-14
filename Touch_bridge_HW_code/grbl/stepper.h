// stepper.h - 스텝 모터 드라이버: 스텝 모터를 구동하여 planner.c의 모션 계획을
// 수행합니다.

#ifndef stepper_h
#define stepper_h

#ifndef SEGMENT_BUFFER_SIZE
#define SEGMENT_BUFFER_SIZE 6
#endif

// 스텝 모터 하위 시스템을 초기화하고 설정합니다.
void stepper_init();

// 스텝 모터를 가동시키지만, 모션 제어 또는 실시간 명령에 의한 호출이 없으면
// 모션 사이클은 구동되지 않습니다.
void st_wake_up();

// 스텝 모터를 즉시 대기(Idle) 상태로 전환(비활성화)합니다.
void st_go_idle();

// 스텝 및 방향 포트의 출력 논리 반전 마스크(Invert Mask)를 생성합니다.
void st_generate_step_dir_invert_masks();

// 스텝 모터 하위 시스템의 변수들을 리셋(초기화)합니다.
void st_reset();

// 특수한 파킹(Parking) 모션을 수행하기 위해 스텝 세그먼트 버퍼의 실행 상태를
// 전환합니다.
void st_parking_setup_buffer();

// 파킹 모션 완료 후 스텝 세그먼트 버퍼를 일반 실행 상태로 복원합니다.
void st_parking_restore_buffer();

// 스텝 세그먼트 버퍼를 채웁니다. 실시간 실행 시스템에 의해 연속적으로 자동
// 호출됩니다.
void st_prep_buffer();

// 신규 모션 계획에 의해 현재 실행 중인 블록 파라미터가 업데이트되었을 때
// planner_recalculate()에 의해 호출됩니다.
void st_update_plan_block_parameters();

// config.h에서 실시간 이송 속도 보고 기능이 활성화된 경우 실시간 상태 보고
// 루틴에 의해 호출되어 속도를 구합니다.
float st_get_realtime_rate();

#endif
