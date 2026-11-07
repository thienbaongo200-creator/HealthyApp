import 'package:flutter/material.dart';
import 'package:frontend/theme/app_colors.dart';

class SkyBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(AppColors.background, BlendMode.src);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: child,
    );
  }
}
