import 'package:flutter/material.dart';
import '../../../widgets/responsive_scale.dart';

class HomeDeviceCard extends StatelessWidget {
  const HomeDeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
  });

  final Map<String, dynamic> device;
  final VoidCallback onTap;
  final Function(LongPressStartDetails) onLongPressStart;
  final Function(LongPressEndDetails) onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * rs),
      child: Semantics(
        label:
            '${device['name']}. 현재 상태 ${device['status']}. 선택하려면 두 번 누르세요. 삭제하려면 5초간 길게 누르세요.',
        button: true,
        child: GestureDetector(
          onTap: onTap,
          onLongPressStart: onLongPressStart,
          onLongPressEnd: onLongPressEnd,
          onLongPressCancel: () => onLongPressEnd(LongPressEndDetails()),
          child: Container(
            padding: EdgeInsets.all(28 * rs),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24 * rs),
              border: Border.all(
                color: const Color(0xFF2A2A2A),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 120 * rs,
                      height: 120 * rs,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(24 * rs),
                        border: Border.all(
                          color: const Color(0xFF333333),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          IconData(
                            device['iconCodePoint'] as int,
                            fontFamily: 'MaterialIcons',
                          ),
                          color: const Color(0xFFFFEB00),
                          size: 56 * rs,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 24)),
                    Text(
                      device['name'] as String,
                      style: TextStyle(
                        fontSize: 26 * rs,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 10)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8 * rs,
                          height: 8 * rs,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00FF88),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8 * rs),
                        Text(
                          device['status'] as String,
                          style: TextStyle(
                            fontSize: 15 * rs,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFAAAAAA),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 28)),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14 * rs),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEB00),
                        borderRadius: BorderRadius.circular(12 * rs),
                      ),
                      child: Text(
                        '눌러서 제어하기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15 * rs,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
