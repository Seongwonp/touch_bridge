import 'package:flutter/widgets.dart';

class ResponsiveScale {
  ResponsiveScale._();

  static double factor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Baseline: 375 x 812 (iPhone 13 mini / typical mid-range)
    final widthFactor = size.width / 375;
    final heightFactor = size.height / 812;
    
    // Use the smaller factor to ensure content fits, 
    // but allow for more flexible scaling (0.85 to 1.4)
    return (widthFactor < heightFactor ? widthFactor : heightFactor).clamp(
      0.8,
      1.4,
    );
  }

  static double v(BuildContext context, double value) {
    return value * factor(context);
  }

  /// Horizontal padding helper
  static double h(BuildContext context, double value) {
    return value * factor(context);
  }
}
