import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/accessibility_settings.dart';
import 'services/accessibility_experiment_service.dart';
import 'services/ble_service.dart';
import 'services/active_device_service.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  await AccessibilitySettings.instance.load();
  await AccessibilityExperimentService.instance.load();
  await ActiveDeviceService.instance.init(); // 서비스 초기화 추가
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
        // 앱 "큰 글씨"는 시스템 글자 확대(접근성 설정)를 덮어쓰지 않고
        // 최소 배율(하한)로만 사용한다. 저시력 사용자의 200% 확대를 잃지 않게 함.
        final appMinScale = settings.largeTextEnabled ? 1.18 : 1.0;

        return MaterialApp(
          title: 'Touch Bridge',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                // 시스템 글자 확대를 보존하되, 앱 "큰 글씨"를 하한으로 적용하고
                // 레이아웃 보호를 위해 2.0배를 상한으로 둔다.
                textScaler: media.textScaler.clamp(
                  minScaleFactor: appMinScale,
                  maxScaleFactor: 2.0,
                ),
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
