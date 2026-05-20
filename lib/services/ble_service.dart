import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ESP32 GATT 스펙:
// Service UUID   : 0000FFE0-0000-1000-8000-00805F9B34FB
// Characteristic : 0000FFE1-0000-1000-8000-00805F9B34FB

class BleService {
  BleService._();
  static final BleService instance = BleService._();

  static final Guid _serviceUuid = Guid('0000FFE0-0000-1000-8000-00805F9B34FB');
  static final Guid _characteristicUuid = Guid('0000FFE1-0000-1000-8000-00805F9B34FB');

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _commandCharacteristic;
  Future<List<BleDeviceInfo>> Function(Duration timeout)? _scanOverride;
  Future<bool> Function(String deviceId)? _connectOverride;

  bool get isConnected => _connectedDevice != null && _commandCharacteristic != null;
  String get connectedDeviceId => _connectedDevice?.remoteId.str ?? '';
  String get connectedDeviceName {
    final name = _connectedDevice?.platformName.trim() ?? '';
    return name.isEmpty ? connectedDeviceId : name;
  }

  Future<List<BleDeviceInfo>> scan({Duration timeout = const Duration(seconds: 5)}) async {
    if (_scanOverride != null) {
      return _scanOverride!.call(timeout);
    }
    if (kIsWeb) {
      if (kDebugMode) debugPrint('[BLE] Web BLE not supported in this flow');
      return const [];
    }

    final found = <String, BleDeviceInfo>{};
    late final StreamSubscription<List<ScanResult>> sub;
    sub = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final id = result.device.remoteId.str;
        final name = result.device.platformName.trim();
        final candidateName = name.isNotEmpty ? name : 'Unknown BLE Device';
        found[id] = BleDeviceInfo(
          id: id,
          name: candidateName,
          rssi: result.rssi,
        );
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      await Future<void>.delayed(timeout);
    } catch (e) {
      if (kDebugMode) debugPrint('[BLE] scan error: $e');
    } finally {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    }

    final list = found.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  Future<bool> connect(String deviceId) async {
    if (_connectOverride != null) {
      return _connectOverride!.call(deviceId);
    }
    if (kIsWeb) return false;

    try {
      final devices = await FlutterBluePlus.systemDevices([_serviceUuid]);
      final target = devices.where((d) => d.remoteId.str == deviceId).firstOrNull;
      if (target == null) {
        if (kDebugMode) debugPrint('[BLE] target not found: $deviceId');
        return false;
      }

      await disconnect();
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
        if (kDebugMode) debugPrint('[BLE] characteristic not found');
        await target.disconnect();
        return false;
      }

      _connectedDevice = target;
      _commandCharacteristic = characteristic;
      if (kDebugMode) {
        debugPrint('[BLE] connected: ${target.remoteId.str} / ${target.platformName}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[BLE] connect error: $e');
      await disconnect();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _connectedDevice?.disconnect();
    } catch (e) {
      if (kDebugMode) debugPrint('[BLE] disconnect error: $e');
    } finally {
      _connectedDevice = null;
      _commandCharacteristic = null;
    }
  }

  Future<bool> sendPress({required int x, required int y, required String deviceId}) async {
    final c = _commandCharacteristic;
    if (c == null) return false;

    final payload = jsonEncode({
      'action': 'press',
      'x': x,
      'y': y,
      'deviceId': deviceId,
    });
    try {
      await c.write(utf8.encode(payload), withoutResponse: false);
      if (kDebugMode) debugPrint('[BLE] sendPress: $payload');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[BLE] sendPress error: $e');
      return false;
    }
  }

  Future<void> sendEmergencyStop(String deviceId) async {
    final c = _commandCharacteristic;
    if (c == null) return;
    final payload = jsonEncode({'action': 'stop', 'deviceId': deviceId});
    try {
      await c.write(utf8.encode(payload), withoutResponse: false);
      if (kDebugMode) debugPrint('[BLE] sendEmergencyStop: $payload');
    } catch (e) {
      if (kDebugMode) debugPrint('[BLE] stop error: $e');
    }
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
  const BleDeviceInfo({required this.id, required this.name, required this.rssi});
  final String id;
  final String name;
  final int rssi;
}
