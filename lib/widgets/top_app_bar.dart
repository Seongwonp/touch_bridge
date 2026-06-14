import 'package:flutter/material.dart';
import 'responsive_scale.dart';

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
  Size get preferredSize => const Size.fromHeight(64);

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
      child: AppBar(
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
    );
  }
}
