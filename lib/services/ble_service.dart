import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'hardware_protocol.dart';
import 'app_logger.dart';
import 'ble_security_session.dart';

// ESP32 GATT 스펙:
// Service UUID   : 0000FFE0-0000-1000-8000-00805F9B34FB
// Characteristic : 0000FFE1-0000-1000-8000-00805F9B34FB

class BleService {
  BleService._() {
    _security = BleSecuritySession(onLog: _addLog);
  }
  static final BleService instance = BleService._();

  static final Guid _serviceUuid = Guid(HardwareProtocol.serviceUuid);
  static final Guid _characteristicUuid = Guid(
    HardwareProtocol.characteristicUuid,
  );
  static const _targetNameHints = ['ble bridge', 'esp32', 'touch bridge'];

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commandCharacteristic;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  final _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  Completer<String>? _ackCompleter;
  String? _lastScanError;

  Future<List<BleDeviceInfo>> Function(Duration timeout)? _scanOverride;
  Future<bool> Function(String deviceId)? _connectOverride;
  Future<bool> Function(String command)? _sendRawOverride;

  // Security/session — challenge-response 인증은 BleSecuritySession에 위임
  late final BleSecuritySession _security;

  static const _nonAuthActions = {
    'challenge',
    'auth',
    'provision',
    HardwareProtocol.actionStop,
    HardwareProtocol.actionSetGrid,
    HardwareProtocol.actionPress,
  };

  // [디버그/데모 전용] 실제 BLE 없이 전송을 성공으로 흉내낸다(시뮬레이터 테스트용).
  // 릴리스에서는 enableDemoMode를 호출하지 않으므로 항상 false다.
  bool _demoMode = false;
  String _demoDeviceId = '';

  /// [디버그/데모 전용] BLE 없이 전송/응답을 성공으로 처리한다.
  void enableDemoMode(String deviceId) {
    if (!kDebugMode) return;
    _demoMode = true;
    _demoDeviceId = deviceId;
    _addLog('DEMO MODE ON: $deviceId (실제 BLE 전송 안 함)');
  }

  bool get isConnected =>
      _demoMode || (_connectedDevice != null && _commandCharacteristic != null);
  String? get lastScanError => _lastScanError;
  BluetoothAdapterState get adapterState => _adapterState;
  String get connectedDeviceId =>
      _demoMode ? _demoDeviceId : (_connectedDevice?.remoteId.str ?? '');
  String get connectedDeviceName {
    final name = _connectedDevice?.platformName.trim() ?? '';
    return name.isEmpty ? connectedDeviceId : name;
  }

  void _addLog(String msg) {
    final ts = DateTime.now().toString().split(' ').last.substring(0, 8);
    final formatted = '[$ts] $msg';
    _logController.add(formatted);
    if (kDebugMode) debugPrint('[BLE] $formatted');
  }

  String _normalizeHardwareLog(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return 'UART_RX: <empty>';
    if (trimmed.startsWith('AVR:') ||
        trimmed.startsWith('ESP:') ||
        trimmed.startsWith('UART:') ||
        trimmed.startsWith('HW:') ||
        trimmed.startsWith('TOUCH_OK') ||
        trimmed.startsWith('ERROR:')) {
      return trimmed;
    }
    return 'UART_RX: $trimmed';
  }

  void warmUp() {
    _adapterStateSub ??= FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      _addLog('어댑터 상태: ${state.name}');
    });
    _adapterState = FlutterBluePlus.adapterStateNow;
  }

  Future<List<BleDeviceInfo>> scan({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_scanOverride != null) {
      return _scanOverride!.call(timeout);
    }
    if (kIsWeb) {
      _addLog('Web BLE not supported');
      return const [];
    }

    _lastScanError = null;
    warmUp();
    final adapterReady = await _waitForAdapterOn(
      timeout: const Duration(seconds: 10),
    );
    if (!adapterReady) {
      _lastScanError = 'BLUETOOTH_NOT_READY';
      _addLog('스캔 취소: 블루투스 어댑터가 준비되지 않았습니다.');
      AppLogger.warn('ble.scan.not_ready', {
        'adapter_state': FlutterBluePlus.adapterStateNow.name,
      });
      return const [];
    }

    final found = <String, BleDeviceInfo>{};
    late final StreamSubscription<List<ScanResult>> sub;
    sub = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final id = result.device.remoteId.str;
        final advName = result.advertisementData.advName.trim();
        final platformName = result.device.platformName.trim();
        final candidateName = advName.isNotEmpty
            ? advName
            : (platformName.isNotEmpty ? platformName : 'Unknown BLE Device');

        final serviceUuids = result.advertisementData.serviceUuids;
        final matchesService = serviceUuids.contains(_serviceUuid);
        final matchesName = _targetNameHints.any(
          (hint) =>
              candidateName.toLowerCase().contains(hint) ||
              platformName.toLowerCase().contains(hint),
        );

        if (!matchesService && !matchesName) {
          continue;
        }

        found[id] = BleDeviceInfo(
          id: id,
          name: candidateName,
          rssi: result.rssi,
        );
      }
    });

    try {
      _addLog('스캔 시작 (${timeout.inSeconds}초)');
      AppLogger.info('ble.scan.start', {'timeout_ms': timeout.inMilliseconds});
      await FlutterBluePlus.startScan(timeout: timeout);
      await Future<void>.delayed(timeout);
    } catch (e) {
      _lastScanError = e.toString();
      _addLog('스캔 오류: $e');
      AppLogger.warn('ble.scan.error', {'error': e.toString()});
    } finally {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    }

    final list = found.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    _addLog('스캔 완료 (${list.length}개 발견)');
    return list;
  }

  Future<bool> _waitForAdapterOn({required Duration timeout}) async {
    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < timeout) {
      final state = _adapterState == BluetoothAdapterState.unknown
          ? FlutterBluePlus.adapterStateNow
          : _adapterState;
      if (state == BluetoothAdapterState.on) {
        return true;
      }
      if (state == BluetoothAdapterState.off ||
          state == BluetoothAdapterState.unavailable ||
          state == BluetoothAdapterState.unauthorized) {
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
  }

  Future<bool> connect(String deviceId) async {
    if (_connectOverride != null) {
      return _connectOverride!.call(deviceId);
    }
    if (kIsWeb) return false;

    try {
      _addLog('기기 연결 시도: $deviceId');
      AppLogger.info('ble.connect.start', {'device_id': deviceId});

      final target = BluetoothDevice.fromId(deviceId);

      await disconnect();

      // 연결 상태 모니터링 시작
      target.connectionState.listen((state) {
        _connectionStateController.add(state);
        _addLog('연결 상태 변경: ${state.name}');
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _commandCharacteristic = null;
          _notifySub?.cancel();
          _security.reset();
        }
      });

      await target.connect(timeout: const Duration(seconds: 10));
      final services = await target.discoverServices();

      BluetoothCharacteristic? characteristic;
      for (final s in services) {
        if (s.uuid == _serviceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid == _characteristicUuid) {
              characteristic = c;
              break;
            }
          }
        }
      }

      if (characteristic == null) {
        _addLog('서비스/특성을 찾을 수 없습니다.');
        await target.disconnect();
        return false;
      }

      _connectedDevice = target;
      _commandCharacteristic = characteristic;

      // Notify 활성화 및 리스너 등록
      await characteristic.setNotifyValue(true);
      _notifySub = characteristic.lastValueStream.listen((value) {
        if (value.isEmpty) return;

        String res;
        try {
          res = utf8.decode(value, allowMalformed: true).trim();
        } catch (e) {
          res = 'DECODE_ERROR: ${value.toString()}';
        }

        _addLog('RECV: ${_normalizeHardwareLog(res)}');
        // isCompleted 체크: 빠른 연속 알림이 오면 이미 완료된 Completer에
        // 다시 complete를 시도해 StateError가 발생하므로 반드시 가드한다.
        if (_ackCompleter != null && !_ackCompleter!.isCompleted) {
          _ackCompleter!.complete(res);
        }
      });

      _addLog('연결 성공: ${target.platformName}');
      AppLogger.info('ble.connect.ok', {'device_id': deviceId});
      return true;
    } catch (e) {
      _addLog('연결 실패: $e');
      AppLogger.error('ble.connect.error', {
        'device_id': deviceId,
        'error': e.toString(),
      });
      await disconnect();
      return false;
    }
  }

  Future<bool> ensureConnected(String deviceId) async {
    if (_demoMode) return true;
    if (isConnected && _connectedDevice?.remoteId.str == deviceId) {
      return true;
    }
    return await connect(deviceId);
  }

  Future<void> disconnect() async {
    try {
      await _notifySub?.cancel();
      await _connectedDevice?.disconnect();
    } catch (e) {
      _addLog('연결 해제 중 오류: $e');
    } finally {
      _addLog('연결 해제 완료');
      _connectedDevice = null;
      _commandCharacteristic = null;
      _notifySub = null;
      _security.reset();
    }
  }

  Future<String> _sendAndWaitAck(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 5),
    bool waitAck = true, // ACK 대기 여부 추가
  }) async {
    if (_demoMode) {
      _addLog('DEMO ACK: ${payload['action']}');
      return 'OK';
    }
    final c = _commandCharacteristic;
    if (c == null) return 'ERROR:NOT_CONNECTED';

    final action = payload['action'] as String?;
    if (action == null || !_nonAuthActions.contains(action)) {
      final ok = await _security.ensureAuthenticated(
        sendAndWaitAck: _sendAndWaitAck,
      );
      if (!ok) return 'ERROR:AUTH_REQUIRED';
    }

    final json = jsonEncode(payload);
    _addLog('SEND: $json');

    if (!waitAck) {
      try {
        await c.write(utf8.encode(json), withoutResponse: false);
        return 'OK'; // 대기 없이 즉시 성공 반환
      } catch (e) {
        _addLog('전송 오류: $e');
        return 'ERROR:WRITE_FAILED';
      }
    }

    _ackCompleter = Completer<String>();
    try {
      await c.write(utf8.encode(json), withoutResponse: false);
      final res = await _ackCompleter!.future.timeout(timeout);
      return res;
    } catch (e) {
      _addLog('전송/응답 타임아웃 또는 오류: $e');
      return 'ERROR:TIMEOUT';
    } finally {
      _ackCompleter = null; // 타임아웃이나 에러 발생 시 반드시 null 처리하여 다음 명령 방해 금지
    }
  }

  Future<bool> sendRaw(String command) async {
    if (_sendRawOverride != null) return _sendRawOverride!(command);
    if (_demoMode) {
      _addLog('DEMO SEND_RAW: $command');
      return true;
    }
    _addLog('SEND_RAW: $command');
    final c = _commandCharacteristic;
    if (c == null) return false;
    try {
      await c.write(utf8.encode('$command\r\n'), withoutResponse: false);
      return true;
    } catch (e) {
      _addLog('RAW 전송 오류: $e');
      return false;
    }
  }

  Future<bool> sendRelativeMove({
    required String axis,
    required double value,
    int feedRate = 800,
  }) async {
    final normalizedAxis = axis.toUpperCase();
    if (!const {'X', 'Y', 'Z'}.contains(normalizedAxis)) {
      _addLog('상대 이동 오류: 잘못된 축 $axis');
      return false;
    }

    final okMode = await sendRaw('G91');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final okMove = await sendRaw('G1 $normalizedAxis$value F$feedRate');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final okReset = await sendRaw('G90');
    return okMode && okMove && okReset;
  }

  Future<String?> readResponse({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final c = _commandCharacteristic;
    if (c == null) return null;

    _ackCompleter = Completer<String>();
    try {
      final res = await _ackCompleter!.future.timeout(timeout);
      return res;
    } catch (e) {
      _addLog('응답 대기 타임아웃: $e');
      return null;
    } finally {
      _ackCompleter = null;
    }
  }

  Future<bool> sendPress({
    required int x,
    required int y,
    required int cols,
    required String deviceId,
  }) async {
    final btnNum = (y * cols) + x + 1;
    final startTime = DateTime.now();
    debugPrint(
      '[BLE_HW] Sending PRESS command: x=$x, y=$y (btnNum=$btnNum, device=$deviceId)',
    );

    // 하드웨어(GRBL)는 BTN_n 형식을 인식함
    final cmd = '${HardwareProtocol.uartBtnPrefix}$btnNum';
    final success = await sendRaw(cmd);

    if (success) {
      final endTime = DateTime.now();
      final latency = endTime.difference(startTime).inMilliseconds;
      AppLogger.info('ble.command.press', {
        'device_id': deviceId,
        'btn': btnNum,
        'latency_ms': latency,
      });
      debugPrint('[BLE_LATENCY] Press command latency: ${latency}ms');
    }

    return success;
  }

  Future<bool> sendSetGrid({
    required int rows,
    required int cols,
    required double originX,
    required double originY,
    required double pitchX,
    required double pitchY,
    required String deviceId,
  }) async {
    final ox10 = (originX * 10).toInt();
    final oy10 = (originY * 10).toInt();
    final px10 = (pitchX * 10).toInt();
    final py10 = (pitchY * 10).toInt();
    debugPrint(
      '[BLE_HW] Sending SET_GRID: rows=$rows, cols=$cols, ox10=$ox10, oy10=$oy10, px10=$px10, py10=$py10 (device=$deviceId)',
    );

    // JSON 대신 하드웨어가 직접 인식하는 텍스트 명령 전송
    final cmd =
        '${HardwareProtocol.uartSetGridPrefix} $rows $cols $ox10 $oy10 $px10 $py10';
    return await sendRaw(cmd);
  }

  Future<String?> sendGetStatus() async {
    // 하드웨어 상태를 요청하는 텍스트 명령 '$$' 전송
    if (await sendRaw('\$\$')) {
      return await readResponse(timeout: const Duration(seconds: 2));
    }
    return null;
  }

  Future<bool> sendSetServo({
    required int upAngle,
    required int downAngle,
    required int pressMs,
  }) async {
    final res = await _sendAndWaitAck({
      'action': HardwareProtocol.actionSetServo,
      'up': upAngle,
      'down': downAngle,
      'ms': pressMs,
    });
    return res.toLowerCase().contains('ok');
  }

  Future<String> sendGetServo() async {
    return await _sendAndWaitAck({'action': HardwareProtocol.actionGetServo});
  }

  Future<void> sendHoming(String deviceId) async {
    await _sendAndWaitAck({
      'action': 'home',
      'deviceId': deviceId,
    }, timeout: const Duration(seconds: 5));
  }

  /// 비상 정지 명령을 전송하고 controller ACK 결과 문자열을 그대로 반환한다.
  ///
  /// 반환값: 'OK'/ACK 문자열(응답 확인), 또는
  /// 'ERROR:NOT_CONNECTED' / 'ERROR:TIMEOUT' / 'ERROR:WRITE_FAILED' 등.
  /// 호출부는 이 값을 [EmergencyStopOutcome.fromAck]로 해석해 사용자에게
  /// 정직한 상태(멈춤 확인 vs 전송만 됨 vs 실패)를 안내해야 한다.
  Future<String> sendEmergencyStop(String deviceId) async {
    return _sendAndWaitAck({
      'action': HardwareProtocol.actionStop,
      'deviceId': deviceId,
    }, timeout: const Duration(seconds: 1));
  }

  /// Provision a device pairing key. The secret is stored in platform-secure storage
  /// and also sent to the device for initial provisioning. This call does not require
  /// an authenticated session.
  Future<bool> provisionPairKey(String secret) async {
    final c = _commandCharacteristic;
    if (c == null) return false;
    return _security.provisionPairKey(
      secret,
      sendAndWaitAck: (payload) => _sendAndWaitAck(payload),
    );
  }

  @visibleForTesting
  void setTestOverrides({
    Future<List<BleDeviceInfo>> Function(Duration timeout)? scan,
    Future<bool> Function(String deviceId)? connect,
  }) {
    _scanOverride = scan;
    _connectOverride = connect;
  }

  @visibleForTesting
  void clearTestOverrides() {
    _scanOverride = null;
    _connectOverride = null;
  }

  @visibleForTesting
  void setSendRawOverride(Future<bool> Function(String command)? fn) {
    _sendRawOverride = fn;
  }
}

class BleDeviceInfo {
  const BleDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
  });
  final String id;
  final String name;
  final int rssi;
}
