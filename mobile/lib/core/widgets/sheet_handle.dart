import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standard drag-handle for bottom sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.textMuted,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
