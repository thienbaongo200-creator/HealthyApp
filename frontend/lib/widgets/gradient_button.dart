import 'package:flutter/material.dart';
import 'package:frontend/widgets/primary_button.dart';

/// Nút gradient bo tròn hình capsule, có hiệu ứng đổ bóng
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final List<Color>? gradientColors;
  final Color? textColor;
  final double fontSize;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.height = 52,
    this.gradientColors,
    this.textColor,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      isLoading: isLoading,
      height: height,
      fontSize: fontSize,
      foregroundColor: textColor,
    );
  }
}
