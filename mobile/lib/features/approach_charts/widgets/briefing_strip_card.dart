import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/approach_chart.dart';

class BriefingStripCard extends StatelessWidget {
  final ApproachChartData chart;

  const BriefingStripCard({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    final ils = chart.ils;
    final runway = chart.runway;
    final faf = chart.findFaf();
    final isIls = chart.approach.routeType == 'I';

    // Localizer / Frequency
    final locId = ils?.localizerIdentifier ?? '';
    final freq = ils?.frequencyDisplay ?? '';

    // Course
    final course = ils?.localizerBearing != null
        ? '${ils!.localizerBearing!.round()}°'
        : (faf?.magneticCourse != null
            ? '${faf!.magneticCourse!.round()}°'
            : '---');

    // FAF altitude
    final fafAlt = faf?.altitude1 != null ? '${faf!.altitude1}\'' : '---';
    final fafName = faf?.fixIdentifier ?? 'FAF';

    // DA/MDA — first approach leg with altitude that's at MAP
    final mapLeg = chart.legs.cast<ApproachLeg?>().firstWhere(
          (l) => l!.isMap,
          orElse: () => null,
        );
    final daLabel = isIls ? 'DA(H)' : 'MDA(H)';
    final daValue = mapLeg?.altitude1 != null ? '${mapLeg!.altitude1}\'' : '---';

    // TDZE
    final tdze = runway?.tdzeDisplay ?? '---';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BRIEFING STRIP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Cell(
                  label: locId.isNotEmpty ? locId : 'LOC',
                  value: freq.isNotEmpty ? freq : '---',
                ),
                _divider(),
                _Cell(label: 'CRS', value: course),
                _divider(),
                _Cell(label: fafName, value: fafAlt),
                _divider(),
                _Cell(label: daLabel, value: daValue),
                _divider(),
                _Cell(label: 'TDZE', value: tdze),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;

  const _Cell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
