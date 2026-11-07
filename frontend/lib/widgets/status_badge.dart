import 'package:flutter/material.dart';
import 'package:frontend/theme/app_colors.dart';

enum StatusTone { success, warning, danger, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  Color get _color => switch (tone) {
    StatusTone.success => AppColors.success,
    StatusTone.warning => AppColors.warning,
    StatusTone.danger => AppColors.danger,
    StatusTone.neutral => AppColors.primary,
  };

  Color get _background => switch (tone) {
    StatusTone.success => AppColors.successSoft,
    StatusTone.warning => AppColors.warningSoft,
    StatusTone.danger => AppColors.dangerSoft,
    StatusTone.neutral => AppColors.primarySoft,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: _color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
