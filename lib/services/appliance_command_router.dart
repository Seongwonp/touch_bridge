import 'ac_command_service.dart';
import 'microwave_command_service.dart';
import 'washing_machine_command_service.dart';

/// 기기 이름/타입 문자열을 보고 적절한 가전 명령 서비스로 라우팅한다.
///
/// - deviceType 이 명시된 경우 우선 사용 (ApplianceType.name 형식)
/// - 없으면 deviceName 에서 키워드를 매칭해 추론
class ApplianceCommandRouter {
  const ApplianceCommandRouter._();

  /// 현재 기기에 맞는 간단 규칙을 실행한다.
  /// 매칭 결과가 없으면 null 을 반환 → 호출측이 AI 백엔드 파싱으로 폴백.
  static Map<String, dynamic>? checkSimpleRules(
    String commandText, {
    String? deviceName,
    String? deviceType,
  }) {
    final kind = _resolveKind(deviceName: deviceName, deviceType: deviceType);
    final result = switch (kind) {
      _ApplianceKind.washer =>
        WashingMachineCommandService.checkSimpleRules(commandText),
      _ApplianceKind.ac => AcCommandService.checkSimpleRules(commandText),
      _ApplianceKind.microwave =>
        MicrowaveCommandService.checkSimpleRules(commandText),
      _ApplianceKind.unknown =>
        MicrowaveCommandService.checkSimpleRules(commandText),
    };
    if (result == null) return null;

    // 간단 규칙은 문자열 매칭으로 확정된 결과라 불확실성이 없다. confidence가
    // 없으면 호출측이 기본값 0.5로 읽어 저신뢰 분기(< 0.55)에 걸리고, 실행 없이
    // 성공처럼 들리는 문구만 말하게 된다. 화면을 못 보는 사용자에게는 거짓 성공
    // 안내가 되므로 1.0을 명시한다.
    return {'confidence': 1.0, ...result};
  }

  static _ApplianceKind _resolveKind({
    String? deviceName,
    String? deviceType,
  }) {
    // 1. deviceType 이 있으면 직접 매핑 (ApplianceType.name 값과 일치)
    if (deviceType != null && deviceType.isNotEmpty) {
      return switch (deviceType.toLowerCase()) {
        'washer' => _ApplianceKind.washer,
        'airconditioner' || 'air_conditioner' || 'ac' =>
          _ApplianceKind.ac,
        'microwave' => _ApplianceKind.microwave,
        _ => _ApplianceKind.unknown,
      };
    }

    // 2. deviceName 키워드 추론 (deviceType 미지정 기기 대응)
    final name = (deviceName ?? '').toLowerCase();
    if (name.contains('세탁') || name.contains('washer') || name.contains('dryer') || name.contains('건조')) {
      return _ApplianceKind.washer;
    }
    if (name.contains('에어컨') || name.contains('냉방') || name.contains('air') || name.contains('aircon')) {
      return _ApplianceKind.ac;
    }
    if (name.contains('전자레인지') || name.contains('microwave') || name.contains('오븐')) {
      return _ApplianceKind.microwave;
    }
    return _ApplianceKind.unknown;
  }
}

enum _ApplianceKind { microwave, washer, ac, unknown }
