# Phase 1: 클라우드 연동 및 인프라 설계

> **담당:** 박성원 (Backend/Cloud Architect)
> **상태:** Phase 1 완료 (Local DB & API 설계)

## 1. 개요
사용자가 기기를 매번 수동으로 매핑하는 번거로움을 줄이기 위해, 클라우드에 저장된 기기 프로필(버튼 위치 정보)을 QR, NFC, 또는 수동 코드를 통해 즉시 불러오는 시스템을 구축한다.

## 2. 데이터베이스 설계 (Current: SQLite -> Future: MongoDB)
- **선택 이유:** 기기마다 다른 버튼 구성(그리드, 리스트, 혼합형)을 유연하게 저장하기 위해 문서 지향(Document-oriented) 구조가 적합함.
- **테이블/컬렉션 구조 (`device_profiles`):**
  - `device_id` (PK): QR/NFC에 저장된 고유 식별자 (예: `MW-SAMSUNG-001`)
  - `device_type`: 가전 종류 (전자레인지, 세탁기 등)
  - `description`: 기기 모델명 및 설명
  - `grid`: `{ rows, cols, originX, originY, pitchX, pitchY }`
  - `buttons`: `[ { button_id, row, col, label }, ... ]`

## 3. 접근 방식 (QR / NFC / Manual)
- **QR Code:** 카메라로 스캔 시 `touchbridge://profile/{device_id}` 형태의 URL을 파싱하여 클라우드 API 호출.
- **NFC Tag:** 시각장애인 접근성이 가장 높은 방식. 기기 본체에 부착된 NFC 태그에 폰을 대면 즉시 프로필 로드.
- **Manual Code:** 태그 훼손 시를 대비해 기기에 점자로 표기된 4~6자리 고유 코드를 수동 입력하여 검색.

## 4. API 엔드포인트
- `GET /device-profile/{device_id}`: 기기 정보 조회
- `POST /vision-mapping?save_as_id={id}`: 새로운 기기 분석 및 클라우드 저장 (관리자/사용자 기여용)

## 5. 단계별 로드맵
- [x] **Phase 1:** 로컬 DB(SQLite) 구축 및 API 인터페이스 정의
- [ ] **Phase 2:** 앱 내 NFC 읽기 기능 및 수동 입력 UI 구현
- [ ] **Phase 3:** MongoDB Atlas 전환 및 프로덕션 클라우드 배포
