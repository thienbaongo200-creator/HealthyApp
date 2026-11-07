import 'package:flutter/material.dart';
import 'package:frontend/theme/app_colors.dart';

class MainNavigationWrapper extends StatelessWidget {
  const MainNavigationWrapper({
    required this.selectedIndex,
    required this.onSelected,
    required this.onQuickAdd,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onQuickAdd;

  static const _items = <(IconData, String)>[
    (Icons.home_rounded, 'Trang chủ'),
    (Icons.menu_book_rounded, 'Nhật ký'),
    (Icons.chat_bubble_outline_rounded, 'Tư vấn'),
    (Icons.watch_outlined, 'Thiết bị'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: _NavigationItem(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
            Expanded(child: _QuickAddNavigationItem(onTap: onQuickAdd)),
            for (var i = 2; i < _items.length; i++)
              Expanded(
                child: _NavigationItem(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddNavigationItem extends StatelessWidget {
  const _QuickAddNavigationItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: IconButton.filled(
      onPressed: onTap,
      tooltip: 'Thêm chỉ số',
      icon: const Icon(Icons.add_rounded),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
      ),
    ),
  );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.12 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(label, maxLines: 1),
          ),
        ],
      ),
    );
  }
}
