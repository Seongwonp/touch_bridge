import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'hardware_protocol.dart';
import 'app_logger.dart';

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
        final res = utf8.decode(value).trim();
        _addLog('RECV: $res');
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
    }
  }

  Future<String> _sendAndWaitAck(
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final c = _commandCharacteristic;
    if (c == null) return 'ERROR:NOT_CONNECTED';

    final json = jsonEncode(payload);
    _addLog('SEND: $json');
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

  Future<bool> sendPress({
    required int x,
    required int y,
    required String deviceId,
  }) async {
    final res = await _sendAndWaitAck({
      'action': HardwareProtocol.actionPress,
      'x': x,
      'y': y,
      'deviceId': deviceId,
    });
    return res.toLowerCase().contains('ok');
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
    // 하드웨어 mm*10 스케일 반영
    final res = await _sendAndWaitAck({
      'action': HardwareProtocol.actionSetGrid,
      'rows': rows,
      'cols': cols,
      'ox10': (originX * 10).toInt(),
      'oy10': (originY * 10).toInt(),
      'px10': (pitchX * 10).toInt(),
      'py10': (pitchY * 10).toInt(),
      'deviceId': deviceId,
    });
    return res.toLowerCase().contains('ok');
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

  Future<void> sendEmergencyStop(String deviceId) async {
    await _sendAndWaitAck({
      'action': HardwareProtocol.actionStop,
      'deviceId': deviceId,
    }, timeout: const Duration(seconds: 1));
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
