import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'sheet_actions.dart' as actions;

class FixBottomSheet extends ConsumerWidget {
  final String fixId;
  final Map<String, dynamic>? fixData;

  const FixBottomSheet({
    super.key,
    required this.fixId,
    this.fixData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.15,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.15, 0.38, 0.55],
      builder: (context, scrollController) {
        return Container(
          color: AppColors.surface,
          child: _FixSheetContent(
            fixId: fixId,
            fixData: fixData,
            scrollController: scrollController,
            ref: ref,
          ),
        );
      },
    );
  }
}

class _FixSheetContent extends StatelessWidget {
  final String fixId;
  final Map<String, dynamic>? fixData;
  final ScrollController scrollController;
  final WidgetRef ref;

  const _FixSheetContent({
    required this.fixId,
    this.fixData,
    required this.scrollController,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final identifier = fixData?['identifier'] ?? fixId;
    final lat = fixData?['latitude'] as num?;
    final lng = fixData?['longitude'] as num?;
    final coordStr = _formatCoordinates(lat?.toDouble(), lng?.toDouble());

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        // Header bar
        Container(
          color: AppColors.toolbarBackground,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Close',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text(
                  identifier,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 56),
            ],
          ),
        ),

        // Action buttons row
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _ActionButton(
                label: 'Direct To',
                onTap: () => actions.directTo(context, ref, identifier),
              ),
              _ActionButton(
                label: 'Add to Route',
                onTap: () => actions.addToRoute(context, ref, identifier),
              ),
              _ActionButton(
                label: 'Hold...',
                onTap: () => actions.showComingSoon(context, 'Hold patterns'),
              ),
              _ActionButton(
                label: 'Wx Forecast',
                onTap: () => actions.showComingSoon(context, 'Wx Forecast'),
              ),
            ],
          ),
        ),

        // Waypoint Information section
        _SectionHeader(title: 'WAYPOINT INFORMATION'),
        _InfoRow(label: 'Name', value: identifier, valueColor: AppColors.accent),
        const Divider(height: 0.5, color: AppColors.divider),
        _InfoRow(
          label: 'Navaid Type',
          value: 'Named Intersection',
          valueColor: AppColors.accent,
        ),

        // Location Information section
        _SectionHeader(title: 'LOCATION INFORMATION'),
        _InfoRow(
          label: 'Coordinates',
          value: coordStr,
          valueColor: AppColors.accent,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  String _formatCoordinates(double? lat, double? lng) {
    if (lat == null || lng == null) return '---';
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    final latStr = lat.abs().toStringAsFixed(2);
    final lngStr = lng.abs().toStringAsFixed(2);
    return '$latStr\u00B0$latDir/$lngStr\u00B0$lngDir';
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceLight,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                color: valueColor ?? AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
