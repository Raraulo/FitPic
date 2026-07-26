import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ErrorStrip extends StatelessWidget {
  const ErrorStrip({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: AppTheme.mediumBrown)),
      child: Text(message, style: const TextStyle(fontSize: 12)),
    );
  }
}
