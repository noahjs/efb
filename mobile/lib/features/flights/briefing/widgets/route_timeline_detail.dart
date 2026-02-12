import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

class RouteTimelineDetail extends StatelessWidget {
  final List<TimelinePoint> timeline;
  final String departureId;
  final String destinationId;

  const RouteTimelineDetail({
    super.key,
    required this.timeline,
    required this.departureId,
    required this.destinationId,
  });

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return const Center(
        child: Text('No route timeline available',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Route Timeline',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(timeline.length, (idx) {
          final point = timeline[idx];
          final isFirst = idx == 0;
          final isLast = idx == timeline.length - 1;
          final hasHazards = point.activeHazards.isNotEmpty;

          return _TimelineEntry(
            point: point,
            isFirst: isFirst,
            isLast: isLast,
            hasHazards: hasHazards,
            label: isFirst
                ? '$departureId (Departure)'
                : isLast
                    ? '$destinationId (Destination)'
                    : null,
          );
        }),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final TimelinePoint point;
  final bool isFirst;
  final bool isLast;
  final bool hasHazards;
  final String? label;

  const _TimelineEntry({
    required this.point,
    required this.isFirst,
    required this.isLast,
    required this.hasHazards,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline rail
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Connector above
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 8,
                    color: hasHazards ? AppColors.warning : AppColors.divider,
                  ),
                // Dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _flightCatColor(point.flightCategory),
                    border: Border.all(
                      color: AppColors.textSecondary,
                      width: 1,
                    ),
                  ),
                ),
                // Connector below
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: hasHazards ? AppColors.warning : AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waypoint header
                    Row(
                      children: [
                        Text(
                          label ?? '${point.waypoint} (${point.distanceFromDep}nm)',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatEta(point),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Weather row
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (point.flightCategory != null)
                          _FlightCatChip(cat: point.flightCategory!),
                        if (point.ceiling != null)
                          _InfoChip(
                            label: 'CIG ${point.ceiling}',
                            icon: Icons.cloud,
                          ),
                        if (point.visibility != null)
                          _InfoChip(
                            label: 'VIS ${point.visibility!.toStringAsFixed(0)}',
                            icon: Icons.visibility,
                          ),
                        if (point.windDir != null && point.windSpd != null)
                          _InfoChip(
                            label:
                                '${point.windDir!.toString().padLeft(3, '0')}/${point.windSpd}kt',
                            icon: Icons.air,
                          ),
                      ],
                    ),
                    // Wind components
                    if (point.headwindComponent != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _formatWindComponent(point.headwindComponent!,
                            point.crosswindComponent),
                        style: TextStyle(
                          color: point.headwindComponent! > 0
                              ? AppColors.error
                              : AppColors.success,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    // TAF forecast
                    if (point.forecastAtEta != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'TAF: ${point.forecastAtEta!.fltCat ?? "N/A"} (${point.forecastAtEta!.changeType})',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    // Hazards
                    if (point.activeHazards.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...point.activeHazards.map((h) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _hazardIcon(h.type),
                                  size: 14,
                                  color: h.altitudeRelation == 'within'
                                      ? AppColors.error
                                      : AppColors.warning,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    h.description,
                                    style: TextStyle(
                                      color: h.altitudeRelation == 'within'
                                          ? AppColors.error
                                          : AppColors.warning,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatEta(TimelinePoint pt) {
    if (pt.etaZulu != null) {
      final dt = DateTime.tryParse(pt.etaZulu!);
      if (dt != null) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}Z';
      }
    }
    final h = pt.etaMinutes ~/ 60;
    final m = pt.etaMinutes % 60;
    return '+${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _formatWindComponent(int headwind, int? crosswind) {
    final hwLabel = headwind > 0 ? 'HW' : 'TW';
    final hwStr = '$hwLabel ${headwind.abs()}kt';
    if (crosswind != null && crosswind != 0) {
      final xwDir = crosswind > 0 ? 'R' : 'L';
      return '$hwStr  XW ${crosswind.abs()}kt $xwDir';
    }
    return hwStr;
  }

  static IconData _hazardIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('ice') || t.contains('icing')) return Icons.ac_unit;
    if (t.contains('turb')) return Icons.waves;
    if (t.contains('conv') || t.contains('thunder')) return Icons.thunderstorm;
    if (t.contains('ifr')) return Icons.visibility_off;
    if (t.contains('mtn')) return Icons.terrain;
    return Icons.warning_amber;
  }
}

class _FlightCatChip extends StatelessWidget {
  final String cat;

  const _FlightCatChip({required this.cat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _flightCatColor(cat),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        cat,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

Color _flightCatColor(String? cat) {
  switch (cat?.toUpperCase()) {
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
