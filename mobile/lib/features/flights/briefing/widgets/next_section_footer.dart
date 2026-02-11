import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class NextSectionFooter extends StatelessWidget {
  final String? nextLabel;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const NextSectionFooter({
    super.key,
    this.nextLabel,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
            onPressed: onPrev,
            iconSize: 20,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: GestureDetector(
              onTap: nextLabel != null ? onNext : null,
              child: Text(
                nextLabel != null
                    ? 'NEXT: $nextLabel'
                    : 'END OF BRIEFING',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: nextLabel != null
                      ? AppColors.accent
                      : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onPressed: nextLabel != null ? onNext : null,
            iconSize: 20,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
