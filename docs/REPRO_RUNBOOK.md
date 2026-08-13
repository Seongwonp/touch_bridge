# Touch Bridge 재현 가이드 (심사용)

## 1) 사전 준비
- Flutter 3.x / Dart 3.x
- Python 3.10+ (백엔드 실행용)
- 실제 또는 테스트용 BLE 주변기기

## 2) 환경 변수
### 앱 루트 `.env`
```env
# 아이폰 실기기 테스트 시 맥의 hostname.local 주소를 사용하세요
AI_BACKEND_URL=http://bagseong-won-ui-MacBookPro.local:8001
```
(`.env_ex` 참고)

### 백엔드 `.env` (`backend` 실행 환경)
```env
GOOGLE_API_KEY=YOUR_REAL_KEY
GEMINI_MODEL=gemini-1.5-flash
MONGO_URI=mongodb://localhost:27017/
```
(`backend/.env_ex` 참고)

## 3) 백엔드 실행
- **MongoDB 실행**: `brew services start mongodb-community` (최초 1회)
- **가상환경 활성화 및 실행**:
```bash
cd backend
source .venv/bin/activate
python3 -m uvicorn main:app --host 0.0.0.0 --port 8001
```

기본 주소: `http://localhost:8001`

## 4) 앱 실행
```bash
cd /path/to/touch_bridge
flutter pub get
flutter run -d chrome
```

모바일 기기 테스트 시 `-d android` 또는 `-d ios` 사용

## 5) 검증 명령
```bash
flutter analyze
flutter test
```

## 6) 데모 체크리스트
1. 홈 화면 기기 선택 가능
2. 보호자 모드 ON에서 기기 관리/기기 추가 진입 가능
3. 보호자 모드 OFF에서 하단 바가 홈/비상/설정으로 단순화되는지 확인
4. 홈의 `말하기` 버튼으로 음성 명령 파싱 및 제어 화면 전환
5. 홈 화면을 빠르게 3회 터치했을 때 현재 선택 기기의 음성 명령 화면으로 진입하는지 확인
6. 음성 명령에서 기기명만 말하면 동작을 되묻고, 기기명 없이 동작만 말하면 현재 선택 기기를 사용하는지 확인
7. 비상 탭의 즉시 중단 동작
8. 설정 > 접근성 실험 지표 수치 갱신 확인
9. 기기별 그리드(예: 3x3/2x2) 설정 변경 시 명령 변환 정상 동작 확인

## 6-0) 모드 분리 검증
1. 사용자 모드: 보호자 모드 OFF, 개발자 모드 OFF 상태에서 홈/비상/설정만 보이는지 확인한다.
2. 보호자 모드: 보호자 모드 ON 상태에서 기기 관리와 기기 추가/매핑 흐름이 보이는지 확인한다.
3. 개발자 모드: 개발자 모드 ON 상태에서 설정 > 개발자/시연 도구가 보이는지 확인한다.
4. 개발자 콘솔에서 `ESP 선택`으로 다른 ESP32를 검색/연결할 수 있는지 확인한다.
5. 개발자 콘솔에서 이동 단위와 속도 `F값`을 바꾼 뒤 X/Y/Z 조이스틱 로그가 바뀐 값으로 출력되는지 확인한다.

## 6-1) 매핑/음성 제어 검증
1. 개발자 모드 또는 수동 매핑 화면에서 X/Y/Z 조이스틱 이동을 확인한다.
2. 사진 매핑 화면에서 기준점(0,0)을 먼저 찍고, 각 버튼 위치를 사진 위에 찍는다.
3. 버튼 마커를 눌러 `테스트 터치`를 실행하고, 실제 하드웨어가 의도한 버튼 칸을 누르는지 확인한다.
4. 저장 후 홈 > 기기 선택 > 이미지로 제어 화면에 들어가, 노란 마커가 사진에서 찍은 위치 그대로 표시되는지 확인한다.
5. 이미지 제어 화면에서 같은 버튼을 눌렀을 때 저장된 `buttonMap(row/col)` 기준으로 동일한 하드웨어 위치가 실행되는지 확인한다.
6. 작은 화면/큰 화면/가로로 긴 사진/세로로 긴 사진에서 사진이 잘리지 않고, 레터박스 영역을 눌러도 매핑 포인트가 추가되지 않는지 확인한다.
7. 사진 매핑 화면의 `전체 버튼 테스트`를 눌러 매핑된 버튼이 순서대로 실행되는지 확인한다.
8. 수동 매핑 화면에서 조이스틱으로 기준점까지 이동한 뒤 `현재 위치를 원점으로 지정`을 누르고, `원점 테스트 터치`가 의도한 기준점에서 실행되는지 확인한다.
9. 실행 로그에서 `mapping.press.send` 이벤트의 `button_id`, `row`, `col`, `btn`, `x`, `y`, `device_id`가 기록되는지 확인한다.
   - 현재 앱은 `$J` 대신 `G91` -> `G1` -> `G90` 안정 이동 명령을 사용한다.
2. 수동 매핑 화면에서 `rows`, `cols`, `originX`, `originY`, `pitchX`, `pitchY`를 저장한다.
3. 사진 매핑 화면에서 버튼 라벨 또는 AI 분석 결과를 저장한다.
   - Vision 응답은 `button_id`, `row`, `col`, `label` 형식을 우선 사용한다.
4. 홈에서 같은 기기를 선택한 뒤 음성 명령을 실행한다.
   - 저장된 `DeviceMappingProfile.buttonMap`이 있으면 해당 매핑을 우선 사용한다.
   - 저장 매핑이 없을 때만 `docs/MOCK_MAPPING_DATA.md` 좌표 fallback을 사용한다.
5. BLE 로그에서 `SET_GRID` 후 `BTN_n` 또는 fallback G-code 전송이 보이는지 확인한다.

## 6-2) 연동 규약 문서
- `docs/HW_APP_INTEGRATION_CONTRACT_KO.md`를 기준으로 enum/명령/주의점을 준수한다.

## 7) 장애 대응 플랜 B
- 백엔드 미연결:
  - 증상: 음성/사진 분석 실패
  - 대응: `AI_BACKEND_URL` 확인, 백엔드 재실행
- BLE 연결 실패:
  - 증상: 연결 상태 실패
  - 대응: 기기 전원/근접 확인, 스캔 재시도
- 마이크 권한 거부:
  - 증상: STT 시작 불가
  - 대응: 권한 허용 후 앱 재시작
