# Touch Bridge (터치 브릿지) 🌉

**Touch Bridge**는 음성 명령과 AI 기술을 결합하여 가전제품을 더욱 쉽고 스마트하게 제어할 수 있도록 돕는 혁신적인 인터페이스 솔루션입니다. 특히 시각 장애인이나 가전제품 조작에 어려움을 겪는 사용자를 위해 설계되었습니다.

## 🚀 주요 기능

- **음성 인식 및 명령 처리**: 한국어 특화 STT(Speech-to-Text) 모델을 통해 정확한 음성 인식을 지원합니다.
- **AI 기반 의도 분석**: Gemini 2.0 Flash 모델을 사용하여 사용자의 자연어 명령(예: "햇반 데워줘")을 기기 제어 신호로 변환합니다.
- **가전 기기 제어 매핑**: 전자레인지 등의 버튼 조작을 디지털 신호로 매핑하여 직관적인 제어를 제공합니다.
- **비상 정지 시스템**: 위험 상황 발생 시 즉각적으로 모든 기기 작동을 중단할 수 있는 안전 기능을 포함합니다.
- **맞춤형 UI/UX**: Flutter 기반의 직관적이고 접근성 높은 인터페이스를 제공합니다.

## 🛠 기술 스택

### Frontend (App)
- **Framework**: Flutter
- **Packages**:
  - `speech_to_text`: 음성 인식 기능
  - `flutter_tts`: 음성 안내 기능
  - `flutter_dotenv`: 환경 변수 관리
  - `http`: 백엔드 통신

### Backend (AI Server)
- **Framework**: FastAPI (Python)
- **AI Models**:
  - **Moonshine (UsefulSensors/moonshine-tiny-ko)**: 고성능 온디바이스 한국어 음성 인식
  - **Gemini 2.0 Flash**: 자연어 이해 및 명령 분석
- **Libraries**: `torch`, `transformers`, `librosa`

## ⚙️ 시작하기

### 백엔드 설정
1. `backend` 폴더로 이동합니다.
2. 필요한 라이브러리를 설치합니다:
   ```bash
   pip install -r requirements.txt
   ```
3. `backend/.env` 파일을 생성하고 `GOOGLE_API_KEY`를 설정합니다.
4. 서버를 실행합니다:
   ```bash
   python main.py
   ```

### 프론트엔드 설정
1. 루트 디렉토리에서 의존성을 설치합니다:
   ```bash
   flutter pub get
   ```
2. 루트 디렉토리에 `.env` 파일을 생성하고 백엔드 주소를 설정합니다.
3. 앱을 실행합니다:
   ```bash
   flutter run
   ```

## 🤝 기여하기
프로젝트에 기여하고 싶으시다면 Issue를 등록하거나 Pull Request를 보내주세요!

---
© 2026 Touch Bridge Team. All rights reserved.
