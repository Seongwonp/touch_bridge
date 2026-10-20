import 'active_device_service.dart';
import 'ble_service.dart';
import 'emergency_intent.dart';

/// 비상 정지 실행의 단일 창구.
///
/// 대상 결정 → 재연결 → STOP 전송 → ACK 해석을 이곳에서만 한다. 정지 경로는
/// 안전과 직결되므로 화면마다 사본을 두어 서로 어긋나면 안 된다.
class EmergencyStopService {
  EmergencyStopService._();
  static final EmergencyStopService instance = EmergencyStopService._();

  /// 현재 연결된 기기(우선) 또는 활성 기기로 중단 명령을 보낸다.
  ///
  /// 반환되는 [EmergencyStopOutcome]은 "확인됨/전송만 됨/실패"를 구분한다 —
  /// 호출부는 outcome.message를 반드시 emergency 우선순위 TTS로 안내하고,
  /// acknowledged일 때만 완료 화면으로 이동해야 한다(거짓 완료 금지).
  Future<EmergencyStopOutcome> stopActiveDevice() async {
    final connectedId = BleService.instance.connectedDeviceId;
    final targetId = connectedId.isNotEmpty
        ? connectedId
        : (ActiveDeviceService.instance.getActiveBleId() ?? '');

    if (targetId.isEmpty) {
      return const EmergencyStopOutcome(
        acknowledged: false,
        sent: false,
        message: '연결된 기기가 없습니다. 기기 전원을 확인해 주세요.',
      );
    }

    if (!BleService.instance.isConnected) {
      await BleService.instance.ensureConnected(targetId);
    }
    final ack = await BleService.instance.sendEmergencyStop(targetId);
    return EmergencyStopOutcome.fromAck(ack);
  }
}
