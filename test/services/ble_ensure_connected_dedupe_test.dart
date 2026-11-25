import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/ble_service.dart';

void main() {
  tearDown(() => BleService.instance.clearTestOverrides());

  test('같은 장치로 동시에 부른 ensureConnected는 연결을 한 번만 시도한다', () async {
    var calls = 0;
    final gate = Completer<bool>();
    BleService.instance.setTestOverrides(connect: (_) {
      calls++;
      return gate.future;
    });

    final a = BleService.instance.ensureConnected('AA:BB');
    final b = BleService.instance.ensureConnected('AA:BB');
    final c = BleService.instance.ensureConnected('AA:BB');
    gate.complete(false);

    expect(await Future.wait([a, b, c]), [false, false, false]);
    expect(calls, 1);

    // 끝난 뒤에 다시 부르면 새로 시도한다.
    BleService.instance.setTestOverrides(connect: (_) async {
      calls++;
      return true;
    });
    expect(await BleService.instance.ensureConnected('AA:BB'), isTrue);
    expect(calls, 2);
  });

  test('다른 장치는 기다리지 않고 따로 시도한다', () async {
    final ids = <String>[];
    BleService.instance.setTestOverrides(connect: (id) async {
      ids.add(id);
      return false;
    });
    await Future.wait([
      BleService.instance.ensureConnected('AA:BB'),
      BleService.instance.ensureConnected('CC:DD'),
    ]);
    expect(ids, ['AA:BB', 'CC:DD']);
  });
}
