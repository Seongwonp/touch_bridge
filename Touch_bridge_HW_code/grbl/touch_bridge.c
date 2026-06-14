#include "touch_bridge.h"
#include <string.h>
#include <stdlib.h>

// 디폴트값: 3x3 그리드, 원점 (0,0), 간격 20.0mm
GridConfig grid_cfg = {
  .rows = 3,
  .cols = 3,
  .origin_x = 0.0,
  .origin_y = 0.0,
  .pitch_x = 20.0,
  .pitch_y = 20.0
};

// 터치 구동 속도 및 깊이 정의
#define TOUCH_DEPTH_MM   -5.0
#define TOUCH_FEED_RATE   150

// 정수를 문자열로 변환하여 추가하는 헬퍼 함수
static void append_int(char *s, int n) {
  char buf[12];
  itoa(n, buf, 10);
  strcat(s, buf);
}

// 소수점 한자리까지 표시하는 헬퍼 함수
static void append_float1(char *s, float f) {
  int32_t n = (int32_t)(f * 10.0f + (f < 0 ? -0.5f : 0.5f));
  if (n < 0) {
    strcat(s, "-");
    n = -n;
  }
  append_int(s, n / 10);
  strcat(s, ".");
  append_int(s, n % 10);
}

void execute_touch(const char* btn_id)
{
  if (strncmp(btn_id, "BTN_", 4) != 0) {
    printPgmString(PSTR("ERROR:Invalid button ID prefix\r\n"));
    return;
  }

  int btn_num = atoi(btn_id + 4);
  int max_buttons = grid_cfg.rows * grid_cfg.cols;
  if (btn_num < 1 || btn_num > max_buttons) {
    printPgmString(PSTR("ERROR:Button number out of bounds\r\n"));
    return;
  }

  int idx = btn_num - 1;
  int col = idx % grid_cfg.cols;
  int row = idx / grid_cfg.cols;

  float x = grid_cfg.origin_x + (float)col * grid_cfg.pitch_x;
  float y = grid_cfg.origin_y + (float)row * grid_cfg.pitch_y;

  char line_buf[48];

  // 1. G90
  gc_execute_line("G90");

  // 2. G0 X{x} Y{y}
  strcpy(line_buf, "G0 X");
  append_float1(line_buf, x);
  strcat(line_buf, " Y");
  append_float1(line_buf, y);
  gc_execute_line(line_buf);

  // 3. G1 Z-5.0 F150
  strcpy(line_buf, "G1 Z-");
  append_float1(line_buf, (float)(-TOUCH_DEPTH_MM));
  strcat(line_buf, " F");
  append_int(line_buf, TOUCH_FEED_RATE);
  gc_execute_line(line_buf);

  // 4. G4 P0.3
  gc_execute_line("G4 P0.3");

  // 5. G0 Z0.0 F150
  strcpy(line_buf, "G0 Z0.0 F");
  append_int(line_buf, TOUCH_FEED_RATE);
  gc_execute_line(line_buf);

  protocol_buffer_synchronize();

  // 성공 알림
  printPgmString(PSTR("TOUCH_OK:"));
  printString((char*)btn_id);
  printPgmString(PSTR("\r\n"));
}

void update_grid_config(const char* cmd)
{
  // 입력형식: "rows cols ox*10 oy*10 px*10 py*10"
  char *ptr = (char *)cmd;
  int vals[6];
  for(int i=0; i<6; i++) {
    while(*ptr && (*ptr == ' ')) ptr++;
    if(!*ptr) {
      printPgmString(PSTR("ERROR:Missing values\r\n"));
      return;
    }
    vals[i] = atoi(ptr);
    while(*ptr && (*ptr != ' ')) ptr++;
  }

  int r = vals[0];
  int c = vals[1];
  float new_ox = (float)vals[2] / 10.0f;
  float new_oy = (float)vals[3] / 10.0f;
  float new_px = (float)vals[4] / 10.0f;
  float new_py = (float)vals[5] / 10.0f;

  if (r > 0 && c > 0) {
    float max_x = new_ox + (float)(c - 1) * new_px;
    float max_y = new_oy + (float)(r - 1) * new_py;

    if (max_x > settings.max_travel[X_AXIS] || max_y > settings.max_travel[Y_AXIS]) {
      printPgmString(PSTR("ERROR:Grid exceeds limits\r\n"));
      return;
    }

    grid_cfg.rows = r;
    grid_cfg.cols = c;
    grid_cfg.origin_x = new_ox;
    grid_cfg.origin_y = new_oy;
    grid_cfg.pitch_x = new_px;
    grid_cfg.pitch_y = new_py;

    printPgmString(PSTR("GRID_CONFIG_UPDATED\r\n"));
  } else {
    printPgmString(PSTR("ERROR:Invalid rows/cols\r\n"));
  }
}
