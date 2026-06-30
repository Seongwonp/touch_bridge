import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/accessibility_settings.dart';
import 'services/accessibility_experiment_service.dart';
import 'services/ble_service.dart';
import 'services/active_device_service.dart';
import 'services/home_device_store.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

// TODO(demo-seed): PPT 스크린샷용 임시 데모 기기 시드 — 캡처 끝나면 반드시 제거.
const bool _seedDemoDeviceForScreenshots = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  await AccessibilitySettings.instance.load();
  await AccessibilityExperimentService.instance.load();
  await ActiveDeviceService.instance.init(); // 서비스 초기화 추가
  if (_seedDemoDeviceForScreenshots) {
    final existing = await HomeDeviceStore.loadDevices();
    if (existing.isEmpty) {
      await HomeDeviceStore.saveDevices([
        {
          'id': 'demo_microwave_01',
          'name': '전자레인지',
          'status': '작동 대기 중',
          'iconCodePoint': 63678,
          'bleId': 'DEMO-BLE-01',
          'bleName': 'TouchBridge-ESP32',
        },
      ]);
      await ActiveDeviceService.instance.setActiveDevice(
        deviceId: 'demo_microwave_01',
        deviceName: '전자레인지',
        bleId: 'DEMO-BLE-01',
        bleName: 'TouchBridge-ESP32',
      );
    }
  }
  BleService.instance.warmUp();
  runApp(const TouchBridgeApp());
}


class TouchBridgeApp extends StatelessWidget {
  const TouchBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AccessibilitySettings.instance,
      builder: (context, _) {
        final settings = AccessibilitySettings.instance;
        final textScale = settings.largeTextEnabled ? 1.18 : 1.0;

        return MaterialApp(
          title: 'Touch Bridge',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(textScale),
                boldText: settings.highContrastEnabled,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}
