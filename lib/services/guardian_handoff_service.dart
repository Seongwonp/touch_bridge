import '../models/handoff_report.dart';
import 'ble_service.dart';
import 'device_mapping_service.dart';
import 'home_device_store.dart';
import 'mapping_execution_service.dart';

/// 보호자가 기기 설정(매핑/등록)을 마친 직후 "사용자가 정말 혼자 쓸 수
/// 있는지"를 점검하는 인수 체크리스트.
///
/// 지금까지 매핑 저장은 스낵바 한 줄 띄우고 홈으로 돌아가는 게 전부라,
/// 실제로 준비가 됐는지 확인하는 단계가 없었다(Codex Part B "보호자→사용자
/// 인수 테스트" 갭). 하드웨어가 연결돼 있지 않을 수도 있으므로, 여기서
/// "확인함"이라고 주장하는 항목은 소프트웨어로 실제 검증 가능한 것들뿐이다.
/// 물리적으로 버튼이 정확히 눌리는지는 여전히 보호자가 직접(좌표 테스트로)
/// 확인해야 하며, 이 체크리스트는 그 이전 단계의 설정 오류를 잡아준다.
class GuardianHandoffService {
  GuardianHandoffService._();
  static final GuardianHandoffService instance = GuardianHandoffService._();

  Future<HandoffReport> run({
    required String deviceId,
    String? testButtonId,
  }) async {
    final items = <HandoffCheckItem>[];

    final devices = await HomeDeviceStore.loadDevices();
    final deviceExists = devices.any((d) => d['id'] == deviceId);
    items.add(
      HandoffCheckItem(
        label: '기기가 홈 화면 목록에 등록됨',
        passed: deviceExists,
        detail: deviceExists
            ? null
            : '홈 화면에 기기가 보이지 않을 수 있습니다. 기기 등록을 다시 확인하세요.',
      ),
    );

    final connected = BleService.instance.isConnected;
    items.add(
      HandoffCheckItem(
        label: '기기와 블루투스로 연결됨',
        passed: connected,
        detail: connected
            ? null
            : '지금 연결이 끊겨 있습니다. 사용자는 혼자 다시 연결할 수 없으므로, 앱을 켤 때 자동 연결되는지 확인하세요.',
      ),
    );

    final profile = await DeviceMappingService.instance.load(deviceId);
    // buttonMap이 비어 있어도 "좌표로 설정" 경로는 그리드 기반 fallback으로
    // 정상 동작하므로(사진 매핑처럼 버튼별 위치가 없을 뿐), 저장된 적이
    // 있는지로 판단한다. 둘 다 저장 시점에 프로필이 생기기 때문이다.
    final hasSavedProfile = await DeviceMappingService.instance.hasSavedProfile(
      deviceId,
    );
    items.add(
      HandoffCheckItem(
        label: '버튼 위치가 매핑됨',
        passed: hasSavedProfile,
        detail: hasSavedProfile
            ? null
            : '아직 매핑된 버튼이 없습니다. 사진 매핑이나 좌표 설정으로 버튼 위치를 등록하세요.',
      ),
    );

    final pitchValid = profile.pitchX != 0 && profile.pitchY != 0;
    items.add(
      HandoffCheckItem(
        label: '버튼 간격 값이 정상',
        passed: pitchValid,
        detail: pitchValid
            ? null
            : '버튼 간격(pitch) 값이 0입니다. 모든 버튼이 같은 위치로 계산될 수 있으니 매핑을 다시 확인하세요.',
      ),
    );

    if (hasSavedProfile) {
      // buttonMap이 비어 있으면(좌표 전용 설정) MicrowaveCommandService의
      // 그리드 fallback으로 해석 가능한 대표 버튼(BT-05, 시작)을 대신 쓴다.
      final candidate =
          testButtonId ??
          (profile.buttonMap.isNotEmpty
              ? profile.buttonMap.keys.first
              : 'BT-05');
      final result = await MappingExecutionService.instance.pressButton(
        deviceId: deviceId,
        profile: profile,
        buttonId: candidate,
        dryRun: true,
      );
      items.add(
        HandoffCheckItem(
          label: '$candidate 버튼 명령 생성 확인',
          passed: result.ok,
          detail: result.ok
              ? null
              : '매핑 값에 문제가 있어 명령을 만들지 못했습니다. 좌표 값을 다시 확인하세요.',
        ),
      );
    }

    return HandoffReport(items: items);
  }
}
