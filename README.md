# Touch Bridge

Touch Bridge는 시각장애인/고령 사용자를 포함한 접근성 우선 환경에서,
기기 제어를 더 안전하고 단순하게 수행하기 위한 Flutter 앱입니다.

## 핵심 목표

- 큰 터치 영역과 고대비 UI 제공
- "첫 탭 안내 + 두 번째 탭 실행"으로 오작동 방지
- 음성 안내(TTS)와 음성 인식(STT) 기반 상호작용 지원
- 긴급 중단(길게 누르기) 중심의 안전 플로우 제공

## 현재 구현 상태

### 접근성 인터랙션

- 주요 버튼/탭/카드에 2단계 탭 패턴 적용
- 1차 탭: 기능/대상 음성 안내
- 2차 탭: 실제 실행
- 버튼 재탭 대기 상태 시 시각적 강조(테두리) + 햅틱 피드백
- `Semantics`를 통해 스크린리더 힌트 강화

### 주요 사용자 플로우

1. 홈 화면에서 기기 카드 스와이프
2. 기기 카드 탭 1회: 상태 안내
3. 기기 카드 탭 2회: 시간 제어 화면 이동
4. `시작 / 음성 제어` 탭 1회: 안내
5. `시작 / 음성 제어` 탭 2회: 긴급 중단 화면 이동 + 작동 안내 음성
6. 긴급 중단 화면:
7. 길게 누르면 즉시 중단
8. 타이머 종료 시 "타이머가 종료되었습니다" 안내 후 홈 복귀

### 타이머/안전

- 시간 입력 키패드 제공 (반응형 크기 조정)
- `타이머 초기화` 동작 제공 (기본 02:30)
- 긴급 중단 버튼 길게 누르기 시간: 2초

### 플랫폼 이슈 반영

- macOS에서 음성 권한(TCC) 이슈 대응
- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- macOS entitlements의 microphone/speech 권한

## 기술 스택

- Flutter / Dart
- `flutter_tts`
- `speech_to_text`

## 프로젝트 구조

```text
lib/
	theme/        # 색상/타이포/테마
	widgets/      # 재사용 UI 컴포넌트
	screens/      # 기능별 화면
		connection/
		control/
		home/
		mapping/
		safety/
		settings/
		voice/
```

## 실행 방법

```bash
flutter pub get
flutter run
```

macOS 실행 시 권장:

```bash
flutter clean
flutter pub get
flutter run -d macos
```

## 품질 점검

```bash
flutter analyze
flutter test
```

## 트러블슈팅

### 1) macOS에서 음성 기능 진입 시 앱 종료

- 증상: `Namespace TCC` 크래시
- 확인 포인트:
- `macos/Runner/Info.plist`에 음성/마이크 usage description 키 존재 여부
- `macos/Runner/*.entitlements`에 speech/mic 권한 존재 여부

권한 캐시 초기화가 필요하면:

```bash
tccutil reset SpeechRecognition com.example.touchBridge
tccutil reset Microphone com.example.touchBridge
```

### 2) macOS에서 스와이프 동작이 안 되는 경우

- 앱 전역 `scrollBehavior`에 마우스/터치 드래그 디바이스 허용이 반영되어 있어야 함

## 디자인/개발 원칙

- 접근성 우선: 단순한 문구, 큰 터치 영역, 명확한 대비
- 안전 우선: 위험 동작은 확인 단계를 통해 실행
- 과도한 상태관리/복잡 로직 지양, 읽기 쉬운 코드 우선

## TODO (다음 단계)

- 화면 간 안내 문구 톤/길이 통일
- 기기별 상태 문구와 실제 동작 결과 음성 동기화 강화
- 실기기 접근성 테스트(VoiceOver/TalkBack) 체크리스트 정리
