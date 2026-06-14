import 'package:flutter/material.dart';
import '../../../widgets/responsive_scale.dart';
import '../../voice/voice_listening_screen.dart';
import '../../control/remote_control_screen.dart';
import '../../control/image_control_screen.dart';
import '../../control/course_control_screen.dart';
import '../../mapping/manual_mapping_screen.dart';
import '../../../services/device_mapping_service.dart';

class ControlModeSheet extends StatelessWidget {
  const ControlModeSheet({
    super.key,
    required this.deviceName,
    required this.deviceId,
    required this.deviceIcon,
  });

  final String deviceName;
  final String deviceId;
  final IconData deviceIcon;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28 * rs)),
        border: const Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      padding: EdgeInsets.fromLTRB(24 * rs, 16 * rs, 24 * rs, 40 * rs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40 * rs,
            height: 4 * rs,
            decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2 * rs),
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(deviceIcon, color: const Color(0xFFFFEB00), size: 32 * rs),
              SizedBox(width: 12 * rs),
              Text(
                deviceName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22 * rs,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveScale.v(context, 8)),
          Text(
            '제어 방식을 선택하세요',
            style: TextStyle(
              color: const Color(0xFF888888),
              fontSize: 14 * rs,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 24)),
          _buildActionButton(
            context: context,
            rs: rs,
            icon: Icons.mic_rounded,
            label: '음성으로 제어',
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VoiceListeningScreen(
                    deviceId: deviceId,
                    deviceName: deviceName,
                  ),
                ),
              );
            },
            isPrimary: true,
          ),
          SizedBox(height: ResponsiveScale.v(context, 12)),
          _buildActionButton(
            context: context,
            rs: rs,
            icon: Icons.image_search_rounded,
            label: '이미지로 제어 (직관적)',
            onPressed: () async {
              Navigator.of(context).pop();
              final profile = await DeviceMappingService.instance.load(deviceId);
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ImageControlScreen(
                    deviceId: deviceId,
                    deviceName: deviceName,
                    imagePath: profile.imagePath,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: ResponsiveScale.v(context, 12)),
          _buildActionButton(
            context: context,
            rs: rs,
            icon: Icons.auto_awesome_motion_rounded,
            label: '간편 코스로 제어 (자동)',
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CourseControlScreen(
                    deviceId: deviceId,
                    deviceName: deviceName,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: ResponsiveScale.v(context, 12)),
          Row(
            children: [
              Expanded(
                child: _buildSecondaryButton(
                  rs: rs,
                  icon: Icons.numbers_rounded,
                  label: '숫자 패드',
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RemoteControlScreen(deviceName: deviceName),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 12 * rs),
              Expanded(
                child: _buildSecondaryButton(
                  rs: rs,
                  icon: Icons.settings_overscan_rounded,
                  label: '좌표 매핑',
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManualMappingScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required double rs,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 64 * rs,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? const Color(0xFFFFEB00) : const Color(0xFF1A1A1A),
          foregroundColor: isPrimary ? Colors.black : const Color(0xFFFFEB00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * rs),
            side: isPrimary 
              ? BorderSide.none 
              : BorderSide(color: const Color(0xFFFFEB00), width: 1.5 * rs),
          ),
          elevation: 0,
        ),
        icon: Icon(icon, size: 24 * rs),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 18 * rs,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required double rs,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 56 * rs,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white70,
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12 * rs),
          ),
        ),
        icon: Icon(icon, size: 20 * rs),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 15 * rs,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
