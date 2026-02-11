import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

class MetarDetail extends StatelessWidget {
  final List<BriefingMetar> metars;
  final List<BriefingWaypoint> waypoints;

  const MetarDetail({
    super.key,
    required this.metars,
    required this.waypoints,
  });

  @override
  Widget build(BuildContext context) {
    if (metars.isEmpty) {
      return const Center(
        child: Text('No METARs available',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'METARs',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ..._buildGroupedMetars(),
      ],
    );
  }

  List<Widget> _buildGroupedMetars() {
    final widgets = <Widget>[];
    final groups = {
      'DEPARTURE': metars.where((m) => m.section == 'departure').toList(),
      'ROUTE': metars.where((m) => m.section == 'route').toList(),
      'DESTINATION': metars.where((m) => m.section == 'destination').toList(),
    };

    for (final entry in groups.entries) {
      if (entry.value.isEmpty) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          entry.key,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ));
      for (final metar in entry.value) {
        widgets.add(_MetarRow(metar: metar));
      }
    }

    return widgets;
  }
}

class _MetarRow extends StatelessWidget {
  final BriefingMetar metar;

  const _MetarRow({required this.metar});

  Color get _categoryColor {
    switch (metar.flightCategory?.toUpperCase()) {
      case 'VFR':
        return AppColors.vfr;
      case 'MVFR':
        return AppColors.mvfr;
      case 'IFR':
        return AppColors.ifr;
      case 'LIFR':
        return AppColors.lifr;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _categoryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                metar.flightCategory ?? '?',
                style: TextStyle(
                  color: _categoryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                metar.icaoId,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (metar.obsTime != null)
                Text(
                  metar.obsTime!,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
            ],
          ),
          if (metar.rawOb != null) ...[
            const SizedBox(height: 6),
            Text(
              metar.rawOb!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
