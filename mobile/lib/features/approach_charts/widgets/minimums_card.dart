import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/approach_chart.dart';

class MinimumsCard extends StatelessWidget {
  final ApproachChartData chart;

  const MinimumsCard({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    final isIls = chart.approach.routeType == 'I';
    final runway = chart.runway;
    final tdze = runway?.thresholdElevation;

    // MAP leg altitude is typically the DA/MDA
    final mapLeg = chart.legs.cast<ApproachLeg?>().firstWhere(
          (l) => l!.isMap,
          orElse: () => null,
        );
    final da = mapLeg?.altitude1;

    // Calculate HAT (height above threshold)
    final hat = (da != null && tdze != null) ? da - tdze : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MINIMUMS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (isIls) ...[
              _MinimumRow(
                type: 'ILS DA(H)',
                altitude: da != null ? '$da\'' : '---',
                hat: hat != null ? '($hat)' : '',
              ),
              const SizedBox(height: 4),
            ],
            _MinimumRow(
              type: isIls ? 'LOC MDA(H)' : 'MDA(H)',
              altitude: da != null ? '$da\'' : '---',
              hat: hat != null ? '($hat)' : '',
            ),
            if (tdze != null) ...[
              const Divider(height: 16),
              Row(
                children: [
                  const Text(
                    'TDZE',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$tdze\'',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 24),
                  if (chart.ils?.thresholdCrossingHeight != null) ...[
                    const Text(
                      'TCH',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${chart.ils!.thresholdCrossingHeight}\'',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MinimumRow extends StatelessWidget {
  final String type;
  final String altitude;
  final String hat;

  const _MinimumRow({
    required this.type,
    required this.altitude,
    this.hat = '',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            type,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          altitude,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (hat.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            hat,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
