import 'package:flutter/material.dart';
import '../../../widgets/responsive_scale.dart';
import '../../../services/ai_backend_service.dart';

class MappingHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isAiAnalyzing;
  final bool hasImage;
  final VoidCallback onAiAnalyze;
  final double rs;

  const MappingHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isAiAnalyzing,
    required this.hasImage,
    required this.onAiAnalyze,
    required this.rs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13 * rs,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE2C62D),
          ),
        ),
        SizedBox(height: ResponsiveScale.v(context, 4)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 24 * rs,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasImage && AiBackendService.instance.isConfigured)
              ElevatedButton(
                onPressed: isAiAnalyzing ? null : onAiAnalyze,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  side: const BorderSide(color: Color(0xFFFFEB00)),
                  padding: EdgeInsets.symmetric(horizontal: 12 * rs),
                ),
                child: isAiAnalyzing
                    ? SizedBox(
                        width: 14 * rs,
                        height: 14 * rs,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFFEB00),
                        ),
                      )
                    : Text(
                        'AI 분석하기',
                        style: TextStyle(color: Colors.white, fontSize: 12 * rs),
                      ),
              ),
          ],
        ),
      ],
    );
  }
}
