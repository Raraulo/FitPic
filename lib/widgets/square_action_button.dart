import 'package:flutter/material.dart';

class SquareActionButton extends StatelessWidget {
  const SquareActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    return SizedBox(
      height: 52,
      width: double.infinity,
      child: primary
          ? ElevatedButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}
