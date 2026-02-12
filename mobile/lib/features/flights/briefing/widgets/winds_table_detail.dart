import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';
import '../../../../services/api_client.dart';
import 'winds_map_widget.dart';

/// Provider to fetch wind grid GeoJSON for the briefing map.
final _briefingWindGridProvider =
    FutureProvider.family<Map<String, dynamic>?, _WindGridKey>(
        (ref, key) async {
  final apiClient = ref.read(apiClientProvider);
  return apiClient.getWindGrid(
    minLat: key.minLat,
    maxLat: key.maxLat,
    minLng: key.minLng,
    maxLng: key.maxLng,
    altitude: key.altitude,
    spacing: key.spacing,
  );
});

class _WindGridKey {
  final double minLat, maxLat, minLng, maxLng, spacing;
  final int altitude;

  const _WindGridKey({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
    required this.altitude,
    required this.spacing,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _WindGridKey &&
          minLat == other.minLat &&
          maxLat == other.maxLat &&
          minLng == other.minLng &&
          maxLng == other.maxLng &&
          altitude == other.altitude &&
          spacing == other.spacing;

  @override
  int get hashCode => Object.hash(minLat, maxLat, minLng, maxLng, altitude, spacing);
}

class WindsTableDetail extends ConsumerWidget {
  final WindsAloftTable? table;
  final List<BriefingWaypoint> waypoints;
  final int cruiseAltitude;

  const WindsTableDetail({
    super.key,
    this.table,
    this.waypoints = const [],
    this.cruiseAltitude = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (table == null || table!.data.isEmpty) {
      return const Center(
        child: Text('No winds aloft data available',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    // Use table's filedAltitude (always set correctly by backend),
    // fall back to the passed cruiseAltitude
    final altitude = table!.filedAltitude > 0
        ? table!.filedAltitude
        : cruiseAltitude;

    // Compute bounds from waypoints for the wind grid request
    Map<String, dynamic>? windGridGeoJson;
    if (waypoints.length >= 2) {
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      for (final wp in waypoints) {
        if (wp.latitude < minLat) minLat = wp.latitude;
        if (wp.latitude > maxLat) maxLat = wp.latitude;
        if (wp.longitude < minLng) minLng = wp.longitude;
        if (wp.longitude > maxLng) maxLng = wp.longitude;
      }

      // Expand bounds to show surrounding area
      final latPad = (maxLat - minLat) * 0.3 + 0.5;
      final lngPad = (maxLng - minLng) * 0.3 + 0.5;
      minLat -= latPad;
      maxLat += latPad;
      minLng -= lngPad;
      maxLng += lngPad;

      // Compute appropriate spacing (~10 points across shorter dimension)
      final latSpan = maxLat - minLat;
      final lngSpan = maxLng - minLng;
      final span = latSpan < lngSpan ? latSpan : lngSpan;
      final rawSpacing = span / 10;
      double spacing;
      if (rawSpacing <= 0.5) {
        spacing = 0.5;
      } else if (rawSpacing <= 1.0) {
        spacing = 1.0;
      } else if (rawSpacing <= 2.0) {
        spacing = 2.0;
      } else {
        spacing = 3.0;
      }

      final key = _WindGridKey(
        minLat: double.parse(minLat.toStringAsFixed(1)),
        maxLat: double.parse(maxLat.toStringAsFixed(1)),
        minLng: double.parse(minLng.toStringAsFixed(1)),
        maxLng: double.parse(maxLng.toStringAsFixed(1)),
        altitude: altitude,
        spacing: spacing,
      );

      final windAsync = ref.watch(_briefingWindGridProvider(key));
      windGridGeoJson = windAsync.value;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Map visualization
        if (waypoints.length >= 2) ...[
          Row(
            children: [
              const Icon(Icons.map_outlined,
                  color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Winds at ${_formatAltitude(altitude)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'NCEP GFS',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 350,
            child: WindsMapWidget(
              waypoints: waypoints,
              cruiseAltitude: altitude,
              windGridGeoJson: windGridGeoJson,
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Table
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
