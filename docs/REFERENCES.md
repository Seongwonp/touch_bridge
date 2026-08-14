# Touch Bridge — 참고문헌 목록

> 정리일: 2026-08-14 | 작성: 3팀 멜론머스크
> 이 문서는 Touch Bridge 프로젝트의 접근성 설계, 기술 구현, 법적 근거에 사용된 모든 참고자료를 정리한 것입니다.

---

## 1. 국제 접근성 표준 (W3C / WCAG)

| # | 자료명 | URL |
|---|--------|-----|
| 1 | WCAG 2.2 전문 (Web Content Accessibility Guidelines 2.2) | https://www.w3.org/TR/WCAG22/ |
| 2 | WCAG2Mobile — WCAG 2.2를 모바일 앱에 적용하는 W3C 해석 | https://www.w3.org/TR/wcag2mobile-22/ |
| 3 | WCAG 1.4.3 — 텍스트 명도 대비 (Contrast Minimum, AA 4.5:1) | https://www.w3.org/TR/WCAG22/#contrast-minimum |
| 4 | WCAG 1.4.6 — 텍스트 명도 대비 강화 (AAA 7:1) | https://www.w3.org/TR/WCAG22/#contrast-enhanced |
| 5 | WCAG 1.4.11 — 비텍스트 대비 (Non-text Contrast, 3:1) | https://www.w3.org/TR/WCAG22/#non-text-contrast |
| 6 | WCAG 2.2.1 — 시간 제한 조정 (Timing Adjustable) | https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html |
| 7 | WCAG 2.4.3 — 포커스 순서 (Focus Order) | https://www.w3.org/TR/WCAG22/#focus-order |
| 8 | WCAG 2.5.5 — 터치 타깃 크기 강화 (AAA, 44×44px) | https://www.w3.org/TR/WCAG22/#target-size-enhanced |
| 9 | WCAG 2.5.8 — 터치 타깃 크기 최소 (AA, 24×24px) | https://www.w3.org/TR/WCAG22/#target-size-minimum |
| 10 | WCAG 4.1.2 — 이름·역할·값 (Name, Role, Value) | https://www.w3.org/TR/WCAG22/#name-role-value |
| 11 | WCAG 4.1.3 — 상태 메시지 (Status Messages) | https://www.w3.org/TR/WCAG22/#status-messages |
| 12 | W3C 모바일 접근성 매핑 (Mobile Accessibility Mapping) | https://www.w3.org/TR/mobile-accessibility-mapping/ |

---

## 2. 국내 법률 및 표준

| # | 자료명 | URL |
|---|--------|-----|
| 13 | 장애인차별금지 및 권리구제 등에 관한 법률 (장차법) 전문 | https://www.law.go.kr/LSW/lsInfoP.do?lsId=010420 |
| 14 | 장차법 시행령 (모바일 앱 접근성 의무 조항 포함) | https://elaw.klri.re.kr/kor_service/lawView.do?hseq=68028 |
| 15 | 보건복지부 — 장차법 모바일 앱 접근성 의무화 보도자료 | https://www.mohw.go.kr/board.es?mid=a10503010100&bid=0027&act=view&list_no=375590 |
| 16 | KS X 3253 — 모바일 애플리케이션 콘텐츠 접근성 지침 2.0 (PDF) | http://www.webwatch.or.kr/pds/(KS%20X%203253)모바일%20애플리케이션%20콘텐츠%20접근성%20%20지침%202.0.pdf |
| 17 | KWCAG 2.2 (KS X OT0003) — 한국형 웹 콘텐츠 접근성 지침 | https://www.nia.or.kr/site/nia_kor/ex/bbs/View.do?bcIdx=25083&cbIdx=90549 |
| 18 | 국립전파연구원 — KS X 3253 고시 정보 | https://www.rra.go.kr/ko/reference/kcsList_view.do?nb_seq=1930&nb_type=6 |

---

## 3. 플랫폼 공식 접근성 가이드

| # | 자료명 | URL |
|---|--------|-----|
| 19 | Apple Human Interface Guidelines — Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility |
| 20 | Apple — VoiceOver 평가 기준 (App Store Connect) | https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria |
| 21 | Apple — UIAccessibilityTraits (역할·속성 정의) | https://developer.apple.com/documentation/uikit/uiaccessibilitytraits |
| 22 | Apple — AVSpeechSynthesizer (iOS TTS API) | https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer |
| 23 | Apple — Haptics 설계 지침 | https://developer.apple.com/design/human-interface-guidelines/playing-haptics |
| 24 | Apple — QueueAnnouncement (VoiceOver 공지 큐) | https://developer.apple.com/documentation/uikit/uiaccessibilityspeechattributequeueannouncement |
| 25 | Apple — Typography (Dynamic Type, 기본 17pt) | https://developer.apple.com/design/human-interface-guidelines/typography |
| 26 | Android Accessibility 개발자 원칙 | https://developer.android.com/guide/topics/ui/accessibility/principles |
| 27 | Android Accessibility Codelab (터치 타깃 48dp 등) | https://developer.android.com/codelabs/starting-android-accessibility |
| 28 | Android — Traversal order (포커스 탐색 순서) | https://developer.android.com/develop/ui/compose/accessibility/traversal |
| 29 | Android — TextToSpeech API | https://developer.android.com/reference/android/speech/tts/TextToSpeech |
| 30 | Android 14 — 비선형 글꼴 스케일링 (최대 200%) | https://developer.android.com/about/versions/14/features#non-linear-font-scaling |
| 31 | Android 16 — 접근성 동작 변경 사항 (announceForAccessibility 지양) | https://developer.android.com/about/versions/16/behavior-changes-all#accessibility |
| 32 | Android — Haptics 원칙 | https://developer.android.com/develop/ui/views/haptics/haptics-principles |
| 33 | Flutter Semantics API | https://api.flutter.dev/flutter/widgets/Semantics-class.html |
| 34 | Flutter liveRegion 속성 | https://api.flutter.dev/flutter/semantics/SemanticsProperties/liveRegion.html |
| 35 | Google Assistant — Conversation Design: Errors | https://developers.google.com/assistant/conversation-design/errors |

---

## 4. 국내 관련 기관

| # | 기관명 | 연락처 | URL |
|---|--------|--------|-----|
| 36 | 한국시각장애인연합회 (한시련, KBUWEL) | 02-799-1000 | http://www.kbuwel.or.kr |
| 37 | 한국디지털접근성진흥원 (KDAA) — 모바일 앱 접근성 인증 | - | http://www.kwacc.or.kr |
| 38 | 한국정보접근성인증평가원 (wa.or.kr) | 02-858-7220 | https://www.wa.or.kr |
| 39 | WebWatch — MA 인증·컨설팅 | - | http://www.webwatch.or.kr |
| 40 | 실로암시각장애인복지관 (평생교육팀) | 02-880-0530 | https://www.silwel.or.kr |
| 41 | 한국시각장애인복지관 | 02-440-5200 | http://www.hsb.or.kr |
| 42 | 경기도시각장애인복지관 | - | https://www.gbw.or.kr |
| 43 | 인천광역시시각장애인복지관 | 032-876-3500 | http://www.ibu.or.kr |

---

## 5. 국내 논문 및 보고서

| # | 자료명 | 저자 | 출처 |
|---|--------|------|------|
| 44 | 저시력 시각장애인의 키오스크 사용성 평가 연구 (2024) | 김경훈, 김유미, 백수민, 고정현 | 정보관리학회지 41(3), DOI: http://doi.org/10.3743/KOSIM.2024.41.3.331 |
| 45 | 시각장애인 보조기기 접근과 스마트기기 활용 조사연구: 경기도 중심 (2024) | 이신영(대구대), 박진석(이화여대), 이경은(경기도시각장애인복지관) | 특수교육재활과학연구 63(2), https://www.dbpia.co.kr/journal/articleDetail?nodeId=NODE11974961 |
| 46 | 시각장애인을 위한 보조기기의 사용과 현황 (2006) | 이진현, 송병섭, 이해균 | 시각장애연구 22(2), https://www.kci.go.kr/kciportal/ci/sereArticleSearch/ciSereArtiView.kci?sereArticleSearchBean.artiId=ART001187304 |
| 47 | 디지털 시대 장애인 정보격차 해소를 위한 방안 마련 연구 (2022) | - | 한국장애인개발원, https://www.koddi.or.kr/system/download.jsp?type=hp_board&subType=ATT1&fileName=20221114161402001.pdf |
| 48 | 가전제품 접근성 인식 설문조사 | - | 한국전자정보통신산업진흥회(KEA), https://gokea.org/core/?cid=11&role=view&uid=6513 |
| 49 | 제2차 점자발전기본계획 2024~2028 | - | 문화체육관광부, https://www.nise.go.kr/onmam/openapi/fileDown.do?fileSn=aT0DtoTmsfXrKAWRAcZhEg |

---

## 6. 국제 학술 논문 (HCI / 접근성)

| # | 자료명 | 출처 |
|---|--------|------|
| 50 | **Toucha11y** — 스마트폰 접근성 UI에서 봇이 실제 터치스크린을 대신 누르는 구조 (Touch Bridge와 동일 아키텍처) | arXiv:2305.04097, https://arxiv.org/abs/2305.04097 |
| 51 | **StateLens** — 대화형 에이전트 + 스마트폰 안내 + 물리 보조물. 기기 상태를 단계/다음 행동으로 모델링 | UIST 2019 |
| 52 | **Slide Rule** — 제스처 UI는 빠르지만 오류율이 높아 명시 버튼과 병행 필요 | ASSETS, https://www.cs.rochester.edu/hci/pubs/pdfs/slide-rule.pdf |
| 53 | 저시력 가전 인터페이스 연구 — 저대비·촉각 부족이 주요 조작 장애, 고대비 마커+음성 설명 효과 확인 | IUI 2023 |
| 54 | **Brewster Earcon 설계 지침** — 리듬·음색·register 조합, 연속 earcon 간 ~0.1초 간격, 음량만으로 구별 금지 | S. Brewster, Researchgate, https://www.researchgate.net/publication/228607856_Experimentally_derived_guidelines_for_the_creation_of_earcons |

---

## 7. 언론 기사

| # | 자료명 | 출처 |
|---|--------|------|
| 55 | 장애인의 가전제품 이용에 유용한 기술들 — 점자 탑재 가전이 극소수인 실태 (2023.08.11) | 에이블뉴스, https://www.ablenews.co.kr/news/articleView.html?idxno=206152 |
| 56 | 월패드·키오스크 앞에 접근권 배제된 시각장애인 (2022.05.13) | 아시아경제, https://www.asiae.co.kr/article/2022051311471919371 |

---

## 8. 기타 기술 참고

| # | 자료명 | URL |
|---|--------|-----|
| 57 | Android TalkBack 개발자 가이드 | https://developer.android.com/guide/topics/ui/accessibility |
| 58 | iOS VoiceOver 개발자 가이드 | https://developer.apple.com/accessibility/ |
| 59 | Journal of Universal Design — 키오스크 접근성 국내 사례 | https://www.ud4all.or.kr/Content/Journal/Paper_2108/Paper03/UD0101-Paper03.html |

---

> **추가 논문 검색 DB**: RISS (riss.kr) · DBpia · KCI
> **검색어**: `시각장애인 가전 접근성` / `시각장애 유니버설디자인 가전` / `시각장애인 터치 인터페이스`

---

## 9. 참고문헌 → 실제 구현 매핑

각 참고자료가 Touch Bridge의 어떤 기능/설계 결정으로 이어졌는지 정리합니다.

### 국제 표준 적용

| 참고문헌 | 적용한 작업 | 구현 위치 |
|----------|------------|-----------|
| WCAG 1.4.3 / 1.4.6 (대비 AA/AAA) | 고대비 다크 테마 설계 — 배경 #000000, 주요색 #FFEB00, 전체 색상 토큰화 | `lib/theme/app_colors.dart` |
| WCAG 1.4.3 / 1.4.6 (대비 AA/AAA) | 색상 대비 자동 단위 테스트 작성 (AA 4.5:1 / AAA 7:1 검증) | `test/theme/app_colors_contrast_test.dart` |
| WCAG 1.4.11 (비텍스트 대비 3:1) | 버튼 외곽선·매핑 마커·포커스 링 대비 확보 | `lib/screens/mapping/widgets/mapping_markers_layer.dart` |
| WCAG 2.2.1 (시간 제한 조정) | 이중 탭 타임아웃 15초로 통일 (전체 화면) | `lib/widgets/primary_button.dart` 외 전체 |
| WCAG 2.4.3 (포커스 순서) | BottomSheet 열릴 때 첫 요소 자동 포커스 이동 (`addPostFrameCallback`) | `lib/screens/home/widgets/control_mode_sheet.dart`, `lib/screens/settings/device_management_screen.dart` |
| WCAG 2.5.5 / 2.5.8 (터치 타깃) | 최소 터치 영역 48px 확보 (`.clamp(48.0, double.infinity)` + `HitTestBehavior.opaque`) | `lib/screens/mapping/widgets/button_marker.dart` |
| WCAG 4.1.2 (이름·역할·값) | 전체 화면 `Semantics(label, button, value, checked, onTap)` 적용 | 전체 화면 |
| WCAG 4.1.3 (상태 메시지) | BleStatusBanner에 `Semantics(liveRegion: true)` 적용 — 재연결 상태 자동 낭독 | `lib/widgets/ble_status_banner.dart` |
| WCAG 4.1.3 (상태 메시지) | 음성 인식 화면 상태 변화 `liveRegion` 처리 | `lib/screens/voice/voice_listening_screen.dart` |

### 플랫폼 가이드 적용

| 참고문헌 | 적용한 작업 | 구현 위치 |
|----------|------------|-----------|
| Apple / Android Haptics | 탐색=light, 실행=medium, 실패=error 햅틱 패턴 통일 | `lib/widgets/primary_button.dart`, `lib/widgets/emergency_button.dart` |
| VoiceOver / TalkBack 가이드 | `CustomSemanticsAction`으로 롱프레스·숨겨진 제스처를 스크린리더 액션 메뉴에 노출 | `lib/screens/home/widgets/home_device_card.dart`, `lib/screens/main_navigation_screen.dart` |
| VoiceOver / TalkBack 가이드 | `ExcludeSemantics`로 카드 하위 Text 중복 낭독 방지 | `lib/screens/home/widgets/home_device_card.dart`, `home_add_device_card.dart` |
| Apple — QueueAnnouncement | TTS 우선순위 큐 설계 (critical > result > navigation > help), 스크린리더 활성 시 navigation TTS 억제 | `lib/services/tts_service.dart` |
| Android 14 비선형 글꼴 | `MediaQuery.textScaler` 존중, 고정 height 컨테이너 제거 → `ConstrainedBox(minHeight:)` | `lib/widgets/emergency_button.dart`, `primary_button.dart` |
| Android 16 접근성 변경 | `SemanticsService.announce` 남용 제거, heading/live region 방식으로 전환 | `lib/widgets/top_app_bar.dart` (`Semantics(header: true)`) |
| Apple Typography (Dynamic Type) | 큰 글씨 옵션 1.18배 확대, 텍스트 확대 설정 영속화 | `lib/services/accessibility_settings.dart`, `lib/theme/app_text.dart` |
| macOS TCC 버그 (Apple) | macOS 플랫폼 TTS/STT 가드 패턴 추가 | `lib/services/tts_service.dart`, `lib/screens/safety/emergency_stop_screen.dart` |

### 국내 법·표준 적용

| 참고문헌 | 적용한 작업 | 구현 위치 |
|----------|------------|-----------|
| KS X 3253 (18개 항목) | 전체 화면 Semantics 트리 점검 및 `header`, `value`, `liveRegion` 적용 | 전체 화면 |
| 장차법 제21조 (음성명령 지원 의무) | 음성 명령(STT + Gemini AI) 핵심 기능으로 구현 | `lib/screens/voice/voice_listening_screen.dart` |
| 장차법 제21조 (음성명령 지원 의무) | 가전 3종(전자레인지·세탁기·에어컨) 음성 명령 서비스 확장 | `lib/services/microwave_command_service.dart`, `washing_machine_command_service.dart`, `ac_command_service.dart` |

### 학술 논문 적용

| 참고문헌 | 적용한 작업 | 구현 위치 |
|----------|------------|-----------|
| **Toucha11y** (arXiv:2305.04097) | 앱이 논리 명령만 생성 → ESP32 하드웨어가 물리적으로 버튼을 누르는 책임 분리 아키텍처 | BLE 프로토콜 설계 전반 |
| **Toucha11y** (arXiv:2305.04097) | AI(Gemini)는 좌표 직접 생성 금지 → 논리 버튼 ID만 반환, 좌표 변환은 매핑 서비스가 담당 | `lib/services/appliance_command_router.dart`, `mapping_execution_service.dart` |
| **StateLens** (UIST 2019) | 기기 상태를 "현재 단계 + 다음 가능한 행동" 구조로 TTS 안내 설계 | `lib/services/tts_service.dart`, TTS 문구 전반 |
| **Slide Rule** (ASSETS) | 음성 명령(속도)과 명시 버튼(정확성) 병행 제공 — 제스처만으론 오류율 높음 | 홈 화면 "말하기 버튼" + 이중 탭 확인 구조 |
| **Brewster Earcon** 지침 | 성공/실패/경고 earcon 리듬·음고 달리 설계, TTS와 동시 재생 금지 | `assets/sounds/` (합성 WAV) |
| 저시력 가전 인터페이스 (IUI 2023) | 사진 매핑 화면: 고대비 마커 + 음성 설명 + 확대 가능한 외곽선 | `lib/screens/mapping/photo_mapping_screen.dart` |

### 기관 활용 계획

| 기관 | 활용 목적 | 상태 |
|------|-----------|------|
| 실로암시각장애인복지관 (02-880-0530) | 당사자(전맹·저시력) 사용성 테스트 참여자 모집 | 예정 |
| 한국시각장애인연합회 (02-799-1000) | 회원 대상 베타테스터 모집 공지 협조 요청 | 예정 |
| 한국디지털접근성진흥원 (kwacc.or.kr) | KS X 3253 기반 MA 인증 상담 및 신청 | 공모전 후 검토 |
