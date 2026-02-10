import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/approach_chart.dart';

class SpeedTimeTable extends StatelessWidget {
  final ApproachChartData chart;

  const SpeedTimeTable({super.key, required this.chart});

  static const _groundSpeeds = [70, 90, 100, 120, 140, 160];

  @override
  Widget build(BuildContext context) {
    final gsAngle = chart.ils?.gsAngle;
    final fafToMap = chart.fafToMapDistance;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'SPEED / TIME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (fafToMap != null)
                  Text(
                    'FAF to MAP: ${fafToMap.toStringAsFixed(1)} NM',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Header
            Row(
              children: [
                const SizedBox(
                  width: 48,
                  child: Text(
                    'GS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                for (final gs in _groundSpeeds)
                  Expanded(
                    child: Text(
                      '$gs',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
            const Divider(height: 8),
            // Descent rate row (if GS angle available)
            if (gsAngle != null && gsAngle > 0) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 48,
                    child: Text(
                      'FPM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  for (final gs in _groundSpeeds)
                    Expanded(
                      child: Text(
                        _descentRate(gs, gsAngle).toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            // Time row (if FAF-to-MAP distance available)
            if (fafToMap != null)
              Row(
                children: [
                  const SizedBox(
                    width: 48,
                    child: Text(
                      'TIME',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  for (final gs in _groundSpeeds)
                    Expanded(
                      child: Text(
                        _timeStr(gs, fafToMap),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Calculate descent rate in FPM for a given ground speed and GS angle.
  int _descentRate(int groundSpeedKts, double gsAngleDeg) {
    final gsRad = gsAngleDeg * math.pi / 180;
    final fpm = groundSpeedKts * 6076.12 / 60 * math.tan(gsRad);
    return (fpm / 10).round() * 10; // round to nearest 10
  }

  /// Calculate time from FAF to MAP as "M:SS".
  String _timeStr(int groundSpeedKts, double distNm) {
    if (groundSpeedKts == 0) return '---';
    final minutes = distNm / groundSpeedKts * 60;
    final mins = minutes.floor();
    final secs = ((minutes - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
