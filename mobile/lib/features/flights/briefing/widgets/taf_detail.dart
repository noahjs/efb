import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

class TafDetail extends StatelessWidget {
  final List<BriefingTaf> tafs;
  final List<BriefingWaypoint> waypoints;

  const TafDetail({
    super.key,
    required this.tafs,
    required this.waypoints,
  });

  @override
  Widget build(BuildContext context) {
    if (tafs.isEmpty) {
      return const Center(
        child: Text('No TAFs available',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'TAFs',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ..._buildGroupedTafs(),
      ],
    );
  }

  List<Widget> _buildGroupedTafs() {
    final widgets = <Widget>[];
    final groups = {
      'DEPARTURE': tafs.where((t) => t.section == 'departure').toList(),
      'ROUTE': tafs.where((t) => t.section == 'route').toList(),
      'DESTINATION': tafs.where((t) => t.section == 'destination').toList(),
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
      for (final taf in entry.value) {
        widgets.add(_TafRow(taf: taf));
      }
    }

    return widgets;
  }
}

class _TafRow extends StatelessWidget {
  final BriefingTaf taf;

  const _TafRow({required this.taf});

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
          Text(
            taf.icaoId,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (taf.rawTaf != null) ...[
            const SizedBox(height: 6),
            Text(
              taf.rawTaf!,
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
