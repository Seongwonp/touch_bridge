# Touch Bridge 재현 가이드 (심사용)

## 1) 사전 준비
- Flutter 3.x / Dart 3.x
- Python 3.10+ (백엔드 실행용)
- 실제 또는 테스트용 BLE 주변기기

## 2) 환경 변수
### 앱 루트 `.env`
```env
AI_BACKEND_URL=http://127.0.0.1:8000
```
(`.env_ex` 참고)

### 백엔드 `.env` (`backend` 실행 환경)
```env
GOOGLE_API_KEY=YOUR_REAL_KEY
GEMINI_MODEL=gemini-3-flash-preview
```
(`backend/.env_ex` 참고)

## 3) 백엔드 실행
```bash
cd backend
pip install -r requirements.txt
python main.py
```

기본 주소: `http://127.0.0.1:8000`

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
2. BLE 검색/연결 시도 가능
3. 음성 명령 파싱 및 제어 화면 전환
4. 비상 정지 동작
5. 설정 > 접근성 실험 지표 수치 갱신 확인
6. 기기별 그리드(예: 3x3/2x2) 설정 변경 시 명령 변환 정상 동작 확인

## 6-1) 연동 규약 문서
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
