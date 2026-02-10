import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/approach_chart.dart';

class ApproachLegsTable extends StatelessWidget {
  final ApproachChartData chart;

  const ApproachLegsTable({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    final legs = chart.legs
        .where((l) => l.fixIdentifier != null && l.fixIdentifier!.isNotEmpty)
        .toList();

    if (legs.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'APPROACH FIXES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            // Header row
            Row(
              children: const [
                SizedBox(width: 60, child: _HeaderCell('FIX')),
                SizedBox(width: 48, child: _HeaderCell('ROLE')),
                Expanded(child: _HeaderCell('CRS')),
                Expanded(child: _HeaderCell('DIST')),
                Expanded(child: _HeaderCell('ALT')),
              ],
            ),
            const Divider(height: 8),
            // Data rows
            ...legs.map((leg) => _LegRow(leg: leg)),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;

  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  final ApproachLeg leg;

  const _LegRow({required this.leg});

  @override
  Widget build(BuildContext context) {
    final isMissed = leg.isMissedApproach;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              leg.fixIdentifier ?? '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isMissed
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: leg.roleLabel != null
                ? _RoleBadge(role: leg.roleLabel!)
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: Text(
              leg.magneticCourse != null
                  ? '${leg.magneticCourse!.round()}°'
                  : '',
              style: _valueStyle(isMissed),
            ),
          ),
          Expanded(
            child: Text(
              leg.distanceNm != null
                  ? '${leg.distanceNm!.toStringAsFixed(1)} NM'
                  : '',
              style: _valueStyle(isMissed),
            ),
          ),
          Expanded(
            child: Text(
              leg.altitudeDisplay,
              style: _valueStyle(isMissed),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _valueStyle(bool muted) {
    return TextStyle(
      fontSize: 12,
      color: muted ? AppColors.textSecondary : AppColors.textPrimary,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      'FAF' => AppColors.warning,
      'MAP' => AppColors.error,
      'IAF' => AppColors.accent,
      'IF' => AppColors.info,
      _ => AppColors.textMuted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
