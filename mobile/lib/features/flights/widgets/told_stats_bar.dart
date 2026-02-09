import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/told_result.dart';
import '../../../services/told_providers.dart';

class ToldStatsBar extends StatelessWidget {
  final ToldResult? result;
  final ToldMode mode;

  const ToldStatsBar({super.key, this.result, required this.mode});

  @override
  Widget build(BuildContext context) {
    final weight = result?.weight;
    final totalDist = result?.totalDistanceFt;
    final vr = result?.vrKias;
    final v50 = result?.v50Kias;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(
            label: 'WEIGHT',
            value: weight != null ? '${weight.round()}' : '--',
            unit: 'lbs',
          ),
          _divider(),
          _StatItem(
            label: 'TOT DIST',
            value: totalDist != null ? '${totalDist.round()}' : '--',
            unit: 'ft',
            valueColor: result?.exceedsRunway == true ? AppColors.error : null,
          ),
          _divider(),
          _StatItem(
            label: mode == ToldMode.takeoff ? 'VR' : 'VAPP',
            value: vr != null ? '${vr.round()}' : '--',
            unit: 'kt',
          ),
          if (mode == ToldMode.takeoff) ...[
            _divider(),
            _StatItem(
              label: 'V50',
              value: v50 != null ? '${v50.round()}' : '--',
              unit: 'kt',
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.divider,
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
