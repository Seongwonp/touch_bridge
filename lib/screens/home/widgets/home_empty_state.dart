import 'package:flutter/material.dart';
import '../../../widgets/responsive_scale.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    
    return Container(
      padding: EdgeInsets.all(ResponsiveScale.v(context, 16)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20 * rs),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '초기 설정 안내',
            style: TextStyle(
              color: const Color(0xFFFFEB00),
              fontSize: 16 * rs,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 10)),
          Text(
            '1. 연결 탭에서 기기를 등록하세요\n2. 홈에서 기기를 선택하세요\n3. 음성 탭에서 "만두 데워줘"처럼 말씀하세요',
            style: TextStyle(
              color: const Color(0xFFD1D5DB),
              fontSize: 14 * rs,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
