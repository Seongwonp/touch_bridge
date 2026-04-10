import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'screens/home/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TouchBridgeApp());
}

class TouchBridgeApp extends StatelessWidget {
  const TouchBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Touch Bridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      home: const HomeScreen(),
    );
  }
}
