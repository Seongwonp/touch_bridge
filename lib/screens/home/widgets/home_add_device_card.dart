import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../widgets/responsive_scale.dart';
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
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * rs),
      child: Semantics(
        label: '새 기기 추가하기. 터치 브리지를 새로운 가전에 연결합니다.',
        button: true,
        child: GestureDetector(
          onTap: () async {
            HapticFeedback.mediumImpact();
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DeviceConnectScreen(),
              ),
            );
            onDeviceAdded();
          },
          child: Container(
            padding: EdgeInsets.all(28 * rs),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24 * rs),
              border: Border.all(
                color: const Color(0xFFFFEB00),
                width: 2 * rs,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100 * rs,
                      height: 100 * rs,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A1A1A),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: const Color(0xFFFFEB00),
                          size: 64 * rs,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 32)),
                    Text(
                      '새 기기 추가하기',
                      style: TextStyle(
                        fontSize: 24 * rs,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFFFEB00),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 12)),
                    Text(
                      '터치 브리지를 새로운 가전에\n연결하고 매핑을 시작합니다',
                      style: TextStyle(
                        fontSize: 14 * rs,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF888888),
                      ),
                      textAlign: TextAlign.center,
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
