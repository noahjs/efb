import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/airport_providers.dart';

class AirportRunwayTab extends ConsumerWidget {
  final String airportId;
  const AirportRunwayTab({super.key, required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airportAsync = ref.watch(airportDetailProvider(airportId));
    final metarAsync = ref.watch(metarProvider(airportId));

    return airportAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
        child: Text(
          'Failed to load runway data',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (airport) {
        if (airport == null) {
          return const Center(
            child: Text(
              'No runway data available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final runways = (airport['runways'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

        if (runways.isEmpty) {
          return const Center(
            child: Text(
              'No runways found',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        // Get wind from METAR if available
        final metar = metarAsync.whenData((d) => d).value;
        final windDir = metar?['wdir'] as num?;
        final windSpd = metar?['wspd'] as num?;
        final windGust = metar?['wgst'] as num?;

        // Compute wind components for each runway end
        final endWinds = <String, _WindComponents>{};
        int? bestEndKey;
        double bestHeadwind = double.negativeInfinity;

        if (windDir != null && windSpd != null) {
          for (final rwy in runways) {
            final ends = (rwy['ends'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
            for (final end in ends) {
              final id = end['id']?.toString() ?? '';
              final heading = end['heading'] as num?;
              if (heading == null) continue;

              final angleDiff = (windDir - heading) * pi / 180;
              final headwind = windSpd * cos(angleDiff);
              final crosswind = windSpd * sin(angleDiff).abs();
              final gustHeadwind =
                  windGust != null ? windGust * cos(angleDiff) : null;
              final gustCrosswind =
                  windGust != null ? (windGust * sin(angleDiff)).abs() : null;

              endWinds[id] = _WindComponents(
                headwind: headwind.round(),
                crosswind: crosswind.round(),
                gustHeadwind: gustHeadwind?.round(),
                gustCrosswind: gustCrosswind?.round(),
              );

              if (headwind > bestHeadwind) {
                bestHeadwind = headwind.toDouble();
                bestEndKey = end['id'] as int?;
              }
            }
          }
        }

        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'RUNWAYS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (final rwy in runways)
              _buildRunwayCard(context, rwy, endWinds, bestEndKey),
            const SizedBox(height: 12),
            // Wind info from METAR
            if (windDir != null && windSpd != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  windGust != null
                      ? 'Wind: $windDir° at $windSpd G$windGust kts'
                      : 'Wind: $windDir° at $windSpd kts',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildRunwayCard(
    BuildContext context,
    Map<String, dynamic> rwy,
    Map<String, _WindComponents> endWinds,
    int? bestEndKey,
  ) {
    final identifiers = rwy['identifiers'] as String? ?? '';
    final length = rwy['length'];
    final width = rwy['width'];
    final surface = rwy['surface'] as String? ?? '';
    final condition = rwy['condition'] as String? ?? '';

    final dims = length != null && width != null
        ? '${_fmtNum(length)}\' x ${_fmtNum(width)}\''
        : '';
    final surfaceText =
        [condition, surface].where((s) => s.isNotEmpty).join(' ').toLowerCase();
    final surfaceDisplay =
        surfaceText.isNotEmpty ? _capitalize(surfaceText) : '';

    // Format identifiers for display (e.g. "03-21" -> "03 - 21")
    final displayPair = identifiers.replaceAll('-', ' - ');

    final ends =
        (rwy['ends'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return InkWell(
      onTap: () => _showRunwayDetail(context, airportId, identifiers),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayPair,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (dims.isNotEmpty)
                    Text(
                      dims,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (surfaceDisplay.isNotEmpty)
                    Text(
                      surfaceDisplay,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (final end in ends)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RunwayEndWidget(
                        end: end,
                        wind: endWinds[end['id']?.toString() ?? ''],
                        isBestWind: end['id'] == bestEndKey,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  void _showRunwayDetail(
      BuildContext context, String airportId, String runway) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (context) =>
          _RunwayDetailSheet(airportId: airportId, runwayIdentifiers: runway),
    );
  }

  static String _fmtNum(dynamic n) {
    if (n is num) {
      return n.toInt().toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'),
            (m) => '${m[1]},',
          );
    }
    return n?.toString() ?? '--';
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _WindComponents {
  final int headwind;
  final int crosswind;
  final int? gustHeadwind;
  final int? gustCrosswind;

  const _WindComponents({
    required this.headwind,
    required this.crosswind,
    this.gustHeadwind,
    this.gustCrosswind,
  });
}

class _RunwayEndWidget extends StatelessWidget {
  final Map<String, dynamic> end;
  final _WindComponents? wind;
  final bool isBestWind;

  const _RunwayEndWidget({
    required this.end,
    this.wind,
    this.isBestWind = false,
  });

  @override
  Widget build(BuildContext context) {
    final identifier = end['identifier'] as String? ?? '';
    final trafficPattern = end['traffic_pattern'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Rwy $identifier',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (isBestWind) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Best Wind',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (trafficPattern != null && trafficPattern.isNotEmpty)
          Text(
            trafficPattern,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.error,
            ),
          ),
        if (wind != null)
          Row(
            children: [
              Icon(
                Icons.arrow_forward,
                size: 12,
                color: wind!.headwind >= 0 ? AppColors.vfr : AppColors.error,
              ),
              const SizedBox(width: 2),
              Text(
                _formatWindComponent(
                    wind!.headwind, wind!.gustHeadwind, 'kt'),
                style: TextStyle(
                  fontSize: 12,
                  color:
                      wind!.headwind >= 0 ? AppColors.vfr : AppColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_downward,
                size: 12,
                color:
                    wind!.crosswind <= 15 ? AppColors.vfr : AppColors.error,
              ),
              const SizedBox(width: 2),
              Text(
                _formatWindComponent(
                    wind!.crosswind, wind!.gustCrosswind, 'kt'),
                style: TextStyle(
                  fontSize: 12,
                  color: wind!.crosswind <= 15
                      ? AppColors.vfr
                      : AppColors.error,
                ),
              ),
            ],
          ),
      ],
    );
  }

  static String _formatWindComponent(int base, int? gust, String unit) {
    if (gust != null && gust != base) {
      return '${base.abs()}-${gust.abs()} $unit';
    }
    return '${base.abs()} $unit';
  }
}

class _RunwayDetailSheet extends ConsumerStatefulWidget {
  final String airportId;
  final String runwayIdentifiers;
  const _RunwayDetailSheet({
    required this.airportId,
    required this.runwayIdentifiers,
  });

  @override
  ConsumerState<_RunwayDetailSheet> createState() =>
      _RunwayDetailSheetState();
}

class _RunwayDetailSheetState extends ConsumerState<_RunwayDetailSheet> {
  int _selectedEndIndex = 0;

  @override
  Widget build(BuildContext context) {
    final airportAsync = ref.watch(airportDetailProvider(widget.airportId));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: airportAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(
              child: Text('Failed to load runway data',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            data: (airport) {
              if (airport == null) {
                return const Center(
                  child: Text('Airport not found',
                      style: TextStyle(color: AppColors.textMuted)),
                );
              }

              final runways = airport['runways'] as List<dynamic>? ?? [];
              final runway = runways.cast<Map<String, dynamic>>().firstWhere(
                    (r) => r['identifiers'] == widget.runwayIdentifiers,
                    orElse: () => <String, dynamic>{},
                  );

              if (runway.isEmpty) {
                return const Center(
                  child: Text('Runway not found',
                      style: TextStyle(color: AppColors.textMuted)),
                );
              }

              final ends = (runway['ends'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>();

              if (ends.isEmpty) {
                return const Center(
                  child: Text('No runway end data',
                      style: TextStyle(color: AppColors.textMuted)),
                );
              }

              // Clamp index in case data changed
              final endIndex = _selectedEndIndex.clamp(0, ends.length - 1);
              final end = ends[endIndex];

              final length = runway['length'];
              final width = runway['width'];
              final surface = runway['surface'] as String? ?? '';
              final condition = runway['condition'] as String? ?? '';
              final slope = runway['slope'];
              final dims = length != null && width != null
                  ? '${_fmtNum(length)}\' x ${_fmtNum(width)}\''
                  : '--';
              final surfaceText = [surface, condition]
                  .where((s) => s.isNotEmpty)
                  .join(', ');

              final heading = end['heading'];
              final elevation = end['elevation'];
              final glideslope = end['glideslope'] as String?;
              final trafficPattern = end['traffic_pattern'] as String?;
              final tora = end['tora'];
              final toda = end['toda'];
              final asda = end['asda'];
              final lda = end['lda'];
              final lightApproach =
                  end['lighting_approach'] as String? ?? 'None';
              final lightEdge = end['lighting_edge'] as String? ?? 'None';
              final lat = end['latitude'];
              final lng = end['longitude'];
              final displaced = end['displaced_threshold'];

              return ListView(
                controller: scrollController,
                children: [
                  // Header with back button
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.toolbarBackground,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back_ios,
                                  size: 16, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text('Back',
                                  style: TextStyle(
                                      color: AppColors.primary, fontSize: 14)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Runway Details',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 60),
                      ],
                    ),
                  ),

                  // Runway end toggle
                  if (ends.length >= 2)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: List.generate(ends.length, (i) {
                          final endId =
                              ends[i]['identifier'] as String? ?? '??';
                          final isSelected = i == endIndex;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  right: i < ends.length - 1 ? 8 : 0),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedEndIndex = i),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                            .withValues(alpha: 0.15)
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                              .withValues(alpha: 0.5)
                                          : AppColors.divider,
                                    ),
                                  ),
                                  child: Text(
                                    'Rwy $endId',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                  const SizedBox(height: 8),

                  _DetailSection(title: 'RUNWAY DETAILS', items: [
                    _DetailRow(label: 'Dimensions', value: dims),
                    if (surfaceText.isNotEmpty)
                      _DetailRow(label: 'Surface', value: surfaceText),
                    if (glideslope != null && glideslope.isNotEmpty)
                      _DetailRow(
                          label: 'Glideslope Ind.', value: glideslope),
                    if (slope != null)
                      _DetailRow(label: 'Slope', value: '$slope%'),
                    if (heading != null)
                      _DetailRow(label: 'Heading', value: '$heading°M'),
                    if (trafficPattern != null && trafficPattern.isNotEmpty)
                      _DetailRow(
                        label: 'Traffic Pattern',
                        value: trafficPattern,
                        valueColor: AppColors.error,
                      ),
                  ]),

                  if (elevation != null)
                    _DetailSection(title: 'ELEVATION', items: [
                      _DetailRow(
                          label: 'Touchdown',
                          value: '${_fmtNum(elevation)}\' MSL'),
                    ]),

                  if (tora != null ||
                      toda != null ||
                      asda != null ||
                      lda != null)
                    _DetailSection(title: 'DECLARED DISTANCES', items: [
                      if (tora != null)
                        _DetailRow(
                            label: 'TORA', value: '${_fmtNum(tora)}\''),
                      if (toda != null)
                        _DetailRow(
                            label: 'TODA', value: '${_fmtNum(toda)}\''),
                      if (asda != null)
                        _DetailRow(
                            label: 'ASDA', value: '${_fmtNum(asda)}\''),
                      if (lda != null)
                        _DetailRow(
                            label: 'LDA', value: '${_fmtNum(lda)}\''),
                    ]),

                  if (displaced != null && displaced > 0)
                    _DetailSection(title: 'THRESHOLD', items: [
                      _DetailRow(
                          label: 'Displaced',
                          value: '${_fmtNum(displaced)}\''),
                    ]),

                  _DetailSection(title: 'LIGHTING', items: [
                    _DetailRow(label: 'Approach', value: lightApproach),
                    _DetailRow(label: 'Edge', value: lightEdge),
                  ]),

                  if (lat != null && lng != null)
                    _DetailSection(title: 'COORDINATES', items: [
                      _DetailRow(
                        label: '',
                        value:
                            '${lat.toStringAsFixed(4)}°${lat >= 0 ? 'N' : 'S'} / ${lng.abs().toStringAsFixed(4)}°${lng >= 0 ? 'E' : 'W'}',
                      ),
                    ]),

                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static String _fmtNum(dynamic n) {
    if (n is num) {
      return n.toInt().toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'),
            (m) => '${m[1]},',
          );
    }
    return n?.toString() ?? '--';
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailRow> items;

  const _DetailSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
