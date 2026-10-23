import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LinearLoader extends StatelessWidget {
  const LinearLoader({super.key, this.visible = true, this.label});
  final bool visible;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
          color: AppTheme.accentSoft, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2.2, color: AppTheme.accent)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label ?? 'Trabajando para ti…',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink))),
      ]),
    );
  }
}
