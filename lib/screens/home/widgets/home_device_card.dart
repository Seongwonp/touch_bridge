import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../../../widgets/responsive_scale.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_icons.dart';

class HomeDeviceCard extends StatelessWidget {
  // 스크린리더 커스텀 액션은 재빌드마다 새로 만들지 않도록 한 번만 생성한다.
  static final CustomSemanticsAction _voiceAction = CustomSemanticsAction(
    label: '음성 명령 시작',
  );

  const HomeDeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    this.onVoiceControl,
  });

  final Map<String, dynamic> device;
  final VoidCallback onTap;
  /// 스크린리더 접근성: TalkBack 액션 메뉴로 음성 명령을 바로 시작.
  /// 기기 관리·삭제는 홈이 아니라 설정의 보호자 설정에서 한다.
  final VoidCallback? onVoiceControl;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * rs),
      child: Semantics(
        // 낭독기가 "두 번 탭하여 활성화"를 스스로 붙이므로 조작법은 반복하지 않는다.
        label: '${device['name']}, ${device['status']}',
        hint: '조작 방법을 엽니다',
        button: true,
        // onTap을 Semantics에 직접 등록 — ExcludeSemantics가 하위 Tree를
        // 가리기 때문에 GestureDetector의 탭이 Semantics로 올라오지 않는다.
        onTap: onTap,
        customSemanticsActions: {
          _voiceAction: ?onVoiceControl,
        },
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: EdgeInsets.all(22 * rs),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(24 * rs),
                border: Border.all(color: AppColors.borderDefault),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowSecondaryGlow,
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              // 카드 높이는 화면·글자 크기에 따라 크게 달라진다. 장식 아이콘을 남는
              // 높이에 맞춰 줄이고, 아주 낮으면 숨겨 이름·상태 글자가 잘리지 않게 한다.
              child: LayoutBuilder(
                builder: (context, box) {
                  // 글자를 1.3배보다 키웠으면 장식 아이콘보다 글자에 높이를 준다.
                  final bigText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
                  final iconBox = bigText || box.maxHeight < 260
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
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.primaryGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24 * rs),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowPrimary,
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            iconFromCodePoint(device['iconCodePoint']),
                            color: Colors.black,
                            size: iconBox * 0.48,
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveScale.v(context, 16)),
                      ],
                      Text(
                        device['name'] as String,
                        style: TextStyle(
                          fontSize: 26 * rs,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
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
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8 * rs),
                          Flexible(
                            child: Text(
                            device['status'] as String,
                            style: TextStyle(
                              fontSize: 15 * rs,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveScale.v(context, 18)),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 14 * rs),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.primaryGradient,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
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
                  );
                },
              ),
            ),
          ), // ExcludeSemantics
        ),
      ),
    );
  }
}
