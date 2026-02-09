import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/theme/app_theme.dart';

/// Shared bottom-sheet detail panel for tapped map features.
/// Used by both advisory and TFR viewers.
class FeatureDetailPanel extends StatelessWidget {
  final List<Map<String, dynamic>> features;
  final String label;
  final String labelPlural;
  final Widget Function(Map<String, dynamic> properties) itemBuilder;
  final VoidCallback onClose;

  const FeatureDetailPanel({
    super.key,
    required this.features,
    required this.label,
    required this.labelPlural,
    required this.itemBuilder,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    Text(
                      '${features.length} ${features.length == 1 ? label : labelPlural} at this location',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: AppColors.textMuted),
                      onPressed: onClose,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: features.length,
                  separatorBuilder: (_, _) => const Divider(
                    color: AppColors.surfaceLight,
                    height: 16,
                  ),
                  itemBuilder: (_, index) => itemBuilder(features[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared info badge widget for feature detail items.
Widget infoBadge(IconData icon, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}
