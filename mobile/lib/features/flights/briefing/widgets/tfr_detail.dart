import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

class TfrDetail extends StatefulWidget {
  final List<BriefingTfr> tfrs;
  final List<BriefingWaypoint> waypoints;

  const TfrDetail({
    super.key,
    required this.tfrs,
    required this.waypoints,
  });

  @override
  State<TfrDetail> createState() => _TfrDetailState();
}

class _TfrDetailState extends State<TfrDetail> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.tfrs.isEmpty) {
      return const Center(
        child: Text('No TFRs along route',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final tfr = widget.tfrs[_selectedIndex];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.block, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Temporary Flight Restriction',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // TFR selector if multiple
        if (widget.tfrs.length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.tfrs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final isSelected = idx == _selectedIndex;
                return ChoiceChip(
                  label: Text(
                    widget.tfrs[idx].notamNumber.isNotEmpty
                        ? widget.tfrs[idx].notamNumber
                        : 'TFR ${idx + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _selectedIndex = idx),
                  selectedColor: AppColors.primary.withAlpha(60),
                  backgroundColor: AppColors.surface,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        // TFR details
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tfr.notamNumber.isNotEmpty)
                Text(
                  tfr.notamNumber,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              if (tfr.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  tfr.description,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
              if (tfr.effectiveStart != null ||
                  tfr.effectiveEnd != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                    label: 'Effective',
                    value:
                        '${tfr.effectiveStart ?? '?'} - ${tfr.effectiveEnd ?? '?'}'),
              ],
              if (tfr.notamText != null && tfr.notamText!.isNotEmpty) ...[
                const Divider(color: AppColors.divider, height: 20),
                Text(
                  tfr.notamText!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
