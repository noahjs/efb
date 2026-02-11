import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

class AdvisoryDetail extends StatefulWidget {
  final String title;
  final List<BriefingAdvisory> advisories;
  final List<BriefingWaypoint> waypoints;

  const AdvisoryDetail({
    super.key,
    required this.title,
    required this.advisories,
    required this.waypoints,
  });

  @override
  State<AdvisoryDetail> createState() => _AdvisoryDetailState();
}

class _AdvisoryDetailState extends State<AdvisoryDetail> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.advisories.isEmpty) {
      return Center(
        child: Text('No ${widget.title}',
            style: const TextStyle(color: AppColors.textMuted)),
      );
    }

    final advisory = widget.advisories[_selectedIndex];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // Advisory selector
        if (widget.advisories.length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.advisories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final isSelected = idx == _selectedIndex;
                return ChoiceChip(
                  label: Text(
                    '${widget.advisories[idx].hazardType} ${idx + 1}',
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
        // Advisory details
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                advisory.hazardType,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (advisory.validStart != null || advisory.validEnd != null)
                _InfoRow(
                  label: 'Valid',
                  value:
                      '${advisory.validStart ?? '?'} - ${advisory.validEnd ?? '?'}',
                ),
              if (advisory.severity != null)
                _InfoRow(label: 'Severity', value: advisory.severity!),
              if (advisory.top != null)
                _InfoRow(label: 'Top', value: advisory.top!),
              if (advisory.base != null)
                _InfoRow(label: 'Base', value: advisory.base!),
              if (advisory.dueTo != null)
                _InfoRow(label: 'Due to', value: advisory.dueTo!),
              if (advisory.rawText.isNotEmpty) ...[
                const Divider(color: AppColors.divider, height: 20),
                Text(
                  advisory.rawText,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
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
      ),
    );
  }
}
