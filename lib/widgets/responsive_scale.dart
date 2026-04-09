import 'package:flutter/widgets.dart';

class ResponsiveScale {
  ResponsiveScale._();

  static double factor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width / 390).clamp(0.82, 1.18);
  }

  static double v(BuildContext context, double value) {
    return value * factor(context);
  }
}
