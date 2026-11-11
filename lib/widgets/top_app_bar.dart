import 'package:flutter/material.dart';
import 'global_emergency_action.dart';
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
    this.showEmergency = true,
    this.onEmergency,
  });

  /// 오른쪽 위 비상 정지가 이 화면의 정지 절차를 부르게 한다([GlobalEmergencyAction.onStop]).
  final VoidCallback? onEmergency;

  final String title;
  final bool showBack;
  final List<Widget>? actions;

  /// 전역 비상 정지 버튼 노출 여부.
  ///
  /// 기본 true — 어떤 화면에서든 두 번 탭으로 즉시 중단할 수 있어야 한다.
  /// 비상 정지 자체를 다루는 화면(비상 탭·카운트다운·완료 화면)만 중복을
  /// 피해 끈다.
  final bool showEmergency;

  @override
  Size get preferredSize => const Size.fromHeight(92);

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
              actions: [
                ...?actions,
                if (showEmergency) GlobalEmergencyAction(onStop: onEmergency),
              ].map((a) => Padding(
                    padding: EdgeInsets.only(right: 8 * rs),
                    child: a,
                  )).toList(),
              centerTitle: false,
            ),
            // Status Header — 스크린리더용 통합 레이블으로 연결/기기 상태를 한 번에 읽는다.
            // 연결·기기 선택이 바뀌면 다시 그린다. 한 번만 읽으면 재연결 뒤에도
            // "허브 연결 필요"로 남아 낭독기 사용자에게 틀린 상태를 알린다.
            // 앱바 높이가 고정이라 시스템 글자 확대는 1.4배까지 따른다(낭독은 영향 없음).
            // 연결 상태를 더 크게 읽어야 하는 사용자를 위해 홈의 연결 배너는 제한 없이 커진다.
            StreamBuilder<bool>(
              stream: BleService.instance.isConnectedStream,
              builder: (context, _) => ValueListenableBuilder<String?>(
                valueListenable:
                    ActiveDeviceService.instance.activeDeviceNameNotifier,
                builder: (context, _, _) => MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.4,
                  child: _buildStatusHeader(rs),
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

  Widget _buildStatusHeader(double rs) {
    final connected = BleService.instance.isConnected;
    final hubText =
        connected ? BleService.instance.connectedDeviceName : '연결 안 됨';
    final deviceName = ActiveDeviceService.instance.getActiveDeviceName();
    return Semantics(
      label: [
        connected ? 'Touch Bridge 연결됨: $hubText' : 'Touch Bridge 연결 안 됨',
        '선택 기기: ${deviceName ?? '없음'}',
      ].join(', '),
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16 * rs),
          child: Row(
            children: [
              Icon(
                connected ? Icons.hub : Icons.hub_outlined,
                color: connected ? Colors.greenAccent : Colors.redAccent,
                size: 13 * rs,
              ),
              SizedBox(width: 4 * rs),
              // FittedBox로 줄이면 시스템 글자 크기 확대가 무시된다. 넘치면 말줄임으로 자른다.
              Flexible(
                child: Text(
                  hubText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13 * rs, color: Colors.white),
                ),
              ),
              SizedBox(width: 12 * rs),
              Icon(Icons.kitchen, color: Colors.blueAccent, size: 13 * rs),
              SizedBox(width: 4 * rs),
              Flexible(
                child: Text(
                  deviceName ?? '기기 선택 필요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13 * rs, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
