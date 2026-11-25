# Touch Bridge 근거자료 출처 감사

> 감사일: 2026-09-04
> 범위: 접근성 M5, FIT0482 X/Y 전환, README 핵심 수치
> 원칙: 표준·플랫폼·법령·제조사 자료는 1차 출처를 우선하며, 해석 자료와
> 학술 연구는 법적/제품 요구사항과 분리한다.

## 출처 등급

- **A — 1차 공식 자료:** 표준 제정기관, 플랫폼 개발사, 법령 원문, 제조사.
- **B — 원 연구/공식 자료 보관본:** 학술 원문 또는 정부 자료를 보관·소개하는
  공공기관 페이지.
- **C — 보조 자료:** 언론, 기관 소개, 포럼. 배경 설명에는 쓸 수 있지만 제품
  사양이나 준수 판정의 단독 근거로 쓰지 않는다.

## 이번 구현에 직접 사용한 자료

| 등급 | 기관·문서 | 확인한 내용 | Touch Bridge 적용 | 상태 |
|---|---|---|---|---|
| A | [W3C, WCAG 2.2](https://www.w3.org/TR/WCAG22/) | 2.5.7 드래그 대안, 2.5.8 타깃 크기, 4.1.2 이름·역할·값 | 드래그 대신 방향 버튼, 최소 터치 영역, Semantics | 확인 |
| A | [W3C, Understanding 2.5.7](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements) | 드래그 기능에는 단일 포인터 대안 필요 | 패널 모서리와 버튼 중심에 0.5% 조그 버튼 | 확인 |
| 참고 | [W3C, WCAG2Mobile](https://www.w3.org/TR/wcag2mobile-22/) | WCAG 2.2를 네이티브·하이브리드 모바일 앱에 적용하는 방법 | 모바일 화면 단위 QA에 참고 | **비규범 Group Draft Note** |
| A | [Android 접근성 원칙](https://developer.android.com/guide/topics/ui/accessibility/principles) | 의미 있는 요소의 목적·라벨 제공 | Flutter Semantics 라벨·역할·상태 | 확인 |
| A | [Android 접근성 테스트](https://developer.android.com/guide/topics/ui/accessibility/testing) | TalkBack 수동 테스트와 실제 사용자 피드백 필요 | TalkBack 실기 QA + 당사자 평가 계획 | 확인 |
| A | [Android 앱 접근성(Views)](https://developer.android.com/guide/topics/ui/accessibility/views/apps-views) | 상호작용 영역 48dp 권장 | 주요 컨트롤 48 logical px 이상 | 확인 |
| A | [Apple VoiceOver 평가 기준](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria) | 보이는 조작은 VoiceOver에서도 가능해야 하며 논리적 탐색 순서 필요 | 화면 이동 확인 중복 제거, 드래그 대안, 실기 평가 | 확인 |
| A | [Flutter Semantics API](https://api.flutter.dev/flutter/widgets/Semantics-class.html) | 플랫폼 접근성 서비스에 전달되는 의미 트리 | label/button/value/liveRegion 구현 | 확인 |
| A | [DFRobot FIT0482 제품 사양](https://www.dfrobot.com/product-1432.html) | 6V, 50:1, 무부하 310RPM, 정격 토크 0.35kg·cm, Hall 해상도 700, 18g | X/Y 후보 모터와 엔코더 폐루프 설계 기준 | 확인 |
| B | [KDI 경제교육·정보센터, 보건복지부 2024년 장애인차별금지법 이행 실태조사 자료](https://eiec.kdi.re.kr/policy/materialView.do?num=269629) | 편의 기능 부족으로 키오스크 이용이 어렵다는 조사 결과 | 문제 정의의 키오스크 통계 | 정부 자료 보관본 |
| A | [국가법령정보센터, 장애인차별금지법](https://www.law.go.kr/LSW/lsInfoP.do?lsId=010420) | 전자정보·비전자정보 접근에서 장애인에게 필요한 수단 제공 원칙 | 접근성을 제품 요구사항으로 취급 | 법률 해석은 전문가 확인 필요 |
| B | [Toucha11y, CHI 2023](https://dl.acm.org/doi/10.1145/3544548.3581254) | 접근 가능한 스마트폰 UI와 물리 터치 로봇의 결합 | 앱/물리 작동 책임 분리의 선행 사례 | 원 연구 |
| B | [BrushLens, UIST 2023](https://dl.acm.org/doi/10.1145/3586183.3606730) | 물리 프록시를 이용한 터치스크린 조작 | 부착형 물리 터치 접근의 선행 사례 | 원 연구 수치는 원문 기준 인용 |

## 표현 교정 기록

- `WCAG2Mobile`은 모바일 앱에 참고할 수 있지만 2025-05-06자 **Group Draft
  Note이며 규범 표준이 아니다**. WCAG 2.2 자체와 동일한 법적 지위로 표현하지
  않는다.
- 장애인차별금지법을 `음성명령 지원 의무`라고 단정하던 문구를 삭제했다.
  법은 정보 접근과 정당한 편의 제공의 근거이며, 음성 명령은 Touch Bridge가
  선택한 접근성 구현 수단이다.
- `77.1%`는 모든 가전 사용자를 대표하는 수치가 아니라 2024년 장애인차별금지법
  이행 실태조사의 **시각장애인 키오스크 이용 응답** 범위로 한정해 쓴다.
- FIT0482의 700 카운트는 제조사 표기의 Hall feedback resolution이다. 실제
  펌웨어에서 상승/하강 에지 계산 방식과 유효 CPR은 실측 후 확정한다.
- 연구 논문의 효과 수치는 실험 장치·환경에 종속된다. Touch Bridge의 성능으로
  전용하지 않고 선행연구 결과로만 표시한다.

## 아직 필요한 1차 검증

- Android TalkBack 실제 기기와 iOS VoiceOver 실제 기기에서 전체 과업 수행.
- 전맹 3명·저시력 3명 분리 평가와 재검증.
- FIT0482 2축의 실측 CPR, 백래시, 스톨 전류, 반복 위치 오차 및 PID 튜닝.
- 스위치봇 누름 성공/실패 ACK와 BLE 재연결 중 중복 실행 방지.
- KS X 3253 최신 원문은 공식 표준 구매/열람본으로 조항과 개정일 재확인.
