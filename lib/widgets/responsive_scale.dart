import 'package:flutter/widgets.dart';

class ResponsiveScale {
  ResponsiveScale._();

  static double factor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Galaxy S20 logical size baseline: 360 x 800.
    final widthFactor = size.width / 360;
    final heightFactor = size.height / 800;
    return (widthFactor < heightFactor ? widthFactor : heightFactor).clamp(
      0.9,
      1.15,
    );
  }

  static double v(BuildContext context, double value) {
    return value * factor(context);
  }
}
