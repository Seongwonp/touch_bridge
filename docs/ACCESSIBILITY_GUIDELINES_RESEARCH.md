# Touch Bridge — 접근성 지침 · 법률 조사 (Accessibility Guidelines & Legal Research)

> 작성일: 2026-08-09
> 목적: 전맹~저시력 사용자가 실제로 쓰기 편한 앱을 만들기 위한 **근거 있는 지침**과 **국내 법적 요구**를 정리한다.
> 출처: 1차 수집은 Codex 웹 리서치(2026-08-09). 각 항목에 권위 있는 1차 출처 링크를 병기했으며,
> **출시 전 전맹·저시력 당사자 평가가 반드시 필요**하다.
> 관련: [ACCESSIBILITY_COPY_GUIDE.md](ACCESSIBILITY_COPY_GUIDE.md), [ACCESSIBILITY_REDESIGN_PLAN.md](ACCESSIBILITY_REDESIGN_PLAN.md), [REPRO_RUNBOOK.md](REPRO_RUNBOOK.md)

## 목표 수준

- **WCAG 2.2 AA + 안전·저시력 관련 선택적 AAA**.
- WCAG는 원래 웹 표준이므로 네이티브 Flutter 앱에는 W3C의 **WCAG2Mobile / WCAG2ICT** 해석을 함께 적용한다.
- 국내 출시 기준은 WCAG에 더해 **KS X 3253(모바일 앱 접근성)** 과 **장애인차별금지법**을 함께 만족해야 한다(아래 4장).

---

## 1. 핵심 요약 10

1. 전맹 사용자의 기본 인터페이스는 앱 자체 TTS가 아니라 **정확한 Semantics 트리 + VoiceOver/TalkBack 호환성**이다.
2. 모든 핵심 기능은 화면 탐색으로 발견되는 **명시적 버튼**으로 제공하고, 길게 누르기·스와이프는 보조 단축키로만 둔다.
3. 버튼은 **짧고 고유한 라벨 + 올바른 역할 + 현재 값/상태 + 결과 중심 힌트**를 가진다.
4. 화면 전환 시 접근성 포커스를 **새 화면 제목/핵심 상태**로 논리적으로 이동시킨다.
5. 앱 "두 번 탭"은 **물리 탭을 세지 말고 semantic activation** 기준으로 처리하거나 명시적 확인 화면으로 바꾼다.
6. 스크린리더 사용 중에는 **일반 앱 TTS를 억제**하고 Semantics/live region을 우선한다(중복 낭독 방지).
7. 저시력 모드는 색상뿐 아니라 **시스템 글꼴 200% 확대·리플로우·초점 표시**까지 견뎌야 한다.
8. 텍스트 대비 최소 **AA 4.5:1**, 핵심 조작 텍스트는 **AAA 7:1**, 컨트롤·초점은 최소 **3:1**.
9. 주요 버튼은 **iOS 44pt·Android 48dp 미만 금지**, 핵심 CTA는 **56–64 logical px 이상**.
10. **비상정지는 확인보다 즉시성 우선** — 단일 활성화·음성·명시적 버튼을 모두 허용하고 즉시 상태 피드백.

우선순위: **P0** = 안전/핵심 작업을 막는 문제, **P1** = 중요한 사용성, **P2** = 품질.

---

## 2. 근거 기반 적용 표

| 지침 항목 | 출처 | 기준·수치 | Touch Bridge 적용 | 우선 |
|---|---|---|---|---|
| 네이티브에 WCAG 적용 | [WCAG2Mobile](https://www.w3.org/TR/wcag2mobile-22/) | WCAG 2.2를 모바일 앱에 매핑(방향·리플로우·제스처 대안·타깃) | 출시 기준 AA, 안전·저시력은 선택적 AAA | P0 |
| 텍스트 대비 | [WCAG 1.4.3](https://www.w3.org/TR/WCAG22/#contrast-minimum) | AA 일반 4.5:1, 큰 텍스트 3:1 | 모든 `AppColors` 조합 자동 검사, 보조 회색도 4.5:1 | P0 |
| 강화 대비 | [WCAG 1.4.6](https://www.w3.org/TR/WCAG22/#contrast-enhanced) | AAA 일반 7:1, 큰 텍스트 4.5:1 | 시작·취소·비상정지·연결 상태는 7:1 목표 | P1 |
| 비텍스트 대비 | [WCAG 1.4.11](https://www.w3.org/TR/WCAG22/#non-text-contrast) | 컨트롤 경계·상태가 인접색과 3:1 | 버튼 외곽선·선택 아이콘·포커스 링·매핑 마커 3:1↑ | P0 |
| 텍스트 확대 | [WCAG 1.4.4](https://www.w3.org/TR/WCAG22/#resize-text) | 200% 확대 시 손실 없음 | 1.18배 옵션만으론 부족 → 시스템 스케일 존중 + 200% QA | P0 |
| iOS 글자 크기 | [Apple Typography](https://developer.apple.com/design/human-interface-guidelines/typography) | 기본 17pt, 공식 최소 11pt, Dynamic Type | 본문 내부 기준 18pt↑ 권장(11pt는 하한이지 권장값 아님) | P1 |
| Android 글자 확대 | [Android 14 비선형 글꼴](https://developer.android.com/about/versions/14/features#non-linear-font-scaling) | `sp` 사용, 최대 200% | `MediaQuery.textScaler` 존중, 고정 높이 텍스트 컨테이너 제거 | P0 |
| "큰 텍스트" 정의 | [Understanding 1.4.6](https://www.w3.org/WAI/WCAG22/Understanding/contrast-enhanced) | 18pt 일반 또는 14pt bold(≈24px·18.5px), CJK 동등 | 이는 "최소 글자 크기"가 아니라 저대비 허용 판정값 | P1 |
| 터치 타깃(최소) | [WCAG 2.5.8](https://www.w3.org/TR/WCAG22/#target-size-minimum) | AA 24×24 CSS px | WCAG 최소에 그치지 말고 모든 조작 영역 48×48↑ | P0 |
| 터치 타깃(강화) | [WCAG 2.5.5](https://www.w3.org/TR/WCAG22/#target-size-enhanced) | AAA 44×44 CSS px | 음성·시작·취소·비상정지는 AAA↑ | P0 |
| iOS 컨트롤 크기 | [Apple Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility) | 기본 44×44pt(형식상 최소 28pt 구분) | 28pt 미사용, 44pt를 실질 하한 유지 | P0 |
| Android 컨트롤 크기 | [Android A11y Codelab](https://developer.android.com/codelabs/starting-android-accessibility) | 최소 48×48dp | 아이콘이 작아도 hit area 48dp↑ | P0 |
| 포커스 순서 | [WCAG 2.4.3](https://www.w3.org/TR/WCAG22/#focus-order) · [Traversal order](https://developer.android.com/develop/ui/compose/accessibility/traversal) | 의미·조작 보존 순서 | 제목→현재기기/상태→주동작→보조→내비 순으로 트리 검사 | P0 |
| 포커스 표시 | [WCAG 2.4.13](https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance) | AAA 2 CSS px 둘레, 상태변화 3:1 | 노랑/흰색 2px↑ 링 + offset | P1 |
| 이름·역할·값 | [WCAG 4.1.2](https://www.w3.org/TR/WCAG22/#name-role-value) | AT가 판별 가능 | Flutter `Semantics(label,button,value,checked,enabled,onTap)` 정확히 | P0 |
| VoiceOver 라벨·Trait | [VoiceOver 평가기준](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria) · [Traits](https://developer.apple.com/documentation/uikit/uiaccessibilitytraits) | 라벨 간결·고유, hint는 결과, trait는 실제 역할 | "누르기 버튼" 대신 `label:전자레인지 시작`, `hint:확인 화면을 엽니다` | P0 |
| TalkBack 라벨·행동 | [Android 접근성 원칙](https://developer.android.com/guide/topics/ui/accessibility/principles) | 제스처 동작을 accessibility action으로도 노출 | 카드 롱프레스 수정·매핑·삭제를 명시 버튼/custom action으로 | P0 |
| 라이브 리전·상태 | [WCAG 4.1.3](https://www.w3.org/TR/WCAG22/#status-messages) · [Flutter liveRegion](https://api.flutter.dev/flutter/semantics/SemanticsProperties/liveRegion.html) | 포커스 강제이동 없이 상태 공지 | "연결됨/누르는 중/완료"를 상태 노드로. 일반 polite, 안전 오류만 assertive | P0 |
| Android 공지 변경 | [Android 16 변경](https://developer.android.com/about/versions/16/behavior-changes-all#accessibility) | `announceForAccessibility` 지양, pane title·live region 권장 | `SemanticsService.announce` 남용 제거 → 제목·상태 노드 갱신 | P0 |
| 제스처 대안·발견성 | [Apple A11y HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility) · [모바일 매핑](https://www.w3.org/TR/mobile-accessibility-mapping/) | 핵심 제스처에 화면 대안 제공 | 길게 누르기·스와이프는 단축키로만, 동일 기능 라벨 버튼 항상 제공 | P0 |
| 시간 제한 | [WCAG 2.2.1](https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html) | 끄기/조정/연장, 경고 시 최소 20초 | **현재 이중 탭 4초 만료는 AT 사용자에게 너무 짧음** → 제거/설정화 | P0 |
| 실수 취소 | [WCAG 2.5.2](https://www.w3.org/WAI/WCAG22/Understanding/pointer-cancellation) | up-event 실행, abort/undo | 전송 전 취소, 전송 후 즉시 중단 제공 | P0 |
| 확인·오류 예방 | [WCAG 3.3.6](https://www.w3.org/TR/WCAG22/#error-prevention-all) · [Apple Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) | 중요 동작은 reversible/checked/confirmed | "1분 조리를 시작합니다 / 시작 / 취소"처럼 결과 명시 | P0 |
| 음성 오류 복구 | [Conversation Design: Errors](https://developers.google.com/assistant/conversation-design/errors) | No Match/No Input 구분, 재표현, 반복 후 종료 | "못 알아들음" 대신 "시간을 듣지 못했습니다. '1분 시작'처럼" 2회 실패 후 버튼 안내 | P0 |
| TTS 큐 | [Android TextToSpeech](https://developer.android.com/reference/android/speech/tts/TextToSpeech) · [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer) | 큐·완료 callback 공식 지원 | Singleton TTS에 우선순위·발화 ID·완료 callback·중복 병합. **dispose에서 무조건 stop 금지** | P0 |
| VoiceOver 공지 큐 | [QueueAnnouncement](https://developer.apple.com/documentation/uikit/uiaccessibilityspeechattributequeueannouncement) | 큐잉/인터럽트 선택 | 일반 상태는 큐, 안전 경고만 인터럽트 | P1 |
| Earcon | [Brewster earcon 지침](https://www.researchgate.net/publication/228607856_Experimentally_derived_guidelines_for_the_creation_of_earcons) | 리듬·음색·register 조합, 짧게, 음량만으로 구별 금지, 연속 간 ~0.1초 | 성공·실패·경고에 서로 다른 리듬·음고 윤곽, 음량 설정 존중 | P1 |
| 햅틱 | [Apple Haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics) · [Android Haptics](https://developer.android.com/develop/ui/views/haptics/haptics-principles) | 시스템 패턴, 일관된 의미, 짧게 | 탐색=light, 접수=medium, 실패·위험=error. 햅틱만으로 결과 전달 금지 | P1 |
| **KS X 3253 (모바일 앱)** | [국립전파연구원](https://www.rra.go.kr/ko/reference/kcsList_view.do?nb_seq=1930&nb_type=6) | 2025-12-31 개정. 대체텍스트·입력조작·대비 등 | 국내 출시 QA에 WCAG + KS X 3253 체크리스트 병기 | P0 |
| **KWCAG 2.2** | [KS X OT0003](https://www.rra.go.kr/ko/reference/kcsList_view.do?nb_seq=5247&nb_type=6) · [NIA 안내](https://www.nia.or.kr/site/nia_kor/ex/bbs/View.do?bcIdx=25083&cbIdx=90549) | 한국형 웹 접근성 지침 2.2 | 심사용 웹/Flutter Web 버전에 적용 | P1 |
| **장애인차별금지법** | [법 제21조](https://law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1031812007) · [시행령 제14조](https://www.law.go.kr/LSW/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1031811893) | 스마트폰 앱 포함, 조작 곤란 시 음성명령 지원 명시 | 접근성을 제품 요구사항으로 관리, 스토어 설명에 지원범위 표기 | P0 |

---

## 3. 핵심 질문 결론 (A–E)

### A. 큰 "말하기" 버튼 vs 화면 길게 누르기
**결론: 큰 말하기 버튼을 기본 진입점, 길게 누르기는 선택 단축키.**
- Apple: 제스처 핵심 기능에 화면 대안 제공. W3C 모바일: 커스텀 제스처 설명 + 단일 포인터 대안.
- 스크린리더가 켜지면 표준 터치 제스처 의미가 바뀜(발견성 최악) → 롱프레스 전용 기능 금지.
- 구현: 첫 포커스 근처 `음성으로 말하기, 버튼`(64dp↑), hint "마이크를 엽니다", 롱프레스는 설정에서 켜는 보조.

### B. 성공·실패 earcon 설계
- **"상승음=성공"은 국제표준 아님**(아래는 Brewster 연구 기반 Touch Bridge 프로토타입 권고 = 추정).

| 의미 | 프로토타입 | 햅틱 |
|---|---|---|
| 명령 접수 | 100–150ms 단음 1회 | light |
| 성공 | 협화 2음, 낮음→높음, 300–500ms | 짧은 success |
| 실패 | 다른 리듬의 낮은 2음/짧은 불협, 400–700ms | error/2회 |
| 안전 경고 | 빠른 3회 pulse, 600–900ms, 빠른 onset | 강한 warning |

- 규칙: 리듬을 충분히 다르게, 음량만으로 구별 금지, 연속 earcon 간 ~0.1초, TTS와 동시 재생 금지(earcon→~100ms→짧은 TTS), 안전 경고만 TTS 중단 허용, 8–12명 소음/이어폰 환경 혼동률 측정.

### C. 끊기지 않는 TTS 큐
- **화면마다 speak/stop 직접 호출 금지 → 앱 전체에 하나의 Speech Arbiter.**
- 우선순위: `critical`(비상·과열·구동실패, 즉시 중단·발화) > `result`(성공/실패/BLE) > `navigation`(화면명, 최신 하나만) > `help`(요청 시).
- 각 발화에 ID·route·priority·dedupe key, 완료 callback 뒤 다음 실행, **dispose에서 전역 stop 금지**, 1–2초 내 동일 문구 병합, 스크린리더 활성 시 일반 TTS off.

### D. 앱 2단계 탭 ↔ 스크린리더 더블탭 충돌
- **물리 탭 횟수를 세지 말 것.** VoiceOver/TalkBack 더블탭 = 포커스 컨트롤에 **단 1회 semantic activation**.
- 가장 안전: 첫 activation → 결과 명시된 **확인 화면**("조리 시작 확인" / "1분 시작" / "취소") → 둘째 activation.
- 현 패턴 유지 시: Flutter `onTap` callback 횟수만 세고 raw pointer 금지, 첫 단계 후 label/value를 "확인 대기 중"으로, **4초 제한 제거/연장**, 비상정지는 확인 패턴 제외(1회 즉시 실행).

### E. 저시력 공식 기준값

| 항목 | 공식 기준 | Touch Bridge 권고 |
|---|---|---|
| 일반 텍스트 대비 | AA 4.5:1 / AAA 7:1 | 핵심 7:1, 나머지 4.5:1↑ |
| 큰 텍스트 대비 | AA 3:1 / AAA 4.5:1 | 4.5:1↑ |
| 큰 텍스트 판정 | 18pt 일반 / 14pt bold(CJK 동등) | "최소 글자"로 오해 금지 |
| 비텍스트 컨트롤 | 3:1 | 경계·아이콘·상태·포커스 검사 |
| iOS 글자 | 기본 17pt, 최소 11pt | 본문 18pt↑, Dynamic Type 필수 |
| Android 글자 | `sp`, 최대 200% | 200%에서 잘림·겹침 없음 |
| WCAG 타깃 | AA 24px / AAA 44px | 최소 48×48 logical px |
| iOS 타깃 | 44×44pt(형식 최소 28) | 44pt 미만 금지 |
| Android 타깃 | 48×48dp | 핵심 CTA 56–64dp↑ |
| 포커스 표시 | 2px 둘레, 전후 3:1 | 2–3px 고대비 링 + offset |

> WCAG에는 모든 모바일 본문에 적용되는 단일 "최소 글자 크기"가 없다. 18pt/14pt bold는 **대비 예외용 큰 텍스트 판정값**이다.

---

## 4. 국내 법·표준 요약 (반드시 준수)

- **장애인차별금지법 제21조 + 시행령 제14조**: 스마트폰 앱 포함 정보접근성 의무. **조작이 어려운 경우 음성명령 지원**을 명시 → Touch Bridge의 음성 제어는 법적 요구와 정합. 접근성은 "옵션"이 아니라 **제품 요구사항**.
- **KS X 3253 (모바일 애플리케이션 콘텐츠 접근성 지침)**: 2025-12-31 개정본. 대체텍스트·입력조작·대비 등 → **국내 출시 QA 체크리스트에 WCAG와 병기**.
- **KWCAG 2.2**: 심사용 웹/Flutter Web 버전에 적용.
- 앱스토어/구글플레이 설명에 **지원하는 접근성 범위 표기** 권장.

> 한국시각장애인연합회는 모바일 접근성 평가·인증 사업을 운영하나, 이번 조사에서 제품 설계에 바로 인용할 세부 공개 지침 원문은 충분히 확보하지 못함 → **당사자 평가로 보완 필수**.

---

## 5. 유사 사례 (설계 근거)

- **Toucha11y** ([arXiv 2305.04097](https://arxiv.org/abs/2305.04097)): 스마트폰 접근성 UI에서 선택 → 봇이 실제 터치스크린을 누름. **Touch Bridge와 거의 동일 구조** → 스마트폰 내장 접근성 기능을 그대로 활용하는 방향을 핵심 아키텍처로.
- **StateLens** (UIST 2019): 대화형 에이전트 + 스마트폰 안내 + 물리 보조물. 기기 상태를 "현재 단계/가능한 다음 동작"으로 모델링.
- **Slide Rule** (ASSETS, [논문](https://www.cs.rochester.edu/hci/pubs/pdfs/slide-rule.pdf)): 제스처 UI가 빠르고 선호됐으나 버튼보다 오류 많음 → **음성 제스처(속도) + 명시 버튼(정확성) 병행**.
- **저시력 가전 인터페이스 연구** (IUI 2023): 저대비·촉각 부족이 조작 장애 → 사진 매핑 화면에 단순 외곽선·확대·고대비 마커 + 음성 설명.

---

## 6. Touch Bridge 적용 현황 & 남은 P0 (2026-08-09 기준)

이번 세션에서 반영한 것(코드):
- 비상정지 실제 명령 전송 + 정직한 확인, 음성 "멈춰/그만/정지/중단" 최우선 인터셉트 → **10번, D의 비상정지 예외와 정합**.
- 성공/실패 **구분 earcon**(합성 WAV) → **B의 방향**(단, 리듬·혼동률 검증은 미완).
- 시스템 글자 확대 존중(textScaler 합성), 보조 텍스트 대비 AA 확보 → **1.4.3 / 1.4.4**.
- 제어 모드 시트: 여는 즉시 선택·옵션 안내 + 2단계 탭 + 버튼 확대 → **2, 3, 이름·역할·값**.

**아직 열려 있는 P0 (다음 우선순위):**
1. **4초 이중 탭 만료 제거/연장** (WCAG 2.2.1) — 현재 홈·시트·비상 등 여러 곳이 4초.
2. **TTS Speech Arbiter(우선순위 큐)** — 지금은 화면마다 speak/stop 직접 호출(끊김의 근본 원인).
3. **스크린리더 활성 시 앱 TTS 억제** + Semantics/live region 우선 — 중복 낭독 방지.
4. **롱프레스 전용 기능 제거** — 카드 삭제·매핑 등에 명시 버튼/accessibility action 대안.
5. **`SemanticsService.announce` 남용 제거**(Android 16 대응) → 화면 제목/상태 노드.

## 7. QA 체크리스트 (요약)

전체 항목은 리서치 원문 기준. 핵심 최소 세트:
- [ ] VoiceOver/TalkBack **만으로** 기기 선택→음성 명령→확인→완료→비상정지 완주.
- [ ] 모든 조작 요소에 고유 label·역할·상태, hint는 결과 설명("탭하세요" 금지).
- [ ] 화면 전환 후 포커스가 논리적 첫 요소로 이동.
- [ ] iOS 최대 Dynamic Type / Android 200%에서 잘림·겹침 없음.
- [ ] 색상 쌍 AA 4.5:1(핵심 7:1), 컨트롤·포커스 3:1 — 자동 검사.
- [ ] 모든 터치 영역 48×48 logical px↑.
- [ ] earcon 3종(성공/실패/경고) 리듬·음고 상이, TTS와 비중첩.
- [ ] TalkBack single-tap / double-tap 양쪽에서 이중 확인 정상.
- [ ] BLE 지연·끊김·ESP32 무응답·로봇 오류 각각 원인+다음행동 안내.
- [ ] **전맹·저시력 당사자 분리 모집** 평가(성공률·오류율·시간·중도포기). 최소 기준: 도움 없이 핵심 작업 100% 완료, 안전 오류 0건.

> 이 문서는 조사 정리본이다. 인용 링크는 접속 가능하나, 규정 수치는 **1차 출처에서 재확인**하고 프로젝트 QA 기준으로 확정할 것.
