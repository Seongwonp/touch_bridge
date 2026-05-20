import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/accessibility_settings.dart';
import 'services/accessibility_experiment_service.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  await AccessibilitySettings.instance.load();
  await AccessibilityExperimentService.instance.load();
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
