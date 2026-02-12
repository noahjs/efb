import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

class AdvisoryDetail extends StatefulWidget {
  final String title;
  final List<BriefingAdvisory> advisories;
  final List<BriefingWaypoint> waypoints;
  final int? cruiseAltitude;

  const AdvisoryDetail({
    super.key,
    required this.title,
    required this.advisories,
    required this.waypoints,
    this.cruiseAltitude,
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
        // Context banner
        if (advisory.affectedSegment != null ||
            advisory.altitudeRelation != null)
          _ContextBanner(
            advisory: advisory,
            cruiseAltitude: widget.cruiseAltitude,
          ),
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

class _ContextBanner extends StatelessWidget {
  final BriefingAdvisory advisory;
  final int? cruiseAltitude;

  const _ContextBanner({required this.advisory, this.cruiseAltitude});

  @override
  Widget build(BuildContext context) {
    final isWithin = advisory.altitudeRelation == 'within';
    final bannerColor =
        isWithin ? AppColors.error.withAlpha(30) : AppColors.warning.withAlpha(20);
    final borderColor =
        isWithin ? AppColors.error : AppColors.warning;
    final textColor = isWithin ? AppColors.error : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (advisory.affectedSegment != null) ...[
            Row(
              children: [
                Icon(Icons.route, size: 14, color: textColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Affects your route between ${advisory.affectedSegment!.fromWaypoint} and ${advisory.affectedSegment!.toWaypoint} (${advisory.affectedSegment!.fromDistNm.round()}nm - ${advisory.affectedSegment!.toDistNm.round()}nm)',
                    style: TextStyle(color: textColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (advisory.altitudeRelation != null && cruiseAltitude != null) ...[
            if (advisory.affectedSegment != null)
              const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isWithin ? Icons.warning_amber : Icons.check_circle_outline,
                  size: 14,
                  color: isWithin ? AppColors.error : AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _altitudeText(),
                    style: TextStyle(
                      color: isWithin ? AppColors.error : AppColors.success,
                      fontSize: 12,
                      fontWeight: isWithin ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _altitudeText() {
    final altStr = cruiseAltitude != null
        ? (cruiseAltitude! >= 18000
            ? 'FL${cruiseAltitude! ~/ 100}'
            : "$cruiseAltitude'")
        : '';
    final base = advisory.base ?? 'SFC';
    final top = advisory.top ?? '?';
    final relation = (advisory.altitudeRelation ?? '').toUpperCase();
    return 'Your altitude $altStr is $relation $base-$top';
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
