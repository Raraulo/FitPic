import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ErrorStrip extends StatelessWidget {
  const ErrorStrip({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD6D6))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFB33A45), size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.35, color: AppTheme.ink))),
        ]),
      );
}
