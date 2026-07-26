import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

class LinearLoader extends StatelessWidget {
  const LinearLoader({super.key, this.visible = true});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox(height: 2);
    return const LinearProgressIndicator(
      minHeight: 2,
      color: AppTheme.darkBrown,
      backgroundColor: AppTheme.line,
    ).animate(onPlay: (controller) => controller.repeat()).fadeIn(duration: 180.ms);
  }
}
