import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/aircraft.dart';
import '../../models/flight.dart';
import '../../models/performance_data.dart';
import '../../services/flight_providers.dart';
import '../../services/aircraft_providers.dart';
import '../../services/told_providers.dart';
import '../../services/told_calculator.dart';
import 'widgets/told_stats_bar.dart';
import 'widgets/told_weather_section.dart';
import 'widgets/told_runway_selector.dart';
import 'widgets/flight_section_header.dart';

class ToldScreen extends ConsumerStatefulWidget {
  final int flightId;
  final ToldMode mode;

  const ToldScreen({super.key, required this.flightId, required this.mode});

  @override
  ConsumerState<ToldScreen> createState() => _ToldScreenState();
}

class _ToldScreenState extends ConsumerState<ToldScreen> {
  bool _initialized = false;

  ToldParams get _params =>
      ToldParams(flightId: widget.flightId, mode: widget.mode);

  @override
  Widget build(BuildContext context) {
    final flightAsync = ref.watch(flightDetailProvider(widget.flightId));

    return flightAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (flight) {
        if (flight == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Flight not found')),
          );
        }
        return _buildWithFlight(flight);
      },
    );
  }

  Widget _buildWithFlight(Flight flight) {
    if (flight.aircraftId == null) {
      return Scaffold(
        appBar: _buildAppBar(flight),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No aircraft assigned to this flight',
              style: TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final aircraftAsync = ref.watch(aircraftDetailProvider(flight.aircraftId!));

    return aircraftAsync.when(
      loading: () => Scaffold(
        appBar: _buildAppBar(flight),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: _buildAppBar(flight),
        body: Center(child: Text('Error loading aircraft: $e')),
      ),
      data: (aircraft) {
        if (aircraft == null) {
          return Scaffold(
            appBar: _buildAppBar(flight),
            body: const Center(child: Text('Aircraft not found')),
          );
        }
        return _buildWithAircraft(flight, aircraft);
      },
    );
  }

  Widget _buildWithAircraft(Flight flight, Aircraft aircraft) {
    final profile = aircraft.defaultProfile;
    final perfJson = widget.mode == ToldMode.takeoff
        ? profile?.takeoffData
        : profile?.landingData;

    if (profile == null || perfJson == null) {
      return Scaffold(
        appBar: _buildAppBar(flight),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No performance data available.\nAdd performance data to the aircraft\'s profile.',
              style: TextStyle(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final perfData = PerformanceData.fromJson(perfJson);
    final notifier = ref.watch(toldNotifierProvider(_params));

    // Initialize: load airport data
    if (!_initialized) {
      _initialized = true;
      final airportId = widget.mode == ToldMode.takeoff
          ? flight.departureIdentifier
          : flight.destinationIdentifier;
      if (airportId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifier.loadAirportData(airportId);
        });
      }
    }

    // Compute weight
    final emptyWeight = aircraft.emptyWeight ?? 0;
    final payloadWeight =
        flight.peopleCount * flight.avgPersonWeight + flight.cargoWeight;
    final fuelWeightPerGal = aircraft.fuelWeightPerGallon ?? 6.7;
    final startFuel = flight.startFuelGallons ?? 0;
    final fuelWeight = startFuel * fuelWeightPerGal;

    double currentWeight;
    double? maxWeight;
    String? weightLimitType;

    if (widget.mode == ToldMode.takeoff) {
      currentWeight = emptyWeight + payloadWeight + fuelWeight;
      maxWeight = aircraft.maxTakeoffWeight;
      weightLimitType = 'Structural';
    } else {
      final flightFuel = flight.flightFuelGallons ?? 0;
      currentWeight =
          emptyWeight + payloadWeight + (startFuel - flightFuel) * fuelWeightPerGal;
      maxWeight = aircraft.maxLandingWeight ?? aircraft.maxTakeoffWeight;
      weightLimitType = 'Structural';
    }

    final isOverweight = maxWeight != null && currentWeight > maxWeight;

    return ListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        final toldState = notifier.state;

        // Trigger recalculation after airport data is loaded
        if (toldState.airportData != null && toldState.result == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            notifier.recalculate(
              performanceData: perfData,
              weightLbs: currentWeight,
              maxWeight: maxWeight,
              weightLimitType: weightLimitType,
            );
          });
        }

        final result = toldState.result;

        return Scaffold(
          appBar: _buildAppBar(flight),
          body: Column(
            children: [
              ToldStatsBar(result: result, mode: widget.mode),
              if (maxWeight != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: isOverweight
                      ? AppColors.error.withValues(alpha: 0.15)
                      : AppColors.surface,
                  child: Text(
                    '${widget.mode == ToldMode.takeoff ? 'MTOW' : 'MLW'}: '
                    '${maxWeight.round()} lbs | '
                    '${weightLimitType ?? ''} Weight Limited',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isOverweight
                          ? AppColors.error
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  children: [
                    _buildRunwaySection(toldState, notifier, perfData),
                    ToldWeatherSection(
                      toldState: toldState,
                      notifier: notifier,
                    ),
                    _buildConfigSection(
                        toldState, notifier, perfData, currentWeight),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Displayed distances are POH distances multiplied by safety distance factor.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: OutlinedButton(
                        onPressed: () {
                          notifier.reset();
                          setState(() => _initialized = false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.divider),
                        ),
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(Flight flight) {
    final modeLabel = widget.mode == ToldMode.takeoff ? 'Takeoff' : 'Landing';

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Text(modeLabel),
      centerTitle: true,
      leadingWidth: 80,
      actions: [
        TextButton(
          onPressed: () {
            final modeStr =
                widget.mode == ToldMode.takeoff ? 'takeoff' : 'landing';
            context.push(
                '/flights/${widget.flightId}/told?mode=$modeStr');
          },
          child: const Text(
            'TOLD',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRunwaySection(
    ToldState toldState,
    ToldStateNotifier notifier,
    PerformanceData perfData,
  ) {
    final rwyId = toldState.runwayEndIdentifier;
    final heading = toldState.runwayHeading;
    final length = toldState.runwayLengthFt;
    final slope = toldState.runwaySlope;

    // Wind components
    final windDir = toldState.windDir ?? 0;
    final windSpd = toldState.windSpeed ?? 0;
    int? headwind, crosswind;
    bool isHeadwind = true;
    if (heading != null) {
      final hw = ToldCalculator.headwindComponent(windDir, windSpd, heading);
      final xw = ToldCalculator.crosswindComponent(windDir, windSpd, heading);
      isHeadwind = hw >= 0;
      headwind = hw.abs().round();
      crosswind = xw.round();
    }

    final distLabel = widget.mode == ToldMode.takeoff ? 'TORA' : 'LDA';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Runway'),
        // Runway selector row
        InkWell(
          onTap: () {
            if (toldState.airportData != null) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ToldRunwaySelector(
                  airportData: toldState.airportData!,
                  toldState: toldState,
                  notifier: notifier,
                  mode: widget.mode,
                ),
              );
            }
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Runway',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                Text(
                  rwyId != null ? 'Rwy $rwyId' : 'Select',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.accent),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        // Wind components
        if (headwind != null && crosswind != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Wind',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Icon(
                  isHeadwind ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 14,
                  color: isHeadwind ? AppColors.vfr : AppColors.error,
                ),
                const SizedBox(width: 2),
                Text(
                  '$headwind kt ${isHeadwind ? 'head' : 'tail'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isHeadwind ? AppColors.vfr : AppColors.error,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_back,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 2),
                Text(
                  '$crosswind kt xwind',
                  style: TextStyle(
                    fontSize: 13,
                    color: crosswind <= 15
                        ? AppColors.textSecondary
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        // Available distance
        if (length != null)
          _fieldRow(distLabel, '${_fmtNum(length.round())}\''),
        if (slope != null) _fieldRow('Slope', '$slope%'),
        // Surface selector
        _surfaceRow(toldState, notifier),
      ],
    );
  }

  Widget _surfaceRow(ToldState toldState, ToldStateNotifier notifier) {
    final surfaces = {
      'paved_dry': 'Paved / Dry',
      'paved_wet': 'Paved / Wet',
      'grass_dry': 'Grass / Dry',
      'grass_wet': 'Grass / Wet',
    };

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.background,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Runway Surface',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                for (final entry in surfaces.entries)
                  ListTile(
                    title: Text(entry.value),
                    trailing: entry.key == toldState.surfaceType
                        ? const Icon(Icons.check, color: AppColors.accent)
                        : null,
                    onTap: () {
                      notifier.setSurfaceType(entry.key);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Surface',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
            Text(
              surfaces[toldState.surfaceType] ?? toldState.surfaceType,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection(
    ToldState toldState,
    ToldStateNotifier notifier,
    PerformanceData perfData,
    double weight,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Aircraft Configuration'),
        _fieldRow('Weight', '${weight.round()} lbs'),
        // Flaps picker
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.background,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Flap Setting',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    for (final flap in perfData.flapSettings)
                      ListTile(
                        title: Text(flap.name),
                        trailing: flap.code == toldState.flapCode
                            ? const Icon(Icons.check, color: AppColors.accent)
                            : null,
                        onTap: () {
                          notifier.setFlapCode(flap.code);
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Flaps',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                Text(
                  perfData.flapSettings
                          .where((f) => f.code == toldState.flapCode)
                          .firstOrNull
                          ?.name ??
                      'Select',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.accent),
                ),
              ],
            ),
          ),
        ),
        // Safety factor
        InkWell(
          onTap: () => _editSafetyFactor(toldState, notifier),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Safety Distance Factor',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                Text(
                  '${toldState.safetyFactor.toStringAsFixed(1)}x',
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.accent),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _editSafetyFactor(ToldState toldState, ToldStateNotifier notifier) {
    final controller =
        TextEditingController(text: toldState.safetyFactor.toString());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Safety Distance Factor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Multiplier applied to all computed distances (1.0 = POH values)',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              onSubmitted: (val) {
                final parsed = double.tryParse(val);
                if (parsed != null && parsed > 0) {
                  notifier.setSafetyFactor(parsed);
                }
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final parsed = double.tryParse(controller.text);
                    if (parsed != null && parsed > 0) {
                      notifier.setSafetyFactor(parsed);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  static String _fmtNum(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]},',
        );
  }
}
