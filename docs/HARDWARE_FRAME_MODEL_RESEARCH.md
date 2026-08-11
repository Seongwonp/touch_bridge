# Touch Bridge — 하드웨어 프레임 / 3D 모델 리서치

> 작성일: 2026-07-21
> 목적: NK1704S(NEMA17/42mm급) 3축 + TB6600 3개 + Arduino Uno GRBL + ESP32 브릿지 구조에
> 재활용할 수 있는 "다운로드 가능한 3D 프레임/모듈 자료"를 조사하고, Touch Bridge 제약 기준으로
> 검증·재정리한다.
> 관련 문서: [HARDWARE_MIGRATION_PLAN.md](HARDWARE_MIGRATION_PLAN.md), [HARDWARE_TASKS.md](HARDWARE_TASKS.md), [HW_APP_INTEGRATION_CONTRACT_KO.md](HW_APP_INTEGRATION_CONTRACT_KO.md)
> 코드는 수정하지 않았다. 이 문서는 조사·판단 자료다.

## 출처와 검증 상태

- 후보 목록의 1차 수집은 Genspark 웹 검색으로 수행했다(사용자 제공).
- 이 세션에서 아래 3건은 `WebFetch`로 **직접 재검증**했고, 결과를 "검증 노트"에 반영했다:
  - V1E LowRider v4 라이선스/규모 → **CC-BY-NC-SA 4.0, 대형기 확인**
  - bdring midTbot(ESP32) → **STL 포함·ESP32/Grbl_ESP32·CC-BY-SA 4.0 확인** (Genspark는 "라이선스 미표기"라 했으나 실제로는 CC-BY-SA)
  - Bruster999 NEMA17 리니어 액추에이터 → **페이지 파싱 실패, 이번 세션 미검증(플래그)**
- 나머지 링크는 Genspark 보고 기준이며, **파생물 배포/제품화 전에는 각 페이지에서 라이선스를 반드시 재확인**해야 한다. Thingiverse/Printables는 "무표기 = 자유 사용"이 아니다.

---

## 0. 먼저: Touch Bridge 제약이 만든 3가지 필터 (Genspark가 놓친 부분)

리서치 후보 대부분은 **책상 위 수평 펜 플로터**다. Touch Bridge는 그것과 세 가지가 다르며, 이 필터가
순위를 바꾼다.

### 필터 A — CoreXY는 현재 제어 스택과 충돌 (가장 중요)

클래식 **GRBL 1.1(Arduino Uno)** 은 **Cartesian(축=모터 1:1) 전용**이다. CoreXY 운동학은 지원하지 않는다.
즉 Genspark가 TOP 2·3으로 올린 **CoreXY 플로터(#2 suromark, #3 Johannes)** 를 쓰려면 둘 중 하나가 필요하다.

1. CoreXY용 GRBL 포크로 교체, 또는
2. 운동학을 ESP32(FluidNC/grblHAL)로 올려 Uno를 제거.

둘 다 "Arduino Uno + GRBL 유지"라는 [HARDWARE_MIGRATION_PLAN.md](HARDWARE_MIGRATION_PLAN.md) 결정과 어긋난다.
→ **현재 스택 유지 시에는 Cartesian(축당 벨트 1개) 구조가 정답**이다. CoreXY는 "펌웨어를 FluidNC로
바꿀 각오가 있을 때만" 후보다. (아이러니하게 midTbot(#9)이 이미 ESP32+Grbl_ESP32라 그 경로와 잘 맞음)

### 필터 B — 수평 플로터가 아니라 "세로 패널 정면 누름"

전자레인지 버튼면은 대개 수직(또는 경사)면이다. 후보들은 전부 Z가 **아래로** 눌러 수평 베드에 그린다.
Touch Bridge는 Z가 **앞으로** 눌러 수직 패널을 친다. 그래서:

- XY 갠트리를 수직면에서 동작하도록 90° 세워야 한다 → Y축에 **중력 부하**가 상시 걸린다.
  스텝모터 홀딩 토크로 버티되, 전원 차단 시 자중 낙하를 막을 방법(카운터밸런스/브레이크/셀프락 리드스크류)이 필요.
- 벨트 처짐/백래시가 수직 자세에서 더 드러난다 → 짧은 스팬 + 리니어 레일 권장.
- Z는 "중력 방향 누름"이 아니라 "수평 누름"이라 팁 정렬·완충 설계를 이 자세 기준으로 해야 한다.

→ 어떤 후보를 골라도 **수직 마운트 개조**는 공통 필수 작업이다.

### 필터 C — TB6600은 외장 대형 드라이버 (전장 케이스가 안 맞음)

후보 대부분은 A4988/DRV8825(폴로루 스틱)를 **CNC 실드**에 꽂는 전제다. Touch Bridge는
**TB6600 3개(각 ≈96×56×33mm 박스형)** 를 쓴다. 그래서:

- Genspark #12 "Arduino CNC Shield 케이스"는 **드라이버 방식이 달라 부적합**하다(실드용).
- 필요한 것은 갠트리에서 분리된 **별도 전장 박스**: Uno + ESP32 + TB6600×3 + 12V PSU + 퓨즈 +
  물리 E-STOP + 레벨시프터. 고정 설치 가전이라 컨트롤 박스를 옆/뒤에 두고 테더링하면 된다(장점).
- 이 전장 박스는 기성 STL이 잘 없어 **자체 설계 가능성이 높다**(방열/커넥터 컷아웃 포함).

---

## 1. 후보 표 (Touch Bridge 기준 재평가)

적용 가능성은 "현재 Uno+GRBL Cartesian 스택 + 수직 정면 누름" 기준으로 재산정했다.

| # | 이름 / 링크 | 플랫폼 | 구조 | NEMA17/42 | GRBL스택 적합 | 적용성 | 핵심 메모 |
|---|---|---|---|---|---|---|---|
| 1 | **MPCNC LowRider v4** [Printables 1034840](https://www.printables.com/model/1034840-lowrider-4-cnc) · [docs](https://docs.v1e.com/lowrider/) | Printables/TV/GitHub | 대형 XYZ 갠트리 | ✅ (5×NEMA17) | ⚠ Cartesian OK, 단 대형 | **중→하** | 문서·BOM·STEP 최상. 그러나 4'×8'급 **대형** → 소형 재설계 필수. Z(T8 리드스크류+NEMA17)만 떼어 쓰면 좋음 |
| 1b | **MPCNC Primo** (참고) [v1e primo](https://docs.v1e.com/) | GitHub docs | 중형 Cartesian 갠트리 | ✅ | ✅ | **중** | LowRider보다 소형. 그래도 데스크 라우터급. V1E 계열 부품 철학은 동일 |
| 2 | **CoreXY Pen Plotter (suromark)** [Printables 184069](https://www.printables.com/model/184069-corexy-pen-plotter) | Printables/TV | CoreXY | ✅ (2×NEMA17) | ❌ 클래식 GRBL 불가 | **중(조건부)** | 소형·강성 좋음. 단 **CoreXY라 FluidNC/포크 필요**. Z는 SG90 → NEMA17 리드스크류로 교체 |
| 3 | **Pen Plotter core XY (Johannes)** [Printables 573473](https://www.printables.com/model/573473-pen-plotter-core-xy) | Printables/TV | CoreXY(초소형) | ✅ (2×NEMA17) | ❌ 클래식 GRBL 불가 | **중(조건부)** | 작업영역 ~90×110mm(≈A6, 패널 크기와 근접), MGN7H 레일. 단 CoreXY + SG90 Z |
| 4 | **CNC-pen-plotter (DAguirreAg)** [GitHub](https://github.com/DAguirreAg/CNC-pen-plotter) | GitHub | **Cartesian** XY(X 듀얼모터) | ✅ (3×NEMA17) | ✅ **딱 맞음** | **상** | 네이티브 GRBL, README+BOM+회로도. X 듀얼모터=강성. A4988→TB6600 교체만. Z는 서보→리드스크류 개조 |
| 5 | **A4 Pen Plotter (JuanGg)** [TV 2504587](https://www.thingiverse.com/thing:2504587) | Thingiverse | Cartesian XY | ✅ (2×NEMA17 35mm) | ✅ | **중** | 부품 수 적음, A4 풋프린트. Z가 솔레노이드/서보 → 전면 재설계 |
| 6 | **Asmograf (cz7asm)** [TV 3340918](https://www.thingiverse.com/thing:3340918) | Thingiverse | Cartesian XY | ✅ (17HS2408) | ⚠ STM32기반 | 하 | 프레임만 참고. 솔레노이드 Z(제약 위반) |
| 7 | **Pen Plotter (nsgindt)** [TV 4397502](https://www.thingiverse.com/thing:4397502) | Thingiverse | Cartesian XY | ✅ | ✅ | 중 | 단순 A4. Z 리트로핏 필요 |
| 8 | **Scrappy Pen Plotter (Electrondust)** [blog](https://www.electrondust.com/2017/11/12/scrappy-arduino-pen-plotter-nema17-steppers/) | Blog | Cartesian XY | ✅ (2×NEMA17) | ✅ | 하 | 빌드 로그 위주, STL 적음 |
| 9 | **midTbot (bdring)** [GitHub](https://github.com/bdring/midTbot_esp32) · [TV 2587684](https://www.thingiverse.com/thing:2587684) | GitHub/TV | Cartesian + **ESP32 PCB** | ⚠ "소형 스텝모터"(모델 미명시) | ✅(ESP32경로) | **중~상** | **ESP32+Grbl_ESP32 내장** → BLE/Wi-Fi 브릿지 계획과 직결. 전체 3D프린트 섀시. 단 모터가 NEMA17인지 repo에 명시 없음(확인 필요), Z는 서보 |
| 10 | **NEMA17 Linear Actuator (Bruster999)** [Printables 165980](https://www.printables.com/model/165980-nema-17-linear-actuator) | Printables | **Z 리드스크류 모듈** | ✅ 직결 | — | **상(Z부)** | Z 누름부 드롭인 후보. 단 1/4"-20 임페리얼 → **T8 미터법으로 변경 권장**. 저자가 "출력 강하지 않음" 명시. ※이번 세션 미검증 |
| 11 | **CNC Touch Probe (natester)** [TV 4672365](https://www.thingiverse.com/thing:4672365) | Thingiverse | **스프링 완충 프로브** | N/A | — | **상(안전부)** | NC 접점 스프링 프로브 → "버튼 닿음" 하드웨어 확인 신호(GRBL $6 probe). Z 캐리지에 브래킷으로 결합 |
| 12 | ~~Arduino CNC Shield Case (araymbox)~~ [Printables 149788](https://www.printables.com/model/149788-arduino-cnc-shield-case) | Printables | 전장 케이스 | N/A | — | **하(부적합)** | **CNC 실드/폴로루용** → TB6600 외장 방식과 안 맞음(필터 C). 전장 박스는 자체 설계 권장 |

보조 소스(메인 아님, CAD 재활용용):
- **Scalable Pen Plotter** [GitHub](https://github.com/ufficioprogettiperduti/Scalable-Pen-Plotter) — 2×NEMA17+Uno+GRBL, XY 캐리지 CAD 재사용. (SG90 Z라 메인 제외)
- **andrewsleigh/plotter V3** [GitHub](https://github.com/andrewsleigh/plotter) — V-slot 갠트리, 2×NEMA17.
- **OpenSCAD MCAD `stepper.scad`** [GitHub](https://github.com/openscad/MCAD/blob/master/stepper.scad) — `motor(Nema17,...)` 파라메트릭. **GPL**. 마운트 자체 모델링 시 유용.

---

## 2. 검증 노트 (이번 세션 직접 확인 / Genspark 정정)

- **LowRider v4**: 라이선스 **CC-BY-NC-SA 4.0** 확정. 규모는 full/half/quarter 시트(≈4'×8'~4'×2') **대형** 확정, 5×NEMA17. → Touch Bridge엔 과대. **소형 파생 재설계 전제**로만 유효. NC 조항이라 발표·프로토타입은 OK, **판매/제품화는 제약**.
- **midTbot**: STL 폴더 존재·**ESP32+Grbl_ESP32**·USB/BT/WiFi 제어 확정. 라이선스 **CC-BY-SA 4.0**(Genspark "미표기"를 정정). Z=서보 확정. **모터가 NEMA17인지 repo에 명시 없음** → tbot 계열은 통상 NEMA17이나 실제 STL 마운트 치수로 확인 필요.
- **Bruster999 리니어 액추에이터**: 페이지 파싱 실패로 **이번 세션 미검증**. 라이선스/나사 규격은 페이지에서 재확인할 것.
- 표의 "License: not stated" 항목(2,3,4,5,6,7,9,10,11,12)은 **파생물 공개 전 원저자/페이지 확인 필수**.

---

## 3. Z축 누름부 권장 조합 (핵심 안전부)

플로터의 서보/솔레노이드 Z는 전부 제약 위반이므로, **Z는 어느 프레임을 골라도 새로 구성**한다.
아래 조합이 힘·정밀·안전을 동시에 만족한다.

1. **구동**: NEMA17 + **T8 리드스크류**(Bruster999 액추에이터를 T8/미터법으로 개조, 또는 3D프린터 Z모듈 유용).
   - 셀프락 성향의 리드스크류라 **전원 차단 시 자중 낙하 억제**(필터 B 대응)에도 유리.
   - 1.8° + 8mm/rev + 1/16 마이크로스텝 ≈ 0.025mm/step급 해상도.
2. **팁/완충**: natester 스프링 프로브 바디를 **전도성 터치팁 홀더**로 전용.
   - **NC 접점 → GRBL `$6` 프로빙**: 펌웨어가 목표 깊이 전에 "버튼 닿음"을 하드웨어로 감지.
   - 소프트웨어가 실패해도 **스프링 스트로크가 물리적으로 과압 상한**을 만든다(과한 힘 차단).
3. **상한 스톱**: Z 상단 브래킷에 마이크로스위치 → GRBL 하드리밋으로 폭주 시 정지.
4. **소프트 상한**: `$132`(Z max travel)와 `pressDepthZ` 상한을 앱 매핑 프로필에서 강제([HARDWARE_MIGRATION_PLAN.md](HARDWARE_MIGRATION_PLAN.md) 5장 `pressDepthZ` 연계).
5. **최종 안전**: TB6600 ENA 라인을 끊는 **물리 E-STOP(NC)** — [HARDWARE_TASKS.md](HARDWARE_TASKS.md) 비상정지 회로와 동일 원칙.
6. 팁 끝 **TPU/실리콘 스너버**로 접촉 충격 흡수 + 촉각 피드백.

→ 이 6겹(리드스크류 셀프락 → 스프링 완충 → probe 접점 → 하드리밋 → 소프트리밋 → E-STOP)이
"기계가 사람 대신 누른다"는 제품의 안전 서사를 그대로 만든다.

---

## 4. 제어부(전장) 케이스 — 현실 정리

- 기성 CNC-실드 케이스는 **부적합**(TB6600 외장, 필터 C).
- 권장: **오프-갠트리 전장 박스 자체 설계**. 포함: Arduino Uno, ESP32, TB6600×3(방열 간격+팬),
  12V PSU/배럴잭+퓨즈, BSS138 레벨시프터, E-STOP 관통구, 공통 GND 버스.
- 고정 가전이라 박스를 벽/선반에 두고 갠트리와 케이블 테더링 → 갠트리 경량화(수직 자세에 유리).
- 참고 출력물로 "TB6600 enclosure" / "electronics project box parametric"를 별도 검색해 브래킷만 차용.

---

## 5. 최종 판단

### 1) 지금 가장 빠르게 쓸 수 있는 프레임
→ **DAguirreAg CNC-pen-plotter(#4)**. 이유: **네이티브 GRBL + Cartesian**이라 현재 Uno+GRBL 스택에
그대로 얹힌다(필터 A 통과, CoreXY 개조 불필요). 3×NEMA17 전제라 NK1704S 3개 배치와 정합,
드라이버만 A4988→TB6600으로 교체. README/BOM/회로도가 갖춰져 재현이 빠르다.
(대안: 더 다듬어진 부품군을 원하면 MPCNC Primo(#1b)를 소형화.)

### 2) 발표용으로 설명하기 좋은 구조
→ **Cartesian XY(#4, 보조로 #5 A4)**. "가로 레일 1개, 세로 레일 1개, 축당 벨트 1개, 아두이노 1개,
G-code 한 줄 흐름"으로 **슬라이드 한 장에 담긴다**. CoreXY는 강성은 좋지만 벨트 경로가 교차해
청중에게 설명이 어렵다 → 발표에는 Cartesian이 유리.

### 3) 제품화까지 봤을 때 가장 안전한 구조
→ **강성 Cartesian 베이스(리니어 레일) + 3장 Z 안전부 조합**:
Z=NEMA17 T8 리드스크류(#10 개조) + natester 스프링 프로브(#11) + GRBL 하드/소프트 리밋 + 물리 E-STOP(TB6600 ENA).
CoreXY가 강성·반복정밀에서 이론상 낫지만, **현 스택에서 CoreXY는 펌웨어 리스크(필터 A)를 얹으므로**
"안전=단순+검증됨" 기준으론 리니어 레일 Cartesian이 낫다. FluidNC로 전환할 계획이 확정되면
그때 CoreXY 강성 이점을 재검토.

### 4) Z축 누름부 조합
→ **Bruster999 리니어 액추에이터(#10)를 T8로 개조해 구동 + natester 터치 프로브(#11)를 완충·전도팁·
접점 확인으로 결합**. 상세는 위 3장 6겹 안전 구성 그대로. 이게 "리드스크류 힘 + 스프링 완충 +
전도성 터치팁 + 하드웨어 닿음 확인"을 한 모듈에 담는 최적 혼합이다.

---

## 6. 다음 액션 / 미해결

- [ ] midTbot STL의 실제 모터 마운트 치수로 **NEMA17 여부 확정**(현재 repo 미명시).
- [ ] Bruster999 액추에이터 페이지 **재검증**(이번 세션 파싱 실패) + T8 개조 도면화.
- [ ] 타깃 **작업영역 확정**: 전자레인지 버튼면 실측(권장 목표 ~150×120mm) → 프레임 스케일 결정.
- [ ] **수직 마운트 개조안**(필터 B): Y축 중력 부하 대응 — 리드스크류 셀프락 vs 카운터밸런스 결정.
- [ ] **펌웨어 분기 결정**: Uno+클래식 GRBL(Cartesian 고정) 유지 vs ESP32 FluidNC 전환(CoreXY 개방). 이 결정이 프레임 선택을 좌우.
- [ ] TB6600×3 **전장 박스 자체 설계**(필터 C).
- [ ] "not stated" 라이선스 항목 **파생 공개 전 재확인**.

> 라이선스 총평: 발표/프로토타입 용도는 대체로 허용 범위(대표 확인분 — LowRider CC-BY-NC-SA, midTbot CC-BY-SA).
> 단 **판매/제품화**로 가면 NC(비상업) 조항과 SA(동일조건 공유) 의무를 반드시 점검해야 한다.
