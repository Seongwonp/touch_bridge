/// 부스 시연용 빌드 설정.
///
/// `--dart-define=TOUCH_BRIDGE_BOOTH=true`로 빌드하면 방문객이 핵심 흐름(말하기 → 확인 →
/// 누르기 → 정지)에서 벗어나지 않도록 보조 기능의 진입점을 숨긴다. 기능 코드는 지우지
/// 않는다. 숨기는 것: 조작 메뉴의 간편 코스·숫자 패드, 설정의 연습 모드.
class BoothMode {
  BoothMode._();

  static const bool enabled = bool.fromEnvironment(
    'TOUCH_BRIDGE_BOOTH',
    defaultValue: false,
  );
}
