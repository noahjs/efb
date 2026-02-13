import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_client.dart';

/// Standard altitude picker that shows ETE and fuel for each altitude option.
/// Matches the hemispheric altitude rules for VFR/IFR and East/West headings.
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
      if (mounted) setState(() => _data = dataMap);
    } catch (_) {
      // Silently fail — rows will show "--"
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  String _formatWind(int? component) {
    if (component == null) return '--';
    if (component == 0) return '0kt';
    // Positive = tailwind, negative = headwind
    final prefix = component > 0 ? '+' : '';
    return '$prefix${component}kt';
  }

  Color _windColor(int? component) {
    if (component == null) return AppColors.textMuted;
    if (component > 0) return AppColors.success; // tailwind = green
    if (component < 0) return AppColors.error; // headwind = red
    return AppColors.textSecondary;
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

                    return InkWell(
                      onTap: () => Navigator.pop(context, alt),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            // Altitude label
                            SizedBox(
                              width: 80,
                              child: Text(
                                _formatAltitude(alt),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            // Wind component (headwind/tailwind)
                            Expanded(
                              child: Text(
                                _formatWind(data?.avgWindComponent),
                                style: TextStyle(
                                  color: _windColor(data?.avgWindComponent),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            // ETE
                            SizedBox(
                              width: 70,
                              child: Text(
                                _formatEte(data?.eteMinutes),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Fuel
                            SizedBox(
                              width: 50,
                              child: Text(
                                _formatFuel(data?.fuelGallons),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 16),
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
