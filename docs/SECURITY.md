# 보안 문서 (프로토타입 권고 및 프로덕션 전환 지침)

본 문서는 현재 구현된 BLE 챌린지-리스폰스(provision/challenge/auth) 방식을 설명하고, 프로덕션에서 필요한 보안 강화 항목을 정리합니다.

## 현재 구현 요약

- 앱 ↔ ESP 간: 프로비저닝(provision)으로 공유 비밀(secret)을 ESP NVS에 저장
- 세션 인증: 앱이 `challenge` 요청 → ESP가 NONCE 반환 → 앱이 HMAC_SHA256(secret, nonce) 계산 후 `auth` 전송 → ESP가 검증하면 세션 인증(5분)
- 인증되지 않은 세션에서는 `press`/`set_grid` 등 주요 명령을 거부. `stop`은 인증 없이 항상 허용(안전)

## 앱 개발자/운영자 지침

- 프로덕션 전환 전 반드시 다음을 고려:
  1. BLE LE Secure Connections(Bluetooth 4.2/5의 보안) 사용 — 페어링+암호화 강제
  2. 프로비저닝에 사용되는 비밀은 사용자 기기의 Secure Storage(Keystore/Keychain)에 저장
  3. ESP에 평문 비밀 저장 금지 — 가능하면 암호화 또는 secure element 사용
  4. OTA 펌웨어 서명 도입 — 악성 펌웨어 배포 방지
  5. 프로비저닝 via BLE 제거 또는 관리 콘솔(서버) + QR 서명 방식 채택

## 권장 아키텍처(프로덕션)

- 장치 고유 비대칭 키(프라이빗 키는 안전 요소/보관소에 보관) → 서버에서 서명한 토큰을 앱에 발급 → 앱은 토큰으로 장치 검증
- BLE에는 LE Secure Connections + bonding 사용, ATT write 권한 최소화
- 모든 명령에 대해 서명(또는 MAC) 검증, 타임스탬프/논스 포함으로 재생 공격 방지

## 테스트 시나리오(개발자)

1. 프로비저닝: 앱에서 임시 secret 전송 → ESP가 PROVISION_OK 반환
2. 인증: `challenge` → `auth`(HMAC) → AUTH_OK
3. 명령: `press` 후 TOUCH_OK 수신 확인
4. 비상상황: 인증 없이 `stop`이 동작하는지 확인

## 로그·민감정보

- 개발 빌드에서는 디버그 로그(Serial/노티파이)를 남길 수 있으나, 프로덕션 빌드에서는 민감정보(Secret/키/풀텍스트 로그)를 남기지 않도록 제거

---

추가로 HSM/secure element(예: ATECC608A) 연동 설계가 필요하면 도와드리겠습니다.