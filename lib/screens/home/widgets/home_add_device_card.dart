import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../widgets/responsive_scale.dart';
import '../../../theme/app_colors.dart';
import '../../connection/device_connect_screen.dart';

class HomeAddDeviceCard extends StatelessWidget {
  const HomeAddDeviceCard({
    super.key,
    required this.onDeviceAdded,
  });

  final VoidCallback onDeviceAdded;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    Future<void> handleTap() async {
      HapticFeedback.mediumImpact();
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DeviceConnectScreen()),
      );
      onDeviceAdded();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * rs),
      child: Semantics(
        label: '새 기기 추가하기. 터치 브리지를 새로운 가전에 연결합니다.',
        button: true,
        onTap: handleTap,
        child: ExcludeSemantics(
          child: GestureDetector(
          onTap: handleTap,
          child: Container(
            padding: EdgeInsets.all(28 * rs),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(24 * rs),
              border: Border.all(
                color: AppColors.primary,
                width: 2 * rs,
              ),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowPrimary, blurRadius: 16),
              ],
            ),
            // 남는 높이에 맞춰 아이콘을 줄이고, 아주 낮으면 숨겨 글자가 잘리지 않게 한다
            // (Galaxy A31에서 "새 기기 추가하기"가 카드 아래로 잘렸다).
            child: LayoutBuilder(
              builder: (context, box) {
                // 글자를 1.3배보다 키웠으면 장식 아이콘보다 글자에 높이를 준다.
                final bigText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final iconBox = bigText || box.maxHeight < 240
                    ? 0.0
                    : (box.maxHeight * 0.28).clamp(56.0, 100 * rs);
                return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (iconBox > 0) ...[
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.primaryGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.black,
                          size: iconBox * 0.64,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 20)),
                    ],
                    Text(
                      '새 기기 추가하기',
                      style: TextStyle(
                        fontSize: 24 * rs,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 12)),
                    Text(
                      '터치 브리지를 새로운 가전에\n연결하고 매핑을 시작합니다',
                      style: TextStyle(
                        fontSize: 14 * rs,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
                );
              },
            ),
          ),
          ),  // ExcludeSemantics
        ),
      ),
    );
  }
}
