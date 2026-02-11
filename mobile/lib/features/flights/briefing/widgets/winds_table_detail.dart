import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

class WindsTableDetail extends StatelessWidget {
  final WindsAloftTable? table;

  const WindsTableDetail({super.key, this.table});

  @override
  Widget build(BuildContext context) {
    if (table == null || table!.data.isEmpty) {
      return const Center(
        child: Text('No winds aloft data available',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Winds Aloft Table',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildTable(),
        ),
      ],
    );
  }

  Widget _buildTable() {
    final t = table!;

    return Table(
      border: TableBorder.all(color: AppColors.divider, width: 0.5),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: [
        // Header row: altitude columns
        TableRow(
          children: [
            _headerCell('Waypoint'),
            ...t.altitudes.map((alt) {
              final isFiled = alt == t.filedAltitude;
              return _headerCell(
                _formatAltitude(alt),
                highlight: isFiled,
                subLabel: isFiled ? 'Filed' : null,
              );
            }),
          ],
        ),
        // Data rows: one per waypoint
        for (int wpIdx = 0; wpIdx < t.waypoints.length; wpIdx++)
          TableRow(
            children: [
              _waypointCell(t.waypoints[wpIdx]),
              ...List.generate(t.altitudes.length, (altIdx) {
                final cell = (wpIdx < t.data.length && altIdx < t.data[wpIdx].length)
                    ? t.data[wpIdx][altIdx]
                    : const WindsAloftCell();
                final isFiled = t.altitudes[altIdx] == t.filedAltitude;
                return _windCell(cell, highlight: isFiled);
              }),
            ],
          ),
      ],
    );
  }

  Widget _headerCell(String text,
      {bool highlight = false, String? subLabel}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: highlight ? AppColors.primary.withAlpha(30) : AppColors.surface,
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              color: highlight ? AppColors.accent : AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subLabel != null)
            Text(
              subLabel,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _waypointCell(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        name,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _windCell(WindsAloftCell cell, {bool highlight = false}) {
    if (cell.direction == null && cell.speed == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: highlight ? AppColors.primary.withAlpha(15) : null,
        child: const Text(
          '--',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      );
    }

    final dir = cell.direction?.round() ?? 0;
    final spd = cell.speed?.round() ?? 0;
    final temp = cell.temperature?.round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: highlight ? AppColors.primary.withAlpha(15) : null,
      child: Column(
        children: [
          Text(
            '$dir\u00B0 ${spd}kt',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          if (temp != null)
            Text(
              '$temp\u00B0C',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }

  String _formatAltitude(int alt) {
    if (alt >= 18000) {
      return 'FL${alt ~/ 100}';
    }
    if (alt >= 1000) {
      return '${(alt / 1000).toStringAsFixed(alt % 1000 == 0 ? 0 : 1)}k';
    }
    return '$alt';
  }
}
