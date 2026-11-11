import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/accessibility_settings.dart';
import 'services/accessibility_experiment_service.dart';
import 'services/ble_service.dart';
import 'services/active_device_service.dart';
import 'services/app_lifecycle_service.dart';
import 'services/demo_seed.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 화면으로 고정한다. 화면을 볼 수 없는 사용자는 폰이 돌아간 것을 모르고,
  // 가로가 되면 낭독 순서와 버튼 자리가 바뀐다. 가로 홈 화면은 말하기 버튼이 잘렸다(실기).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  await AccessibilitySettings.instance.load();
  await AccessibilityExperimentService.instance.load();
  await ActiveDeviceService.instance.init();
  await DemoSeed.seed();
  BleService.instance.warmUp();
  // 활성 기기를 읽은 뒤에 붙인다. 실행·복귀 재연결, 화면 켜짐, 백엔드 깨우기를 맡는다.
  AppLifecycleService.instance.start();
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
