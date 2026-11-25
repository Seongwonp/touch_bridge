# 실행 가이드

## 1. 준비

- Flutter 3.44 이상 / Dart 3.12 이상 (CI는 3.47.5로 검증)
- Python 3.10 이상 (백엔드)
- Android 기기 (음성 인식·BLE 실사용 기준)
- 실제 장치를 쓸 경우: ESP32 두 대(모터 제어기, CT 노드), SwitchBot Bot. 배선과 첫 구동은 [`hardware/touchbridge_corexy/README.md`](../hardware/touchbridge_corexy/README.md)를 따른다.

## 2. 환경 변수

### 앱 (`.env`, 저장소 루트)

```env
AI_BACKEND_URL=http://127.0.0.1:8000
# 실기기에서는 백엔드 PC의 같은 네트워크 IP를 쓴다. 예: http://192.168.0.10:8000
AI_BACKEND_API_KEY=
```

`pubspec.yaml`이 `.env`를 asset으로 선언하므로 파일이 없으면 빌드가 실패한다. 클론 직후 한 번 만든다.

```bash
cp .env_ex .env
```

### 백엔드 (`backend/.env`)

```env
AI_PROVIDER=google            # google | school
GOOGLE_API_KEY=
GEMINI_MODEL=gemini-1.5-flash
BACKEND_API_KEY=              # 설정하면 모든 요청에 X-API-Key를 요구한다
MONGO_URI=mongodb://localhost:27017/
```

MongoDB가 없으면 메모리 저장소로 동작한다. 전체 항목은 `backend/.env_ex`를 본다.

## 3. 실행

```bash
# 백엔드
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000

# 앱
flutter pub get
flutter run                                          # 연결된 Android 기기
flutter run --dart-define=TOUCH_BRIDGE_DEMO=true     # 장치 없이 데모 기기·가짜 전송으로 실행 (debug 빌드)
flutter build apk --release --dart-define=TOUCH_BRIDGE_BOOTH=true   # 시연용: 보조 기능 진입점 숨김
```

## 4. 검증

```bash
flutter analyze --fatal-infos
flutter test
cd backend && python -m unittest discover -s . -p "test_*.py"
```

GitHub Actions가 push·PR마다 같은 명령을 실행한다.

### Windows에서 경로에 한글이 있을 때

- `flutter test`: 임시 폴더가 한글 경로면 테스트 실행기가 바로 종료된다. 임시 폴더를 ASCII 경로로 바꾼다.
  ```powershell
  $env:TEMP = "C:\src\tmp"; $env:TMP = "C:\src\tmp"; flutter test
  ```
- `flutter analyze`: 분석 서버가 한글 경로에서 실패한다. ASCII 경로에 복사본을 두고 실행한다.
  ```powershell
  robocopy <프로젝트> C:\src\tb /E /XD .dart_tool build .git
  cd C:\src\tb; flutter analyze --fatal-infos
  ```
- `flutter pub get`이 `linux/`·`macos/`·`windows/` 생성 파일의 줄바꿈만 바꿀 수 있다. 커밋 전에 `git checkout -- linux macos windows`로 되돌린다.

## 5. 앱 동작 확인

1. 홈의 '말하기'를 누르고 "10분 돌려줘"라고 말한다. 앱이 "10분 조리를 시작할까요?"라고 묻는다.
2. "네"라고 답하면 장치로 명령을 보내고, 누르는 동안 화면에 '즉시 정지'가 보인다. 한 번 누르면 바로 정지한다.
3. "만두 데워줘"처럼 규칙에 없는 말은 백엔드 AI가 해석해 시간을 정하고 다시 묻는다.
4. 설정 → 보호자 설정에서 가전을 추가하고, 사진으로 버튼 위치를 찾거나 1·5·10mm 단위로 직접 맞춘다.
5. TalkBack을 켠 상태에서 1~2를 반복해, 앱 음성과 낭독기 음성이 겹치지 않는지 확인한다.

## 6. 장치 연동 확인

전원을 넣기 전:
- 6V 모터 전원과 ESP32 로직 전원을 분리하고 GND를 공통으로 묶는다.
- X/Y 엔코더 A/B상 배선과 방향을 확인한다.
- 모터 전원을 바로 끌 수 있는 스위치를 손 닿는 곳에 둔다.
- SwitchBot Bot의 주소(`config_local.h`), 누름 모드, 배터리를 확인한다.

전원을 넣은 뒤:
1. `home`으로 벽 감지 원점 복귀를 확인한다.
2. 각 축을 `move_only`로 조금씩 움직여 방향과 오차를 확인한다.
3. 원점 복귀 전, 허용 오차 초과, 오래된 위치 토큰에서는 누름이 거부되는지 확인한다.
4. `STOPPED`는 모터 정지와 대기 명령 폐기를 뜻한다. 이미 Bot에 보낸 누름은 되돌릴 수 없다.

## 7. 자주 생기는 문제

| 증상 | 확인할 것 |
|---|---|
| 음성 명령 해석 실패 | `AI_BACKEND_URL`, 백엔드 실행 여부. 무료 서버는 첫 요청이 느릴 수 있다 |
| BLE 연결 실패 | 장치 전원, 거리, 다른 앱이 장치에 연결돼 있는지 |
| 음성 인식이 시작되지 않음 | 마이크 권한, 휴대폰의 음성 인식 서비스 |
