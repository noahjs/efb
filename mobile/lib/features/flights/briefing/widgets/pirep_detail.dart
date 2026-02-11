import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

class PirepDetail extends StatelessWidget {
  final String title;
  final List<BriefingPirep> pireps;
  final List<BriefingWaypoint> waypoints;

  const PirepDetail({
    super.key,
    required this.title,
    required this.pireps,
    required this.waypoints,
  });

  @override
  Widget build(BuildContext context) {
    if (pireps.isEmpty) {
      return Center(
        child: Text('No $title',
            style: const TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        for (final pirep in pireps) _PirepCard(pirep: pirep),
      ],
    );
  }
}

class _PirepCard extends StatelessWidget {
  final BriefingPirep pirep;

  const _PirepCard({required this.pirep});

  @override
  Widget build(BuildContext context) {
    final isUrgent = pirep.urgency == 'UUA';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: isUrgent
            ? Border.all(color: AppColors.error.withAlpha(100), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? AppColors.error.withAlpha(40)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  pirep.urgency,
                  style: TextStyle(
                    color: isUrgent ? AppColors.error : AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (pirep.aircraftType != null)
                Text(
                  pirep.aircraftType!,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              const Spacer(),
              if (pirep.time != null)
                Text(
                  pirep.time!,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Translated fields
          if (pirep.location != null)
            _FieldRow(label: 'Location', value: pirep.location!),
          if (pirep.altitude != null)
            _FieldRow(label: 'Altitude', value: 'FL${pirep.altitude}'),
          if (pirep.turbulence != null)
            _FieldRow(label: 'Turbulence', value: pirep.turbulence!),
          if (pirep.icing != null)
            _FieldRow(label: 'Icing', value: pirep.icing!),
          const SizedBox(height: 6),
          Text(
            pirep.raw,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;

  const _FieldRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
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
