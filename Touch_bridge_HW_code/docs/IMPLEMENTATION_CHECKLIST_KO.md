# Touch Bridge HW 구현 체크리스트

## 작업 규칙
- 각 단계 종료 시 반드시:
  1. 테스트 수행
  2. 결과 기록
  3. 관련 문서 최신화

---

## Stage 1. 기준선 정리 (As-Is)
- [x] 현재 명령 파서 상태 확인 (`BTN_`, `BT-`, `PRESS`, `SET_GRID`)
- [x] 현재 터치 실행 경로 확인 (Z축 G-code 기반)
- [x] 현재 핀맵 상태 확인 (`cpu_map_atmega328p.h` 비정상 매핑)
- [x] 기준선 문서화

### As-Is 요약
1. 프로토콜 파서는 확장되어 앱 연동 형식 수용 가능.
2. 실행부는 `G1 Z...` 기반이라 SG90 제어 구조와 불일치.
3. 핀맵은 X/Y/Z/CONTROL 비트가 비정상적으로 겹쳐 있어 실기기 구동 리스크가 큼.

### Stage 1 테스트
- 코드 읽기 기반 구조 검증 완료
- 명령 파서 분기 존재 확인 완료

### Stage 1 문서 최신화
- `APP_HW_PROTOCOL_KO.md` 유지
- 본 체크리스트 문서 생성/기록 완료

---

## Stage 2. 핀맵 정상화 (X/Y 2축 + SG90 전제)
- [x] 실제 배선 기준 핀 테이블 확정 (Uno 기본 매핑 복구 기준)
- [x] `cpu_map_atmega328p.h` 정상 비트맵으로 교정
- [x] Z축 스텝 의존 제거 방향 반영 (Z 핀은 유지하되 SG90 구성에서 미사용 명시)
- [x] CONTROL/LIMIT 핀 충돌 여부 검증 (중복 비트 설정 제거)

### Stage 2 테스트
- [x] 빌드 테스트 (`make -n`으로 빌드 타깃/의존성 확인)
- [ ] 축별 step/dir 펄스 확인 (실기기 연결 대기)

### Stage 2 문서 최신화
- [x] 핀맵 표 문서 반영 (`APP_HW_PROTOCOL_KO.md`)

---

## Stage 3. SG90 터치 엔진 도입
- [x] `servo_init()` 추가 (`touch_bridge_servo_init`)
- [x] 서보 down/up 제어 경로 추가 (`servo_write_angle`)
- [x] `execute_touch()`에서 Z G-code 터치 제거 후 SG90 시퀀스로 전환
- [x] 기본 파라미터(UP/DOWN 각도, dwell) 정의

### Stage 3 테스트
- [x] 코드 경로/명령 파서 반영 확인 (`SET_SERVO`, SG90 호출 경로)
- [ ] 실기기에서 `PRESS x y` 시 XY 이동 + SG90 down/up 확인

### Stage 3 문서 최신화
- [x] SG90 파라미터/명령 문서 반영 (`APP_HW_PROTOCOL_KO.md`)

---

## Stage 4. 런타임 튜닝 명령 추가
- [x] `SET_SERVO` 명령 추가
- [x] `GET_SERVO` 조회 명령 추가
- [x] 범위/형식 검증 및 에러 메시지 정리

### Stage 4 테스트
- [x] 코드 경로 테스트 (`SET_SERVO`, `GET_SERVO` 파서/핸들러 연결)
- [x] 유효/무효 입력 규칙 확인 (범위/동일각도 제한)
- [ ] 실기기에서 파라미터 반영 동작 확인

### Stage 4 문서 최신화
- [x] UART 명령 표 갱신 (`APP_HW_PROTOCOL_KO.md`)

---

## Stage 5. 가변 그리드 통합 검증 (2x2/3x3)
- [ ] 3x3 테스트 시나리오
- [ ] 2x2 테스트 시나리오
- [ ] 범위 초과 에러 처리 검증

### Stage 5 테스트
- [ ] 좌표 전체 커버리지 테스트

### Stage 5 문서 최신화
- [ ] 앱 측 선행 `SET_GRID` 주의사항 재확인

---

## Stage 6. 안정화
- [ ] 응답/에러 메시지 표준화
- [ ] 비상정지/중단 시나리오 점검
- [ ] 회귀 테스트 체크리스트 고정

### Stage 6 테스트
- [ ] end-to-end 시나리오 통과 기록

### Stage 6 문서 최신화
- [ ] 최종 런북/운영 문서 확정
