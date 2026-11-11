import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/ble_service.dart';

/// 위치 맞추기 화면은 장치가 알려 준 실제 위치로 버튼을 저장한다.
/// 펌웨어 상태 줄에서 위치·원점 기준·대기열을 읽는다.
void main() {
  test('펌웨어 상태 줄에서 실제 위치를 읽는다', () {
    final s = BleService.parseMotionStatus(
      'STATE IDLE homed=1 pos=(12.30, -4.05) ref=(12.30, -4.05) enc=(10, 20) bot=0 q=0 auth=none',
    );
    expect(s, isNotNull);
    expect(s!.x, closeTo(12.30, 1e-9));
    expect(s.y, closeTo(-4.05, 1e-9));
    expect(s.homed, isTrue);
    expect(s.queue, 0);
  });

  test('이동 중이면 대기열 수를 읽는다', () {
    final s = BleService.parseMotionStatus(
      'STATE MOVING homed=0 pos=(1.00, 2.00) ref=(5.00, 2.00) enc=(0, 0) bot=0 q=2 auth=ok',
    );
    expect(s!.homed, isFalse);
    expect(s.queue, 2);
  });

  test('상태 줄이 아니면 null', () {
    expect(BleService.parseMotionStatus('{"event":"power","w":0.0,"state":"off"}'), isNull);
    expect(BleService.parseMotionStatus('OK'), isNull);
  });

  test('상대 이동 도중 정지가 들어오면 남은 줄을 보내지 않는다', () async {
    final ble = BleService.instance;
    final sent = <String>[];
    ble.setPriorityStopOverride((_) async => 'STOPPED');
    ble.setSendRawOverride((cmd) async {
      sent.add(cmd);
      // 첫 줄(G91)을 보낸 직후 사용자가 정지를 누른다.
      if (cmd == 'G91') await ble.sendEmergencyStop('dev');
      return true;
    });
    addTearDown(() {
      ble.setSendRawOverride(null);
      ble.setPriorityStopOverride(null);
    });

    final ok = await ble.sendRelativeMove(axis: 'X', value: 5);

    expect(ok, isFalse);
    expect(sent, ['G91'], reason: '정지 뒤에는 이동(G1)도 모드 복귀(G90)도 나가지 않는다');
  });
}
