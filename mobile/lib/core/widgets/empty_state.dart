import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Consistent empty-state placeholder used when a list or screen has no data.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppText.title),
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle, style: AppText.bodySecondary),
        ],
      ),
    );
  }
}
