# 보안 문서 (프로토타입 권고 및 프로덕션 전환 지침)

본 문서는 현재 구현된 BLE 챌린지-리스폰스(provision/challenge/auth) 방식을 설명하고, 프로덕션에서 필요한 보안 강화 항목을 정리합니다.

## 현재 구현 요약 (펌웨어 v3, `hardware/touchbridge_corexy/` 기준)

- 앱 ↔ ESP 간: 프로비저닝(provision)으로 공유 비밀(secret, 최소 8자)을 ESP NVS에 저장.
  소스 코드에는 기본 비밀값이 없다.
- 세션 인증: 앱이 `challenge` 요청 → ESP가 NONCE 반환 → 앱이 HMAC_SHA256(secret, nonce) 계산 후 `auth` 전송 → ESP가 검증하면 세션 인증(5분)
- 키가 등록된 기기에서는 인증되지 않은 BLE 세션의 물리 동작(`press`, 이동, `SET_GRID` 등)을 거부한다.
- `stop`은 인증 없이 항상 허용(안전).
- 이미 등록된 키는 유효한 세션이나 USB 시리얼에서만 교체할 수 있다.
- 부팅·상태 로그에는 키 자체가 아니라 등록 여부(`set`/`none`)와 세션 상태(`ok`/`locked`)만 찍힌다.

### 인증의 예외 — 반드시 알고 있어야 할 것

- **키 등록 전에는 인증이 없다.** 키가 없는 기기는 BLE 범위 안의 누구든 동작시킬 수 있고,
  **첫 키도 누구나 등록할 수 있다**(trust on first use). 공개 장소 시연 전에는 키를 먼저 등록할 것.
- **USB 시리얼은 항상 인증 없이 허용된다.** 기기에 물리적으로 케이블을 꽂을 수 있으면
  모든 명령을 보낼 수 있고, 시리얼 전용 `KEYRESET`으로 페어링 키를 지울 수도 있다.

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
3. 명령: `move_only`로 `POSITIONED`와 `positionToken`을 받은 뒤, 그 토큰으로 `press` →
   `COMPLETED` 수신 확인 (펌웨어 v3는 옛 `TOUCH_OK` 응답을 보내지 않는다)
4. 거부: 인증 없이 `press` → `ERROR_PROTOCOL`(`AUTH_REQUIRED`)로 거부되는지 확인
5. 비상상황: 인증 없이 `stop`이 동작하는지 확인

## 로그·민감정보

- 개발 빌드에서는 디버그 로그(Serial/노티파이)를 남길 수 있으나, 프로덕션 빌드에서는 민감정보(Secret/키/풀텍스트 로그)를 남기지 않도록 제거
- 키를 안전 요소에 보관하는 방식(예: ATECC608A 같은 secure element)은 프로덕션 전환 시 검토 대상이다.