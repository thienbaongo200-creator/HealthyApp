import 'package:flutter/material.dart';
import 'package:frontend/widgets/app_card.dart';

/// Backward-compatible card surface; glass effects are no longer applied.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 20,
    this.blur = 10,
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0xFFE7EFED),
    this.borderWidth = .5,
    this.shadowColor = const Color(0x1F244842),
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final Color shadowColor;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      width: width,
      height: height,
      margin: margin,
      borderRadius: borderRadius,
      padding: padding,
      child: child,
    );
  }
}
