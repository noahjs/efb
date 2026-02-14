import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_client.dart';

/// Standard altitude picker that shows ETE and fuel for each altitude option.
/// Matches the hemispheric altitude rules for VFR/IFR and East/West heading.
Future<int?> showAltitudePickerSheet(
  BuildContext context, {
  required ApiClient apiClient,
  int? currentAltitude,
  String? departureIdentifier,
  String? destinationIdentifier,
  String? routeString,
  int? trueAirspeed,
  double? fuelBurnRate,
  int? performanceProfileId,
  int? aircraftId,
  String? flightRules,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => _AltitudePickerBody(
        scrollController: scrollController,
        apiClient: apiClient,
        currentAltitude: currentAltitude,
        departureIdentifier: departureIdentifier,
        destinationIdentifier: destinationIdentifier,
        routeString: routeString,
        trueAirspeed: trueAirspeed,
        fuelBurnRate: fuelBurnRate,
        performanceProfileId: performanceProfileId,
        aircraftId: aircraftId,
        flightRules: flightRules,
      ),
    ),
  );
}

enum _RuleFilter { vfr, ifr }

enum _DirectionFilter { west, east, all }

class _AltitudePickerBody extends StatefulWidget {
  final ScrollController scrollController;
  final ApiClient apiClient;
  final int? currentAltitude;
  final String? departureIdentifier;
  final String? destinationIdentifier;
  final String? routeString;
  final int? trueAirspeed;
  final double? fuelBurnRate;
  final int? performanceProfileId;
  final int? aircraftId;

  final String? flightRules;

  const _AltitudePickerBody({
    required this.scrollController,
    required this.apiClient,
    this.currentAltitude,
    this.departureIdentifier,
    this.destinationIdentifier,
    this.routeString,
    this.trueAirspeed,
    this.fuelBurnRate,
    this.performanceProfileId,
    this.aircraftId,
    this.flightRules,
  });

  @override
  State<_AltitudePickerBody> createState() => _AltitudePickerBodyState();
}

class _AltitudePickerBodyState extends State<_AltitudePickerBody> {
  late _RuleFilter _rule;
  _DirectionFilter _direction = _DirectionFilter.west;
  Map<int, _AltitudeData> _data = {};
  bool _loading = false;

  // Computed optimal fields
  int? _optimalAltitude;
  int _timeSavedMinutes = 0;
  String? _comparedToLabel;
  double _maxAbsWind = 1; // avoid division by zero

  @override
  void initState() {
    super.initState();
    _rule = widget.flightRules?.toUpperCase() == 'VFR'
        ? _RuleFilter.vfr
        : _RuleFilter.ifr;
    _fetchData();
  }

  List<int> _generateAltitudes() {
    final altitudes = <int>[];
    final isVfr = _rule == _RuleFilter.vfr;

    if (_direction == _DirectionFilter.all) {
      // All standard altitudes
      for (int ft = 3000; ft <= 17000; ft += 1000) {
        if (isVfr) {
          altitudes.add(ft + 500);
        } else {
          altitudes.add(ft);
        }
      }
      if (!isVfr) {
        // Flight levels above 18,000
        for (int fl = 180; fl <= 450; fl += 10) {
          altitudes.add(fl * 100);
        }
      }
    } else {
      final isEast = _direction == _DirectionFilter.east;
      // Hemispheric rules:
      // Eastbound (0-179): odd thousands (IFR) / odd+500 (VFR)
      // Westbound (180-359): even thousands (IFR) / even+500 (VFR)
      for (int thousands = 3; thousands <= 17; thousands++) {
        final isOdd = thousands % 2 != 0;
        final matches = isEast ? isOdd : !isOdd;
        if (matches) {
          altitudes.add(isVfr ? thousands * 1000 + 500 : thousands * 1000);
        }
      }
      if (!isVfr) {
        // Flight levels — odd FLs east, even FLs west
        for (int fl = 180; fl <= 450; fl += 10) {
          final flOdd = (fl ~/ 10) % 2 != 0;
          final matches = isEast ? flOdd : !flOdd;
          if (matches) {
            altitudes.add(fl * 100);
          }
        }
      }
    }
    return altitudes;
  }

  Future<void> _fetchData() async {
    final altitudes = _generateAltitudes();
    if (altitudes.isEmpty) return;

    setState(() => _loading = true);
    try {
      final response = await widget.apiClient.calculateAltitudes(
        departureIdentifier: widget.departureIdentifier,
        destinationIdentifier: widget.destinationIdentifier,
        routeString: widget.routeString,
        trueAirspeed: widget.trueAirspeed,
        fuelBurnRate: widget.fuelBurnRate,
        performanceProfileId: widget.performanceProfileId,
        aircraftId: widget.aircraftId,
        altitudes: altitudes,
      );
      final results = response['results'] as List<dynamic>? ?? [];
      final dataMap = <int, _AltitudeData>{};
      for (final r in results) {
        final alt = r['altitude'] as int;
        dataMap[alt] = _AltitudeData(
          eteMinutes: r['ete_minutes'] as int?,
          fuelGallons: (r['flight_fuel_gallons'] as num?)?.toDouble(),
          avgWindComponent: r['avg_wind_component'] as int?,
          avgGroundspeed: r['avg_groundspeed'] as int?,
        );
      }
      if (mounted) {
        setState(() => _data = dataMap);
        _computeOptimal();
      }
    } catch (_) {
      // Silently fail — rows will show "--"
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _computeOptimal() {
    if (_data.isEmpty) return;

    // Find altitude with lowest ETE
    int? bestAlt;
    int? bestEte;
    int? worstEte;
    double maxWind = 0;

    for (final entry in _data.entries) {
      final ete = entry.value.eteMinutes;
      final wind = entry.value.avgWindComponent;
      if (wind != null) {
        maxWind = math.max(maxWind, wind.abs().toDouble());
      }
      if (ete != null) {
        if (bestEte == null || ete < bestEte) {
          bestEte = ete;
          bestAlt = entry.key;
        }
        if (worstEte == null || ete > worstEte) {
          worstEte = ete;
        }
      }
    }

    if (bestAlt == null || bestEte == null) return;

    // Compare against current altitude if set, otherwise worst
    final currentData = widget.currentAltitude != null
        ? _data[widget.currentAltitude]
        : null;
    final compareEte = currentData?.eteMinutes ?? worstEte ?? bestEte;
    final saved = compareEte - bestEte;
    final compareLabel = currentData != null && widget.currentAltitude != null
        ? _formatAltitude(widget.currentAltitude!)
        : null;

    setState(() {
      _optimalAltitude = bestAlt;
      _timeSavedMinutes = saved;
      _comparedToLabel = compareLabel;
      _maxAbsWind = maxWind > 0 ? maxWind : 1;
    });
  }

  String _formatAltitude(int ft) {
    if (ft >= 18000) {
      return 'FL${ft ~/ 100}';
    }
    return '${_addComma(ft)}\'';
  }

  String _addComma(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }

  String _formatEte(int? minutes) {
    if (minutes == null) return '--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}m';
  }

  String _formatFuel(double? gallons) {
    if (gallons == null) return '--';
    return '${gallons.round()}g';
  }

  @override
  Widget build(BuildContext context) {
    final altitudes = _generateAltitudes();
    final currentDisplay = widget.currentAltitude != null
        ? _addComma(widget.currentAltitude!)
        : '--';

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Altitude',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                currentDisplay,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),

        // Recommendation banner
        if (!_loading && _optimalAltitude != null && _timeSavedMinutes > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppColors.accent.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Optimal: ${_formatAltitude(_optimalAltitude!)}'
                    ' \u2014 saves $_timeSavedMinutes min'
                    '${_comparedToLabel != null ? ' vs $_comparedToLabel' : ''}',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Column headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const SizedBox(
                width: 72,
                child: Text(
                  'ALT',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  'WIND',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(
                width: 50,
                child: Text(
                  'GS',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(
                width: 58,
                child: Text(
                  'ETE',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(
                width: 44,
                child: Text(
                  'FUEL',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 24), // radio column spacer
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),

        // Altitude list
        Expanded(
          child: _loading && _data.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: altitudes.length,
                  itemBuilder: (ctx, i) {
                    final alt = altitudes[i];
                    final data = _data[alt];
                    final isSelected = alt == widget.currentAltitude;
                    final isOptimal = alt == _optimalAltitude;

                    return InkWell(
                      onTap: () => Navigator.pop(context, alt),
                      child: Container(
                        color: isOptimal
                            ? AppColors.accent.withValues(alpha: 0.06)
                            : null,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        child: Row(
                          children: [
                            // Altitude label
                            SizedBox(
                              width: 72,
                              child: Row(
                                children: [
                                  if (isOptimal)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  Text(
                                    _formatAltitude(alt),
                                    style: TextStyle(
                                      color: isOptimal
                                          ? AppColors.accent
                                          : AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Wind component bar
                            Expanded(
                              child: _WindBar(
                                component: data?.avgWindComponent,
                                maxAbsWind: _maxAbsWind,
                              ),
                            ),
                            // Groundspeed
                            SizedBox(
                              width: 50,
                              child: Text(
                                data?.avgGroundspeed != null
                                    ? '${data!.avgGroundspeed}'
                                    : '--',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            // ETE
                            SizedBox(
                              width: 58,
                              child: Text(
                                _formatEte(data?.eteMinutes),
                                style: TextStyle(
                                  color: isOptimal
                                      ? AppColors.accent
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            // Fuel
                            SizedBox(
                              width: 44,
                              child: Text(
                                _formatFuel(data?.fuelGallons),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Radio
                            _RadioDot(selected: isSelected),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        const Divider(height: 1, color: AppColors.divider),

        // Bottom filter bar: VFR/IFR + West/East/All
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _FilterChip(
                  label: 'VFR',
                  selected: _rule == _RuleFilter.vfr,
                  onTap: () {
                    setState(() => _rule = _RuleFilter.vfr);
                    _fetchData();
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'IFR',
                  selected: _rule == _RuleFilter.ifr,
                  onTap: () {
                    setState(() => _rule = _RuleFilter.ifr);
                    _fetchData();
                  },
                ),
                const SizedBox(width: 16),
                _FilterChip(
                  label: 'West',
                  selected: _direction == _DirectionFilter.west,
                  onTap: () {
                    setState(() => _direction = _DirectionFilter.west);
                    _fetchData();
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'East',
                  selected: _direction == _DirectionFilter.east,
                  onTap: () {
                    setState(() => _direction = _DirectionFilter.east);
                    _fetchData();
                  },
                ),
                const SizedBox(width: 6),
                _FilterChip(
                  label: 'All',
                  selected: _direction == _DirectionFilter.all,
                  onTap: () {
                    setState(() => _direction = _DirectionFilter.all);
                    _fetchData();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AltitudeData {
  final int? eteMinutes;
  final double? fuelGallons;
  final int? avgWindComponent; // negative = headwind, positive = tailwind
  final int? avgGroundspeed;

  const _AltitudeData({
    this.eteMinutes,
    this.fuelGallons,
    this.avgWindComponent,
    this.avgGroundspeed,
  });
}

/// Visual wind bar: text label + proportional colored bar.
class _WindBar extends StatelessWidget {
  final int? component;
  final double maxAbsWind;

  const _WindBar({required this.component, required this.maxAbsWind});

  @override
  Widget build(BuildContext context) {
    if (component == null) {
      return const Text(
        '--',
        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
      );
    }

    final label = component == 0
        ? '0kt'
        : '${component! > 0 ? '+' : ''}${component}kt';
    final color = component! > 0
        ? AppColors.success
        : component! < 0
            ? AppColors.error
            : AppColors.textSecondary;
    final fraction = component!.abs() / maxAbsWind;

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: color.withValues(alpha: 0.25),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;

  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.textMuted,
          width: 2,
        ),
        color: selected ? AppColors.accent : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceLight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.textSecondary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
