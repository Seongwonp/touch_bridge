import 'dart:async';

import 'package:flutter/material.dart';

abstract class DeviceService {
  ValueNotifier<bool> get isConnected;
  ValueNotifier<bool> get isOperating;
  ValueNotifier<bool> get isStalled;

  Future<bool> connect(String deviceId);
  Future<void> disconnect();
  Future<void> sendMotorCommand({required int sensitivity, required int speed});
  Future<void> saveMappingData(List<Offset> relativePoints);
  void resetStall();
}

class MockDeviceService implements DeviceService {
  @override
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  @override
  final ValueNotifier<bool> isOperating = ValueNotifier<bool>(false);
  @override
  final ValueNotifier<bool> isStalled = ValueNotifier<bool>(false);

  final double physicalWidthMm = 100.0;
  final double physicalHeightMm = 100.0;

  @override
  Future<bool> connect(String deviceId) async {
    debugPrint('MockDeviceService: connect($deviceId)');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    isConnected.value = true;
    return true;
  }

  @override
  Future<void> disconnect() async {
    isConnected.value = false;
  }

  @override
  void resetStall() {
    isStalled.value = false;
  }

  @override
  Future<void> saveMappingData(List<Offset> relativePoints) async {
    if (!isConnected.value) return;

    debugPrint('MockDeviceService: mapping points=${relativePoints.length}');
    for (var i = 0; i < relativePoints.length; i++) {
      final point = relativePoints[i];
      final realX = point.dx * physicalWidthMm;
      final realY = point.dy * physicalHeightMm;
      debugPrint(
        'MockDeviceService: SET_POS id=${i + 1} x=${realX.toStringAsFixed(1)} y=${realY.toStringAsFixed(1)}',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> sendMotorCommand({
    required int sensitivity,
    required int speed,
  }) async {
    isOperating.value = true;
    isStalled.value = false;
    debugPrint('MockDeviceService: ST sen=$sensitivity spd=$speed');

    await Future<void>.delayed(const Duration(seconds: 1));
    if (sensitivity >= 90) {
      isStalled.value = true;
      isOperating.value = false;
      return;
    }

    await Future<void>.delayed(const Duration(seconds: 1));
    isOperating.value = false;
  }
}
