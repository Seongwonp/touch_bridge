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
                maxLines: 2,
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
                  // 앱 테마의 버튼 최소 폭이 화면 전체라, 글자와 한 줄에 두면 레이아웃 오류로
                  // release에서 줄 전체가 사라졌다(부스 실기 2026-11-18). 폭을 내용에 맞춘다.
                  minimumSize: Size(0, 44 * rs),
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
