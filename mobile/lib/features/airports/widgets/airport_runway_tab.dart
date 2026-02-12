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

        // Get wind from METAR if available (including nearby station data)
        final metarEnvelope = metarAsync.whenData((d) => d).value;
        final metarData = metarEnvelope?['metar'] as Map<String, dynamic>?;
        final wdirRaw = metarData?['wdir'];
        final windDir = wdirRaw is num ? wdirRaw : null;
        final windSpd = metarData?['wspd'] as num?;
        final windGust = metarData?['wgst'] as num?;
        final isNearby = metarEnvelope?['isNearby'] as bool? ?? false;
        final nearbyStation = metarEnvelope?['station'] as String? ?? '';
        final nearbyDistance = metarEnvelope?['distanceNm'];

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
              final heading = end['heading'] as num? ??
                  _headingFromIdentifier(end['identifier'] as String?);
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
            // Nearby station wind warning
            if (isNearby && windDir != null && windSpd != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 20, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Winds from $nearbyStation ($nearbyDistance nm away)',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                  () {
                    final windStr = windGust != null
                        ? 'Wind: $windDir° at $windSpd G$windGust kts'
                        : 'Wind: $windDir° at $windSpd kts';
                    return isNearby
                        ? '$windStr ($nearbyStation)'
                        : windStr;
                  }(),
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

  /// Derive magnetic heading from runway identifier (e.g. "02" → 20, "35R" → 350).
  static num? _headingFromIdentifier(String? identifier) {
    if (identifier == null || identifier.isEmpty) return null;
    final digits = RegExp(r'^\d+').stringMatch(identifier);
    if (digits == null) return null;
    final num = int.tryParse(digits);
    if (num == null || num < 1 || num > 36) return null;
    return num * 10;
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
    final metarAsync = ref.watch(metarProvider(widget.airportId));

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
              final endId = end['identifier'] as String? ?? '';

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

              final heading = end['heading'] ??
                  AirportRunwayTab._headingFromIdentifier(
                      end['identifier'] as String?);
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

              // Compute wind components for selected runway end
              final detailEnvelope = metarAsync.whenData((d) => d).value;
              final detailMetar = detailEnvelope?['metar'] as Map<String, dynamic>?;
              final windDir = detailMetar?['wdir'] as num?;
              final windSpd = detailMetar?['wspd'] as num?;
              final windGust = detailMetar?['wgst'] as num?;
              final detailIsNearby = detailEnvelope?['isNearby'] as bool? ?? false;
              final detailStation = detailEnvelope?['station'] as String? ?? '';
              final detailDistance = detailEnvelope?['distanceNm'];

              int? headwindComp, crosswindComp, gustHead, gustCross;
              bool isHeadwind = true;
              if (windDir != null &&
                  windSpd != null &&
                  heading != null) {
                final angleDiff =
                    (windDir.toDouble() - (heading as num).toDouble()) *
                        pi /
                        180;
                final hw = windSpd.toDouble() * cos(angleDiff);
                final xw =
                    (windSpd.toDouble() * sin(angleDiff)).abs();
                isHeadwind = hw >= 0;
                headwindComp = hw.abs().round();
                crosswindComp = xw.round();
                if (windGust != null) {
                  gustHead =
                      (windGust.toDouble() * cos(angleDiff)).abs().round();
                  gustCross =
                      (windGust.toDouble() * sin(angleDiff)).abs().round();
                }
              }

              return Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.airportId,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Runway Details',
                          style: TextStyle(
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: List.generate(ends.length, (i) {
                          final eid =
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
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.divider,
                                    ),
                                  ),
                                  child: Text(
                                    'Rwy $eid',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
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
                  // Nearby wind warning in detail sheet
                  if (detailIsNearby && windDir != null && windSpd != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 18, color: AppColors.warning),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Winds from $detailStation ($detailDistance nm away)',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Scrollable content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        _DetailSection(
                            title: 'RUNWAY DETAILS - $endId',
                            items: [
                              _DetailRow(label: 'Dimensions', value: dims),
                              if (surfaceText.isNotEmpty)
                                _DetailRow(
                                    label: 'Surface', value: surfaceText),
                              if (glideslope != null && glideslope.isNotEmpty)
                                _DetailRow(
                                    label: 'Glideslope Ind.',
                                    value: glideslope),
                              if (slope != null)
                                _DetailRow(label: 'Slope', value: '$slope%'),
                              if (heading != null)
                                _DetailRow(
                                    label: 'Heading', value: '$heading°M'),
                              if (trafficPattern != null &&
                                  trafficPattern.isNotEmpty)
                                _DetailRow(
                                  label: 'Traffic Pattern',
                                  value: '$trafficPattern traffic',
                                  valueColor: Colors.green,
                                ),
                              if (headwindComp != null)
                                _WindRow(
                                  headwind: headwindComp,
                                  crosswind: crosswindComp!,
                                  gustHeadwind: gustHead,
                                  gustCrosswind: gustCross,
                                  isHeadwind: isHeadwind,
                                ),
                            ]),
                        if (elevation != null)
                          _DetailSection(
                              title: 'ELEVATION - $endId',
                              items: [
                                _DetailRow(
                                    label: 'Touchdown',
                                    value: '${_fmtNum(elevation)}\' MSL'),
                              ]),
                        if (tora != null ||
                            toda != null ||
                            asda != null ||
                            lda != null)
                          _DetailSection(
                              title: 'DECLARED DISTANCES - $endId',
                              items: [
                                if (tora != null)
                                  _DetailRow(
                                      label: 'TORA',
                                      value: '${_fmtNum(tora)}\''),
                                if (toda != null)
                                  _DetailRow(
                                      label: 'TODA',
                                      value: '${_fmtNum(toda)}\''),
                                if (asda != null)
                                  _DetailRow(
                                      label: 'ASDA',
                                      value: '${_fmtNum(asda)}\''),
                                if (lda != null)
                                  _DetailRow(
                                      label: 'LDA',
                                      value: '${_fmtNum(lda)}\''),
                              ]),
                        if (displaced != null && displaced > 0)
                          _DetailSection(
                              title: 'THRESHOLD - $endId',
                              items: [
                                _DetailRow(
                                    label: 'Displaced',
                                    value: '${_fmtNum(displaced)}\''),
                              ]),
                        _DetailSection(
                            title: 'LIGHTING - $endId',
                            items: [
                              _DetailRow(
                                  label: 'Approach', value: lightApproach),
                              _DetailRow(label: 'Edge', value: lightEdge),
                            ]),
                        if (lat != null && lng != null)
                          _DetailSection(
                              title: 'COORDINATES - $endId',
                              items: [
                                _DetailRow(
                                  label: '',
                                  value:
                                      '${lat.toStringAsFixed(4)}°${lat >= 0 ? 'N' : 'S'} / ${lng.abs().toStringAsFixed(4)}°${lng >= 0 ? 'E' : 'W'}',
                                ),
                              ]),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
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
  final List<Widget> items;

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

class _WindRow extends StatelessWidget {
  final int headwind;
  final int crosswind;
  final int? gustHeadwind;
  final int? gustCrosswind;
  final bool isHeadwind;

  const _WindRow({
    required this.headwind,
    required this.crosswind,
    this.gustHeadwind,
    this.gustCrosswind,
    this.isHeadwind = true,
  });

  @override
  Widget build(BuildContext context) {
    final headColor = isHeadwind ? AppColors.vfr : AppColors.error;
    final crossColor = crosswind <= 15 ? AppColors.textSecondary : AppColors.error;

    final headStr = gustHeadwind != null && gustHeadwind != headwind
        ? '$headwind-$gustHeadwind kts'
        : '$headwind kts';
    final crossStr = gustCrosswind != null && gustCrosswind != crosswind
        ? '$crosswind-$gustCrosswind kts'
        : '$crosswind kts';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Wind',
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
          const Spacer(),
          // Crosswind component
          Icon(
            Icons.arrow_back,
            size: 14,
            color: crossColor,
          ),
          const SizedBox(width: 2),
          Text(
            crossStr,
            style: TextStyle(fontSize: 14, color: crossColor),
          ),
          const SizedBox(width: 12),
          // Headwind/tailwind component
          Icon(
            isHeadwind ? Icons.arrow_downward : Icons.arrow_upward,
            size: 14,
            color: headColor,
          ),
          const SizedBox(width: 2),
          Text(
            headStr,
            style: TextStyle(fontSize: 14, color: headColor),
          ),
        ],
      ),
    );
  }
}
