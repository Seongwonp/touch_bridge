#ifndef TOUCH_BRIDGE_H
#define TOUCH_BRIDGE_H

#include "grbl.h"

// 동적 그리드 파라미터 구조체
typedef struct {
  uint8_t rows;      // 행 개수
  uint8_t cols;      // 열 개수
  float origin_x;    // 첫 번째 버튼의 시작 절대 X 좌표 (mm)
  float origin_y;    // 첫 번째 버튼의 시작 절대 Y 좌표 (mm)
  float pitch_x;     // X축 버튼 간의 간격 (mm)
  float pitch_y;     // Y축 버튼 간의 간격 (mm)
} GridConfig;

extern GridConfig grid_cfg;

// 터치 실행 함수
void execute_touch(const char* btn_id);

// 그리드 설정을 변경하는 함수
void update_grid_config(const char* cmd);

#endif
