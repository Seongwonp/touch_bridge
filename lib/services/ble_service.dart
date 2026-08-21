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
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  final _connectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  /// 연결 여부만 필요한 위젯에서 flutter_blue_plus 없이 구독할 수 있는 편의 스트림.
  /// distinct: 연결 성공 시 명시 emit과 플랫폼 스트림 이벤트가 겹쳐도
  /// 구독 위젯(배너 TTS 등)이 같은 상태를 두 번 안내하지 않게 한다.
  Stream<bool> get isConnectedStream => connectionStateStream
      .map((s) => s == BluetoothConnectionState.connected)
      .distinct();

  // ── 자동 재연결 ──────────────────────────────────────────────────────────
  final _reconnectStateController =
      StreamController<BleReconnectState>.broadcast();

  /// 자동 재연결 상태 스트림 (reconnecting / reconnected / failed).
  Stream<BleReconnectState> get reconnectStateStream =>
      _reconnectStateController.stream;

  String? _autoReconnectTargetId;
  int _reconnectAttempt = 0;
  static const int _maxReconnectAttempts = 3;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;

  /// 현재 자동 재연결 시도 중인지 여부 (UI 상태 표시용).
  bool get isReconnecting => _isReconnecting;
  // ─────────────────────────────────────────────────────────────────────────

  Completer<String>? _ackCompleter;
  String? _lastScanError;

  Future<List<BleDeviceInfo>> Function(Duration timeout)? _scanOverride;
  Future<bool> Function(String deviceId)? _connectOverride;
  Future<bool> Function(String command)? _sendRawOverride;

  // Security/session — challenge-response 인증은 BleSecuritySession에 위임
  late final BleSecuritySession _security;

  // 인증 없이 허용되는 JSON 액션은 페어링·인증·비상정지뿐이다.
  // raw 경로(sendRaw)는 별도의 물리 동작 게이트
  // (BleSecuritySession.authorizePhysicalAction)를 거친다 —
  // 프로비저닝된 기기는 인증 필수, 미프로비저닝(데모)은 경고와 함께 허용.
  static const _nonAuthActions = {
    'challenge',
    'auth',
    'provision',
    HardwareProtocol.actionStop,
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

      // 연결 상태 모니터링 — 구독을 저장해 재연결 시 이전 구독을 취소한다.
      // 저장하지 않으면 연결을 바꿀 때마다 리스너가 누적되어 이전 기기의
      // disconnected 이벤트가 현재 연결을 잘못 초기화할 수 있다.
      //
      // 가드는 "이 구독이 아직 활성 구독인가"로 판단한다. 이전 구현은
      // `_connectedDevice?.remoteId != target.remoteId`로 가드했는데,
      // _connectedDevice는 discoverServices까지 끝난 뒤에야 설정되므로
      // 연결 직후 플랫폼이 밀어주는 connected 이벤트가 그 사이에 도착하면
      // 드롭되어 UI가 "연결됨" 안내를 영영 못 받는 문제가 있었다.
      _connectionSub?.cancel();
      late final StreamSubscription<BluetoothConnectionState> sub;
      sub = target.connectionState.listen((state) {
        if (!identical(sub, _connectionSub)) return; // 교체된 옛 구독이면 무시
        _connectionStateController.add(state);
        _addLog('연결 상태 변경: ${state.name}');
        if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _commandCharacteristic = null;
          _notifySub?.cancel();
          _security.reset();
          _maybeScheduleReconnect();
        }
      });
      _connectionSub = sub;

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

      // 성공한 기기 ID를 기억해 이후 끊김 시 자동 재연결 대상으로 쓴다.
      _autoReconnectTargetId = deviceId;
      _reconnectAttempt = 0;
      _addLog('연결 성공: ${target.platformName}');
      AppLogger.info('ble.connect.ok', {'device_id': deviceId});
      // 연결 완료를 명시적으로 emit — 플랫폼 스트림의 connected 이벤트가
      // 준비 전에 도착해 유실됐더라도 구독자(배너/TTS)는 반드시 알림을 받는다.
      // (isConnectedStream은 distinct라 중복 emit은 안내되지 않는다.)
      _connectionStateController.add(BluetoothConnectionState.connected);
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
    // 명시적 해제 → 자동 재연결 완전 중단. null이 돼야 _maybeScheduleReconnect가 조기 반환.
    _reconnectTimer?.cancel();
    _autoReconnectTargetId = null;
    _reconnectAttempt = 0;
    _isReconnecting = false;
    // 리스너를 먼저 취소하므로 플랫폼의 disconnected 이벤트는 UI에 전달되지
    // 않는다 — 실제로 연결돼 있던 경우에는 아래에서 직접 emit해 준다.
    final hadConnection = _connectedDevice != null;
    try {
      await _connectionSub?.cancel();
      await _notifySub?.cancel();
      await _connectedDevice?.disconnect();
    } catch (e) {
      _addLog('연결 해제 중 오류: $e');
    } finally {
      _addLog('연결 해제 완료');
      _connectedDevice = null;
      _commandCharacteristic = null;
      _connectionSub = null;
      _notifySub = null;
      _security.reset();
      if (hadConnection) {
        _connectionStateController.add(BluetoothConnectionState.disconnected);
      }
    }
  }

  /// 연결이 끊어졌을 때 지수 백오프로 자동 재연결을 예약한다.
  ///
  /// - 최대 [_maxReconnectAttempts]회 시도 (2초 → 4초 → 8초 간격)
  /// - [disconnect()]가 호출되면 [_autoReconnectTargetId]가 null이 되어 즉시 중단됨
  /// - connect() 내부의 disconnect()가 타겟을 지우기 때문에,
  ///   실패 후 재시도를 위해 타겟을 직접 복원하고 재귀 호출한다.
  void _maybeScheduleReconnect() {
    final targetId = _autoReconnectTargetId;
    if (targetId == null || _isReconnecting || _demoMode) return;

    if (_reconnectAttempt >= _maxReconnectAttempts) {
      _addLog('자동 재연결 포기 ($_maxReconnectAttempts회 시도 완료)');
      _reconnectAttempt = 0;
      _autoReconnectTargetId = null;
      _reconnectStateController.add(BleReconnectState.failed);
      return;
    }

    _reconnectAttempt++;
    _isReconnecting = true;
    // 지수 백오프: 1<<1=2초, 1<<2=4초, 1<<3=8초
    final delaySeconds = 1 << _reconnectAttempt;
    _addLog('자동 재연결 예약 ($_reconnectAttempt/$_maxReconnectAttempts, ${delaySeconds}초 후)');
    AppLogger.info('ble.reconnect.scheduled', {
      'attempt': _reconnectAttempt,
      'delay_s': delaySeconds,
      'target': targetId,
    });
    _reconnectStateController.add(BleReconnectState.reconnecting);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      // 이 시점에 disconnect()가 호출됐으면 중단.
      if (_autoReconnectTargetId == null) {
        _isReconnecting = false;
        return;
      }

      _isReconnecting = false;
      final success = await connect(targetId);

      if (success) {
        // connect() 내부에서 _autoReconnectTargetId = targetId로 이미 복원됨.
        _addLog('자동 재연결 성공');
        AppLogger.info('ble.reconnect.ok', {'target': targetId});
        _reconnectStateController.add(BleReconnectState.reconnected);
      } else {
        // connect()가 실패하면 내부에서 disconnect()를 호출해 _autoReconnectTargetId가
        // null로 지워진다. 다음 시도를 위해 복원 후 재귀 예약.
        _autoReconnectTargetId = targetId;
        _maybeScheduleReconnect();
      }
    });
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
    final c = _commandCharacteristic;
    if (c == null) return false;

    // 물리 동작 인증 게이트: 페어링 키가 프로비저닝된 기기는 유효한 HMAC
    // 세션 없이는 raw 명령(G-code/BTN_n/SET_GRID)을 보내지 않는다.
    // (이전에는 JSON 명령만 인증을 거치고 이 경로가 전부 우회됐다.)
    final authorized = await _security.authorizePhysicalAction(
      sendAndWaitAck: _sendAndWaitAck,
    );
    if (!authorized) {
      _addLog('RAW 차단: 인증되지 않은 세션 ($command)');
      AppLogger.warn('ble.raw.blocked_unauthorized', {'command': command});
      return false;
    }

    _addLog('SEND_RAW: $command');
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

  // ── 재연결 상태 머신 테스트 지원 ─────────────────────────────────────────
  @visibleForTesting
  bool get isReconnectingForTest => _isReconnecting;

  @visibleForTesting
  String? get autoReconnectTargetIdForTest => _autoReconnectTargetId;

  @visibleForTesting
  int get reconnectAttemptForTest => _reconnectAttempt;

  /// 재연결 상태를 스트림에 직접 emit — UI/위젯 테스트에서 상태 변화를 시뮬레이션.
  @visibleForTesting
  void emitReconnectStateForTest(BleReconnectState state) =>
      _reconnectStateController.add(state);

  /// 재연결 내부 상태 초기화 — 각 테스트 케이스 독립성 보장.
  @visibleForTesting
  void resetReconnectStateForTest() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _autoReconnectTargetId = null;
    _reconnectAttempt = 0;
    _isReconnecting = false;
  }
  // ─────────────────────────────────────────────────────────────────────────
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

/// BLE 자동 재연결 상태.
///
/// [reconnecting]: 재연결 시도 예약됨 (타이머 대기 or connect() 진행 중)
/// [reconnected]:  재연결 성공
/// [failed]:       최대 재시도 횟수 소진 → 사용자에게 수동 재연결 안내 필요
enum BleReconnectState { reconnecting, reconnected, failed }
