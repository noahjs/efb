import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class FlightFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? valueColor;

  const FlightFieldRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.showChevron = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ??
                    (onTap != null ? AppColors.accent : AppColors.textPrimary),
              ),
            ),
            if (showChevron)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
