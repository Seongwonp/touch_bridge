import 'package:flutter/material.dart';

class ButtonMarker extends StatelessWidget {
  final int index;
  final String label;
  final double rs;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ButtonMarker({
    super.key,
    required this.index,
    required this.label,
    required this.rs,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(children: [
        Container(
          width: 40 * rs,
          height: 40 * rs,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEB00).withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2 * rs),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8 * rs)],
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18 * rs),
            ),
          ),
        ),
        SizedBox(height: 4 * rs),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * rs, vertical: 2 * rs),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4 * rs),
          ),
          child: Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 10 * rs),
          ),
        ),
      ]),
    );
  }
}
