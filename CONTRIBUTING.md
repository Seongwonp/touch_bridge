# 기여 안내 (CONTRIBUTING)

이 문서는 Touch Bridge 저장소에서 코드를 고칠 때 지켜야 하는 규칙을 모은 것이다.
빌드·테스트·커밋 절차와, 안전·접근성 때문에 바꾸면 안 되는 코드 계약을 다룬다.
프로젝트 소개는 [README.md](README.md), 앱-하드웨어 명령 규격은
[docs/HW_APP_INTEGRATION_CONTRACT_KO.md](docs/HW_APP_INTEGRATION_CONTRACT_KO.md)와
[docs/ESP32_MOTION_PROTOCOL_V2.md](docs/ESP32_MOTION_PROTOCOL_V2.md), 변경 이력은
[docs/WORK_LOG.md](docs/WORK_LOG.md)를 본다.

## 1. 빌드와 테스트

```bash
cp .env_ex .env          # 클론 직후 1회. .env는 gitignore 대상이며 asset으로 선언돼 있어 없으면 analyze·빌드가 깨진다
flutter pub get
flutter analyze --fatal-infos
flutter test
cd backend && pip install -r requirements.txt && python -m unittest discover -s . -p "test_*.py"
```

- CI(`.github/workflows/ci.yml`)는 push·PR마다 위 네 가지를 그대로 실행한다. 정적 분석은
  info까지 실패로 처리하므로 경고 0건을 유지한다.
- 하드웨어 없이 앱을 돌려 보려면 `flutter run --dart-define=TOUCH_BRIDGE_DEMO=true`.
  플래그가 없으면 기기 목록이 빈 화면으로 뜬다. 상세는 [docs/REPRO_RUNBOOK.md](docs/REPRO_RUNBOOK.md).
- Windows에서 프로젝트·사용자 경로에 한글이 있으면 `flutter test`는 `%TEMP%`를 ASCII
  경로로 바꿔야 돌고, `flutter analyze`는 ASCII 경로 복사본에서만 돈다. 절차는
  [docs/REPRO_RUNBOOK.md](docs/REPRO_RUNBOOK.md) 5절.
- `flutter pub get`이 `linux/`·`macos/`·`windows/`의 생성 파일을 줄바꿈만 바꿔 건드릴 수
  있다. 커밋 전에 되돌린다.
- 자동 테스트는 앱 코드 경로를 고정하는 것이다. 실제 모터 구동·정지 ACK, TalkBack/VoiceOver
  완주, 당사자 평가는 자동 테스트로 대신하지 않으며 문서에서도 완료로 적지 않는다.

## 2. 커밋

- 메시지는 `유형: 요약` 형식의 한국어 한 줄로 시작한다. 유형은 `feat`, `fix`, `docs`,
  `test`, `refactor`, `ci`, `chore`를 쓰고 범위가 분명하면 `feat(backend):`처럼 괄호로 적는다.
- 본문에는 무엇을 왜 바꿨는지와 검증 방법(실행한 명령, 통과 수)을 적는다. 과거 실행
  수치를 현재 결과처럼 재사용하지 않는다.
- 안전 경로(정지·전송·규칙 판정)를 바꾸는 커밋은 그 계약을 고정하는 테스트를 함께 넣는다.
- 공개 이력은 다시 쓰지 않는다(force push 금지). 되돌릴 때는 새 커밋으로 되돌린다.
- 커밋 메시지와 PR 본문에 도구 공동 작성자 표기를 넣지 않는다.

## 3. 코드 계약 — 안전

- **정지 후 잔여 명령 금지.** 긴 시퀀스(여러 버튼, 여러 G-code 줄)를 보내는 코드는 시작
  시 `BleService.motionEpoch`를 기억하고, 그 토큰을 하위 함수까지 인자(`epoch:`)로 넘겨
  매 전송 전과 모든 대기 뒤에 비교한다. 하위에서 토큰을 새로 잡으면 대기 중 들어온 정지가
  새어 나간다. 토큰이 바뀌었으면 보내지 않고 `stoppedByEmergency`로 끝낸다. 정지로 끊긴
  경우 Z 복구 같은 추가 이동 명령도 보내지 않으며, 복구 도중 정지도 같은 규칙이다.
- **정지 판정은 epoch만 보지 않는다.** 실행 화면의 정지 버튼은 실행 토큰이 잡히기 전
  (안내 음성·연결·매핑 로드)부터 보이므로, 화면이 `_stopRequestedThisRun`으로 정지 요청을
  직접 기록하고 전송 함수 호출 직전에 await 없이 확인한다. epoch는 BLE 링크 끊김에도
  바뀌므로 "정지 요청 없이 끊김"은 정지로 취급하지 말고 끝까지 전달하지 못했다고 안내한다.
- **실행 중 화면의 정지는 단일 탭.** 확인 단계 없이 `SingleTapStopController` →
  `EmergencyStopService.stopActiveDevice()`로 간다. 진행 중 중복 탭은 새 요청을 만들지
  않고, 미확인·실패 뒤에는 재시도할 수 있어야 한다. 정지로 끊긴 시퀀스의 결과는 정지
  안내를 덮지 않고(`_lastSequenceStopped`), 미확인·실패면 진행 뷰를 재시도 UI로 유지한다.
  실행 구간에는 STT가 닫혀 있어 음성 "멈춰"는 아직 지원하지 않는다.
- **완료를 단정하지 않는다.** ACK가 없는 경로의 성공 문구는 "…하도록 기기에 전달했습니다"
  까지다. "눌렀습니다", "완료되었습니다", "멈췄습니다"는 장치 ACK를 받은 비상 정지에서만
  쓴다. 타임아웃이나 무관한 알림(`TEMP_OK` 등)은 확인으로 치지 않는다.
- **모션 컨트롤러**는 대기 중 연결 끊김도 감시하고 정지·연결 변경 시 이전 작업을 취소한다.
  타임아웃은 정지 확인으로 안내하지 않는다. 화면 종료 시 `dispose()`를 반드시 부른다.
- **보정이 무효화된 프로필로는 전송하지 않는다.** 사진 경로·크기·수정시각이 바뀌면 실제
  mm 좌표와 캘리브레이션을 무효화하고, 재보정 전에는 일반 제어의 그리드 폴백도 막는다.

## 4. 코드 계약 — 명령 해석

- **규칙 판정 순서.** 앱(`MicrowaveCommandService`)과 백엔드(`microwave_logic`) 모두
  취소·정지 → 부정어면 실행 안 함(AI 경로로) → 전체 일치 규칙만 즉시 실행 순서를 지킨다.
  부분 문자열 `contains`로 실행 명령을 만들지 않는다.
- **무확인 실행은 문법 전체 일치일 때만.** 정규화한 문장이 "시간 + 요청 어미" 문법에
  전체 일치할 때만(`is_plain_time_request`) 확인 없이 실행한다. 남은 글자 수 같은 휴리스틱으로
  안전을 판단하지 않는다. 부정어는 원문 어절 기준으로(문장부호 제거 후) 본다.
- **백엔드 응답은 경로와 무관하게 `sanitize_command_response`를 통과한다.** 규칙·음식 추론
  결과도 예외가 아니다. 20분을 넘는 시간은 잘라서 `needs_confirmation`으로 돌려준다.
  `inferred_seconds`는 실제로 눌리는 버튼의 합이어야 한다.
- AI는 논리 버튼 ID까지만 만든다. 좌표는 기기별 매핑 프로필이 만든다.

## 5. 코드 계약 — 접근성

- **TTS 억제는 명시된 우선순위로만 판단한다.** 스크린리더가 켜져 있으면 `navigation`·
  `info` 우선순위는 억제된다. `interrupt: true`는 선점 플래그일 뿐 억제를 우회하지 않으므로,
  스크린리더에서도 들려야 하는 결과·실패·비상 발화는 `TtsPriority.result` 또는
  `emergency`를 명시한다.
- **음성 화면 `_speak`의 기본 우선순위는 `result`다.** 스크린리더가 대신 읽는 화면 진입
  안내·녹음 상태·화면 이동만 `navigation`을 명시한다. liveRegion(`_statusMessage`)에는
  축약어가 아니라 TTS와 같은 전체 문장을 싣는다.
- **이중 탭 확인은 맥락별로 적용한다.** 위험하거나 되돌리기 어려운 동작은 두 번 탭,
  20초 안에 두 번째 탭이 없으면 취소한다. 스크린리더 활성 시 단순 화면 이동은 OS의
  확인과 겹치지 않도록 앱 확인을 생략하되, 물리 동작·삭제 확인은 스크린리더 사용 여부와
  무관하게 유지한다(`accessibility_confirmation_policy.dart`).
- **Semantics 라벨에 "버튼"을 넣지 않는다.** `button: true`가 역할을 붙인다. 버튼의
  hint는 버튼 위젯 바깥이 아니라 안쪽 라벨에 붙여야 노드에 남는다.
- **카드 하위 텍스트를 `ExcludeSemantics`로 묶을 때는** 부모 `Semantics(onTap:)`을 반드시
  명시한다. 길게 누르기 같은 숨은 제스처는 `CustomSemanticsAction`으로도 노출한다.
- **색상은 토큰으로만.** 새 색이 필요하면 `AppColors`에 토큰을 추가하고 화면에
  `Color(0xFF...)`를 직접 쓰지 않는다. `borderDefault`는 8% 불투명도 테두리 전용이라
  버튼 배경 같은 솔리드 채움에 쓰지 않는다. 색상 대비는
  `test/theme/app_colors_contrast_test.dart`가 검사한다(AA 4.5:1, 핵심 색상 AAA 7:1).
- **200% 글자 확대를 깨지 않는다.** 고정 높이 대신 `ConstrainedBox(minHeight:)`를 쓴다.
- **macOS에서는 TTS/STT를 호출하지 않는다.**
  `if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) return;` 가드를 유지한다.

## 6. 구조

- 화면 전용 컴포넌트는 그 화면의 `widgets/` 하위 디렉터리에 둔다. 화면 파일이 200줄을
  넘기 시작하면 같은 패턴으로 쪼개는 것을 먼저 검토한다.
- 기기 목록은 `HomeDeviceStore`(`home_devices` 키) 한 곳에서만 읽고 쓴다. 버튼 매핑은
  `mapping_profile_<deviceId>` 키에 기기별로 저장한다.
- 보호자 화면 문구는 장치 중립어("터치봉", "현재 위치 눌러보기")를 쓴다. 코드 안의
  `switchbot` 이름은 옛 표기이며, 바꿀 때는 `docs/ESP32_MOTION_PROTOCOL_V2.md`와 테스트를
  함께 고친다.

## 7. 말하지 않을 것

문서·발표·커밋 메시지에서 다음을 완료된 것처럼 적지 않는다.

- 시각장애인 당사자 사용성 평가(계획서만 있다).
- 앱과 펌웨어를 묶은 실기기 E2E, 모터 정지·ACK 실측.
- TalkBack/VoiceOver 전체 과업 완주 검증.
- 프로덕션 보안: 앱 `.env` asset의 정적 노출, 프록시 뒤 레이트리밋 IP 신뢰 설정,
  미프로비저닝 BLE 기기의 fail-open 정책은 재검토 대상이다([docs/SECURITY.md](docs/SECURITY.md)).
