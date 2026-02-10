import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/cifp_providers.dart';
import '../widgets/briefing_strip_card.dart';
import '../widgets/approach_legs_table.dart';
import '../widgets/profile_view_painter.dart';
import '../widgets/map_view_painter.dart';
import '../widgets/minimums_card.dart';
import '../widgets/speed_time_table.dart';

class ApproachChartScreen extends ConsumerWidget {
  final String airportId;
  final int approachId;

  const ApproachChartScreen({
    super.key,
    required this.airportId,
    required this.approachId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartAsync = ref.watch(approachChartDataProvider(
      (airportId: airportId, approachId: approachId),
    ));

    return Scaffold(
      appBar: AppBar(
        title: chartAsync.whenOrNull(
              data: (chart) => Text(chart.approach.procedureName),
            ) ??
            Text('$airportId Approach'),
      ),
      body: chartAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load chart data:\n$err',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (chart) {
          final procedureName = chart.approach.procedureName;
          final rwy = chart.approach.runwayIdentifier;

          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      procedureName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        chart.approach.airportIdentifier,
                        if (chart.approach.icaoIdentifier != null)
                          '(${chart.approach.icaoIdentifier})',
                        if (rwy != null) '· RWY $rwy',
                      ].join(' '),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Briefing Strip
              BriefingStripCard(chart: chart),

              // Missed approach text
              if (chart.missedApproachLegs.isNotEmpty)
                _MissedApproachCard(chart: chart),

              // Approach Legs Table
              ApproachLegsTable(chart: chart),

              // Map View (top-down)
              MapViewCard(chart: chart),

              // Profile View
              ProfileViewCard(chart: chart),

              // MSA
              if (chart.msa != null && chart.msa!.sectors.isNotEmpty)
                _MsaCard(chart: chart),

              // Speed/Time Table
              SpeedTimeTable(chart: chart),

              // Minimums
              MinimumsCard(chart: chart),
            ],
          );
        },
      ),
    );
  }
}

class _MissedApproachCard extends StatelessWidget {
  final dynamic chart;

  const _MissedApproachCard({required this.chart});

  @override
  Widget build(BuildContext context) {
    final missedLegs = chart.missedApproachLegs as List;
    if (missedLegs.isEmpty) return const SizedBox.shrink();

    // Build a simple missed approach description from fix names
    final fixes = missedLegs
        .where((l) => l.fixIdentifier != null)
        .map((l) => l.fixIdentifier as String)
        .toList();

    final text = fixes.isNotEmpty
        ? 'Missed approach via: ${fixes.join(', ')}'
        : 'Missed approach procedure';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MISSED APPROACH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MsaCard extends StatelessWidget {
  final dynamic chart;

  const _MsaCard({required this.chart});

  @override
  Widget build(BuildContext context) {
    final msa = chart.msa;
    if (msa == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MSA ${msa.msaCenter}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final sector in msa.sectors)
                  _SectorChip(
                    from: sector.bearingFrom,
                    to: sector.bearingTo,
                    altitude: sector.altitude,
                    radius: sector.radius,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectorChip extends StatelessWidget {
  final int from;
  final int to;
  final int altitude;
  final int radius;

  const _SectorChip({
    required this.from,
    required this.to,
    required this.altitude,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            '$from° - $to°',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '$altitude\'',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '$radius NM',
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
