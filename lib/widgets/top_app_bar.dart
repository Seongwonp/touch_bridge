import 'package:flutter/material.dart';
import 'responsive_scale.dart';
import '../services/active_device_service.dart';
import '../services/ble_service.dart';
import '../theme/app_colors.dart';

class TopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TopAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions,
  });

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(86);

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    
    return Container(
      decoration: const BoxDecoration(color: AppColors.background),
      child: SafeArea(
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: showBack
                ? IconButton(
                    tooltip: '뒤로 가기',
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 22 * rs, color: AppColors.primary),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
              title: Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20 * rs,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
              actions: actions?.map((a) => Padding(
                    padding: EdgeInsets.only(right: 8 * rs),
                    child: a,
                  )).toList(),
              centerTitle: false,
            ),
            // Status Header — 스크린리더용 통합 레이블으로 연결/기기 상태를 한 번에 읽는다.
            Semantics(
              label: [
                BleService.instance.isConnected
                    ? '허브 연결됨: ${BleService.instance.connectedDeviceName}'
                    : '허브 연결 필요',
                '선택 기기: ${ActiveDeviceService.instance.getActiveDeviceName() ?? '없음'}',
              ].join(', '),
              child: ExcludeSemantics(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * rs),
                  child: Row(
                    children: [
                      Icon(
                        BleService.instance.isConnected ? Icons.hub : Icons.hub_outlined,
                        color: BleService.instance.isConnected ? Colors.greenAccent : Colors.redAccent,
                        size: 13 * rs,
                      ),
                      SizedBox(width: 4 * rs),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            BleService.instance.isConnected ? BleService.instance.connectedDeviceName : '허브 연결 필요',
                            style: TextStyle(fontSize: 11 * rs, color: Colors.white70),
                          ),
                        ),
                      ),
                      SizedBox(width: 12 * rs),
                      Icon(Icons.kitchen, color: Colors.blueAccent, size: 13 * rs),
                      SizedBox(width: 4 * rs),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            ActiveDeviceService.instance.getActiveDeviceName() ?? '기기 선택 필요',
                            style: TextStyle(fontSize: 11 * rs, color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.accentLineGradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
