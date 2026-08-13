import 'package:flutter/widgets.dart';

class ResponsiveScale {
  ResponsiveScale._();

  static double factor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Baseline: 375 x 812 (iPhone 13 mini / typical mid-range)
    final widthFactor = size.width / 375;
    final heightFactor = size.height / 812;

    // Use the smaller factor to ensure content fits, but allow flexible scaling.
    // NOTE(접근성 후속): 이 factor는 텍스트 크기에도 곱해져 작은 화면에서 글자가 축소된다.
    // 저시력 대응의 정석은 텍스트 스케일과 레이아웃 스케일을 분리하는 것(별도 리팩터).
    // 현재는 시스템 글자 확대(main.dart textScaler)로 텍스트 크기를 우선 보장한다.
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
