import 'package:flutter/material.dart';
import 'responsive_scale.dart';
import '../services/active_device_service.dart';
import '../services/ble_service.dart';

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
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: showBack 
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 22 * rs, color: const Color(0xFFFFEB00)),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 20 * rs,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: const Color(0xFFFFEB00),
                ),
              ),
              actions: actions?.map((a) => Padding(
                    padding: EdgeInsets.only(right: 8 * rs),
                    child: a,
                  )).toList(),
              centerTitle: false,
            ),
            // Status Header
            Padding(
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
          ],
        ),
      ),
    );
  }
}
