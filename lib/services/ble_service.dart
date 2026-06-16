import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'hardware_protocol.dart';
import 'app_logger.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ESP32 GATT 스펙:
// Service UUID   : 0000FFE0-0000-1000-8000-00805F9B34FB
// Characteristic : 0000FFE1-0000-1000-8000-00805F9B34FB

class BleService {
  BleService._();
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

  // Security/session
  final _secureStorage = const FlutterSecureStorage();
  String? _pairKey;
  bool _sessionAuthenticated = false;
  int _sessionAuthExpiryMs = 0;

  static const _nonAuthActions = {
    'challenge',
    'auth',
    'provision',
    HardwareProtocol.actionStop,
    HardwareProtocol.actionSetGrid,
    HardwareProtocol.actionPress,
  };

  bool get isConnected =>
      _connectedDevice != null && _commandCharacteristic != null;
  String? get lastScanError => _lastScanError;
  BluetoothAdapterState get adapterState => _adapterState;
  String get connectedDeviceId => _connectedDevice?.remoteId.str ?? '';
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

  Future<void> _loadPairKey() async {
    if (_pairKey != null) return;
    try {
      _pairKey = await _secureStorage.read(key: 'ble_pair_key');
      if (_pairKey != null) _addLog('SEC: pair key loaded');
    } catch (e) {
      _addLog('SEC: load key error $e');
    }
  }

  String _bytesToHex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  String _hmacHex(String key, String data) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(data));
    return _bytesToHex(digest.bytes);
  }

  Future<bool> _ensureSessionAuthenticated({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_sessionAuthenticated && DateTime.now().millisecondsSinceEpoch < _sessionAuthExpiryMs) {
      return true;
    }

    await _loadPairKey();
    if (_pairKey == null) return false; // not provisioned

    // Request nonce (challenge)
    final nonceResp = await _sendAndWaitAck({'action': 'challenge'}, timeout: timeout);
    if (!nonceResp.startsWith('NONCE:')) return false;
    final nonce = nonceResp.substring(6);

    final mac = _hmacHex(_pairKey!, nonce);
    final authResp = await _sendAndWaitAck({'action': 'auth', 'mac': mac}, timeout: timeout);

    if (authResp.toUpperCase().contains('AUTH_OK')) {
      _sessionAuthenticated = true;
      _sessionAuthExpiryMs = DateTime.now().millisecondsSinceEpoch + (5 * 60 * 1000); // 5 minutes
      _addLog('SEC: session authenticated');
      return true;
    }
    _addLog('SEC: authentication failed');
    return false;
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
          _sessionAuthenticated = false;
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
        _ackCompleter?.complete(res);
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
      _sessionAuthenticated = false;
    }
  }

  Future<String> _sendAndWaitAck(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 5),
    bool waitAck = true, // ACK 대기 여부 추가
  }) async {
    final c = _commandCharacteristic;
    if (c == null) return 'ERROR:NOT_CONNECTED';

    final action = payload['action'] as String?;
    if (action == null || !_nonAuthActions.contains(action)) {
      final ok = await _ensureSessionAuthenticated();
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
      _addLog('전송/응답 타임아웃: $e');
      return 'ERROR:TIMEOUT';
    } finally {
      _ackCompleter = null;
    }
  }

  Future<bool> sendRaw(String command) async {
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

  Future<String?> readResponse({Duration timeout = const Duration(seconds: 2)}) async {
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
    debugPrint('[BLE_HW] Sending PRESS command: x=$x, y=$y (btnNum=$btnNum, device=$deviceId)');
    
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
    debugPrint('[BLE_HW] Sending SET_GRID: rows=$rows, cols=$cols, ox10=$ox10, oy10=$oy10, px10=$px10, py10=$py10 (device=$deviceId)');
    
    // JSON 대신 하드웨어가 직접 인식하는 텍스트 명령 전송
    final cmd = '${HardwareProtocol.uartSetGridPrefix} $rows $cols $ox10 $oy10 $px10 $py10';
    return await sendRaw(cmd);
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

  Future<void> sendEmergencyStop(String deviceId) async {
    await _sendAndWaitAck({
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
    final res = await _sendAndWaitAck({'action': 'provision', 'secret': secret});
    if (res.toUpperCase().contains('PROVISION_OK')) {
      try {
        await _secureStorage.write(key: 'ble_pair_key', value: secret);
        _pairKey = secret;
        _addLog('SEC: pair key stored');
        return true;
      } catch (e) {
        _addLog('SEC: store key failed $e');
      }
    }
    return false;
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
