import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/weight_balance.dart';
import '../../../services/api_client.dart';
import '../../../services/wb_providers.dart';
import '../../../services/wb_calculator.dart';
import '../../../services/aircraft_providers.dart';
import '../../../services/flight_providers.dart';
import '../widgets/wb_weight_summary_bar.dart';
import '../widgets/wb_envelope_chart.dart';
import '../widgets/flight_wb_station_row.dart';

class FlightWBScreen extends ConsumerStatefulWidget {
  final int flightId;

  const FlightWBScreen({super.key, required this.flightId});

  @override
  ConsumerState<FlightWBScreen> createState() => _FlightWBScreenState();
}

class _FlightWBScreenState extends ConsumerState<FlightWBScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  WBProfile? _profile;
  int? _scenarioId;
  int? _aircraftId;
  Map<int, double> _stationWeights = {};
  Map<int, String?> _occupantNames = {};
  Map<int, bool> _isPersonFlags = {};
  double _startingFuelGallons = 0;
  double _endingFuelGallons = 0;
  WBCalculationResult? _calcResult;
  Timer? _saveTimer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    // Flush pending save and wait for it to complete
    _saveTimer?.cancel();
    await _autoSave();
    // Now invalidate so flight details re-fetches with fresh backend data
    ref.invalidate(flightWBProvider(widget.flightId));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final wbAsync = ref.watch(flightWBProvider(widget.flightId));

    return wbAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const Text('Weight & Balance'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const Text('Weight & Balance'),
        ),
        body: _buildError(e),
      ),
      data: (data) {
        if (!_initialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_initialized) {
              _initFromScenario(data.scenario, data.profile);
            }
          });
        }
        return _buildScaffold(data.profile);
      },
    );
  }

  Future<void> _initFromScenario(WBScenario scenario, WBProfile profile) async {
    _initialized = true; // Prevent re-entry
    _profile = profile;
    _scenarioId = scenario.id;
    _aircraftId = profile.aircraftId;

    // Populate station weights from scenario loads
    _stationWeights = {};
    _occupantNames = {};
    _isPersonFlags = {};
    for (final load in scenario.stationLoads) {
      _stationWeights[load.stationId] = load.weight;
      if (load.occupantName != null) {
        _occupantNames[load.stationId] = load.occupantName;
      }
    }
    // Restore isPerson flags from saved loads, defaulting seats to person
    for (final station in profile.stations) {
      if (station.category == 'seat' && station.id != null) {
        final load = scenario.stationLoads
            .where((l) => l.stationId == station.id)
            .firstOrNull;
        _isPersonFlags[station.id!] = load?.isPerson ?? true;
      }
    }

    // Default to scenario fuel values for immediate display
    _startingFuelGallons = scenario.startingFuelGallons ?? 0;
    _endingFuelGallons = scenario.endingFuelGallons ?? 0;
    _recompute();

    // Fetch fresh flight data from API to override fuel (handles sync from flight detail)
    try {
      final api = ref.read(apiClientProvider);
      final flightJson = await api.getFlight(widget.flightId);
      if (!mounted) return;

      final startFuel = (flightJson['start_fuel_gallons'] as num?)?.toDouble();
      final endFuel = (flightJson['fuel_at_shutdown_gallons'] as num?)?.toDouble() ?? 0;

      bool changed = false;
      if (startFuel != null) {
        _startingFuelGallons = startFuel;
        changed = true;
      }
      if (endFuel > 0) {
        _endingFuelGallons = endFuel;
        changed = true;
      }
      if (changed) {
        _recompute();
      }
    } catch (_) {
      // Fall back to scenario values (already set)
    }
  }

  Widget _buildError(Object error) {
    final msg = error.toString();
    final isNoProfile = msg.contains('No W&B profile');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.balance, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            isNoProfile
                ? 'No W&B profile configured'
                : 'Error loading W&B',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            isNoProfile
                ? 'Configure a W&B profile for this\naircraft to use flight W&B.'
                : msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 13),
          ),
          if (isNoProfile && _aircraftId != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  context.push('/aircraft/$_aircraftId/wb'),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Configure W&B'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScaffold(WBProfile profile) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
        ),
        title: const Text('Weight & Balance'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Loading'),
            Tab(text: 'Results'),
          ],
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textMuted,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLoadingTab(profile),
          _buildResultsTab(profile),
        ],
      ),
    ),
    );
  }

  // ===== LOADING TAB =====

  Widget _buildLoadingTab(WBProfile profile) {
    final result = _calcResult;

    // Sort non-fuel stations by arm (front to back)
    final stations = profile.stations
        .where((s) => s.category != 'fuel')
        .toList()
      ..sort((a, b) => a.arm.compareTo(b.arm));

    // Group stations by arm value for side-by-side layout
    final groupedByArm = <double, List<WBStation>>{};
    for (final s in stations) {
      groupedByArm.putIfAbsent(s.arm, () => []).add(s);
    }
    final armGroups = groupedByArm.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView(
      children: [
        // Status pill
        if (result != null) _buildStatusPill(result),

        // Stations sorted by arm
        if (stations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
            child: Text(
              'STATIONS (FRONT TO BACK)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: AppColors.textMuted,
              ),
            ),
          ),
        for (final group in armGroups)
          if (group.value.length == 2)
            // Two stations at same arm — render side-by-side
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      group.value.first.groupName ??
                          'Arm ${group.key.toStringAsFixed(1)} in',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (int i = 0; i < 2; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: FlightWBStationRow(
                            station: group.value[i],
                            weight: _stationWeights[group.value[i].id] ?? 0,
                            occupantName: _occupantNames[group.value[i].id],
                            isPerson: _isPersonFlags[group.value[i].id] ?? false,
                            compact: true,
                            onWeightChanged: (w) {
                              setState(() =>
                                  _stationWeights[group.value[i].id!] = w);
                              _onChanged();
                            },
                            onOccupantNameChanged: (name) {
                              setState(() =>
                                  _occupantNames[group.value[i].id!] = name);
                              _onChanged();
                            },
                            onIsPersonChanged: (v) {
                              setState(() =>
                                  _isPersonFlags[group.value[i].id!] = v);
                              _onChanged();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            )
          else
            // Single station (or 3+)
            for (final station in group.value)
              if (station.category == 'baggage')
                // Baggage gets compact card style at full width
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: FlightWBStationRow(
                    station: station,
                    weight: _stationWeights[station.id] ?? 0,
                    occupantName: _occupantNames[station.id],
                    isPerson: _isPersonFlags[station.id] ?? false,
                    compact: true,
                    onWeightChanged: (w) {
                      setState(() => _stationWeights[station.id!] = w);
                      _onChanged();
                    },
                    onOccupantNameChanged: (name) {
                      setState(() => _occupantNames[station.id!] = name);
                      _onChanged();
                    },
                    onIsPersonChanged: (v) {
                      setState(() => _isPersonFlags[station.id!] = v);
                      _onChanged();
                    },
                  ),
                )
              else
                FlightWBStationRow(
                  station: station,
                  weight: _stationWeights[station.id] ?? 0,
                  occupantName: _occupantNames[station.id],
                  isPerson: _isPersonFlags[station.id] ?? false,
                  onWeightChanged: (w) {
                    setState(() => _stationWeights[station.id!] = w);
                    _onChanged();
                  },
                  onOccupantNameChanged: (name) {
                    setState(() => _occupantNames[station.id!] = name);
                    _onChanged();
                  },
                  onIsPersonChanged: (v) {
                    setState(() => _isPersonFlags[station.id!] = v);
                    _onChanged();
                  },
                ),

        // Fuel section (after stations)
        ..._buildFuelRows(),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStatusPill(WBCalculationResult result) {
    final ok = result.isWithinEnvelope;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ok
            ? AppColors.success.withValues(alpha: 0.15)
            : AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.warning,
            size: 18,
            color: ok ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(
            ok ? 'Within Limits' : 'Exceeds Limits',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ok ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  // Fuel preset helper values from aircraft
  double? get _topOffGallons {
    final aircraft = _aircraftId != null
        ? ref.read(aircraftDetailProvider(_aircraftId!)).value
        : null;
    return aircraft?.totalUsableFuel;
  }

  double? get _tabsGallons {
    final aircraft = _aircraftId != null
        ? ref.read(aircraftDetailProvider(_aircraftId!)).value
        : null;
    if (aircraft == null) return null;
    final tabsTotal = aircraft.fuelTanks
        .where((t) => t.tabFuelGallons != null)
        .fold<double>(0, (sum, t) => sum + t.tabFuelGallons!);
    return tabsTotal > 0 ? tabsTotal : null;
  }

  double? get _minReqGallons {
    final flight = ref.read(flightDetailProvider(widget.flightId)).value;
    if (flight == null) return null;
    final burn = flight.flightFuelGallons ?? 0;
    final reserve = flight.reserveFuelGallons ?? 0;
    final total = burn + reserve;
    return total > 0 ? total : null;
  }

  String? get _activePreset {
    final topOff = _topOffGallons;
    final tabs = _tabsGallons;
    final minReq = _minReqGallons;
    if (topOff != null && (_startingFuelGallons - topOff).abs() < 0.05) {
      return 'topoff';
    }
    if (tabs != null && (_startingFuelGallons - tabs).abs() < 0.05) {
      return 'tabs';
    }
    if (minReq != null && (_startingFuelGallons - minReq).abs() < 0.05) {
      return 'minreq';
    }
    return null;
  }

  List<Widget> _buildFuelRows() {
    final tripFuel = (_startingFuelGallons - _endingFuelGallons)
        .clamp(0.0, double.infinity);

    return [
      Padding(
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
        child: Text(
          'FUEL',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: AppColors.textMuted,
          ),
        ),
      ),

      // Starting fuel row
      InkWell(
        onTap: _editStartingFuel,
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
                child: Text('Starting Fuel',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
              Text(
                _startingFuelGallons > 0
                    ? '${_startingFuelGallons.toStringAsFixed(1)} gal'
                    : '0 gal',
                style: TextStyle(
                  fontSize: 14,
                  color: _startingFuelGallons > 0
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),

      // Ending fuel (read-only)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text('Ending Fuel',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
            ),
            Text(
              _endingFuelGallons > 0
                  ? '${_endingFuelGallons.toStringAsFixed(1)} gal'
                  : '0 gal',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),

      // Trip fuel (read-only)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text('Trip Fuel (burn)',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMuted)),
            ),
            Text(
              '${tripFuel.toStringAsFixed(1)} gal',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    ];
  }

  Future<void> _editStartingFuel() async {
    final controller = TextEditingController(
        text: _startingFuelGallons > 0
            ? _startingFuelGallons.toStringAsFixed(1)
            : '');

    final topOff = _topOffGallons;
    final tabs = _tabsGallons;
    final minReq = _minReqGallons;
    final active = _activePreset;
    double? result;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => PopScope(
        onPopInvokedWithResult: (didPop, _) {
          result ??= double.tryParse(controller.text);
        },
        child: Padding(
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
              Row(
                children: [
                  const Expanded(
                    child: Text('Starting Fuel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                  ),
                  TextButton(
                    onPressed: () {
                      result = 0;
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done',
                        style: TextStyle(color: AppColors.accent)),
                  ),
                ],
              ),
              // Preset buttons
              if (topOff != null || tabs != null || minReq != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (topOff != null)
                      Expanded(
                        child: _FuelPresetButton(
                          label: 'Top Off',
                          subtitle: '${topOff.toStringAsFixed(1)} gal',
                          isActive: active == 'topoff',
                          onTap: () {
                            result = topOff;
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    if (topOff != null && (tabs != null || minReq != null))
                      const SizedBox(width: 8),
                    if (tabs != null)
                      Expanded(
                        child: _FuelPresetButton(
                          label: 'Tabs',
                          subtitle: '${tabs.toStringAsFixed(1)} gal',
                          isActive: active == 'tabs',
                          onTap: () {
                            result = tabs;
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    if (tabs != null && minReq != null)
                      const SizedBox(width: 8),
                    if (minReq != null)
                      Expanded(
                        child: _FuelPresetButton(
                          label: 'Min Req',
                          subtitle: '${minReq.toStringAsFixed(1)} gal',
                          isActive: active == 'minreq',
                          onTap: () {
                            result = minReq;
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Fuel at departure',
                  suffixText: 'gal',
                ),
                onSubmitted: (_) => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() => _startingFuelGallons = result ?? 0);
      _onChanged();
    }
  }

  // ===== RESULTS TAB =====

  Widget _buildResultsTab(WBProfile profile) {
    final result = _calcResult;

    if (result == null) {
      return const Center(
        child: Text('Enter station weights to see results',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView(
      children: [
        // Status pill
        _buildStatusPill(result),

        // Weight summary bar
        WBWeightSummaryBar(result: result, profile: profile),

        // Envelope chart
        WBEnvelopeChart(
          envelopes: profile.envelopes,
          result: result,
          axis: 'longitudinal',
          maxLandingWeight: profile.maxLandingWeight,
          maxZeroFuelWeight: profile.maxZeroFuelWeight,
          maxTakeoffWeight: profile.maxTakeoffWeight,
          maxRampWeight: profile.maxRampWeight,
        ),

        // Lateral envelope chart (if enabled)
        if (profile.lateralCgEnabled)
          WBEnvelopeChart(
            envelopes: profile.envelopes,
            result: result,
            axis: 'lateral',
            maxLandingWeight: profile.maxLandingWeight,
            maxZeroFuelWeight: profile.maxZeroFuelWeight,
            maxTakeoffWeight: profile.maxTakeoffWeight,
            maxRampWeight: profile.maxRampWeight,
          ),

        // Condition details
        _buildConditionDetails(result, profile),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildConditionDetails(
      WBCalculationResult result, WBProfile profile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'CONDITIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: AppColors.textMuted,
              ),
            ),
          ),
          _conditionRow('ZFW', result.zfwCondition, profile.maxZeroFuelWeight),
          _conditionRow('Ramp', result.rampCondition,
              profile.maxRampWeight ?? profile.maxTakeoffWeight),
          _conditionRow('TOW', result.towCondition, profile.maxTakeoffWeight),
          _conditionRow(
              'LDW', result.ldwCondition, profile.maxLandingWeight),
        ],
      ),
    );
  }

  Widget _conditionRow(
      String label, WBCondition condition, double? limit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            condition.withinLimits
                ? Icons.check_circle
                : Icons.cancel,
            size: 16,
            color: condition.withinLimits
                ? AppColors.success
                : AppColors.error,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
          ),
          Expanded(
            child: Text(
              '${condition.weight.toStringAsFixed(0)} lbs${limit != null ? ' / ${limit.toStringAsFixed(0)}' : ''}',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Text(
            'CG ${condition.cg.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  // ===== COMPUTATION & SAVE =====

  void _recompute() {
    final profile = _profile;
    if (profile == null || profile.stations.isEmpty) return;

    final aircraft = _aircraftId != null
        ? ref.read(aircraftDetailProvider(_aircraftId!)).value
        : null;
    final fuelWpg = aircraft?.fuelWeightPerGallon ?? 6.7;

    final loads = _stationWeights.entries
        .where((e) => e.value > 0)
        .map((e) => StationLoad(stationId: e.key, weight: e.value))
        .toList();

    final result = WBCalculator.compute(
      profile: profile,
      stationLoads: loads,
      fuelWeightPerGallon: fuelWpg,
      startingFuelGallons: _startingFuelGallons,
      endingFuelGallons: _endingFuelGallons,
    );

    setState(() => _calcResult = result);
  }

  void _onChanged() {
    _recompute();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  Future<void> _autoSave() async {
    if (_scenarioId == null || _aircraftId == null || _profile == null) return;

    try {
      final api = ref.read(apiClientProvider);
      final loads = <Map<String, dynamic>>[];
      for (final entry in _stationWeights.entries) {
        final load = <String, dynamic>{
          'station_id': entry.key,
          'weight': entry.value,
        };
        if (_occupantNames[entry.key] != null) {
          load['occupant_name'] = _occupantNames[entry.key];
        }
        if (_isPersonFlags.containsKey(entry.key)) {
          load['is_person'] = _isPersonFlags[entry.key];
        }
        loads.add(load);
      }

      // Save W&B scenario
      await api.updateWBScenario(
        _aircraftId!,
        _profile!.id!,
        _scenarioId!,
        {
          'station_loads': loads,
          'starting_fuel_gallons': _startingFuelGallons,
          'ending_fuel_gallons': _endingFuelGallons,
        },
      );

      // Compute people count, avg person weight, and cargo weight
      final personWeights = <double>[];
      double cargoWeight = 0;

      for (final station in _profile!.stations) {
        if (station.id == null || station.category == 'fuel') continue;
        final w = _stationWeights[station.id] ?? 0;
        if (w <= 0) continue;

        if (station.category == 'seat' && (_isPersonFlags[station.id] ?? true)) {
          // Person in seat
          personWeights.add(w);
        } else {
          // Cargo in seat, baggage, or other
          cargoWeight += w;
        }
      }

      final peopleCount = personWeights.length;
      final avgPersonWeight = peopleCount > 0
          ? (personWeights.reduce((a, b) => a + b) / peopleCount)
              .roundToDouble()
          : 170.0;

      // Sync fuel, people, and weights back to the flight
      final flightService = ref.read(flightServiceProvider);
      await flightService.updateFlight(widget.flightId, {
        'start_fuel_gallons': _startingFuelGallons,
        'fuel_at_shutdown_gallons': _endingFuelGallons,
        'people_count': peopleCount,
        'avg_person_weight': avgPersonWeight,
        'cargo_weight': cargoWeight,
      });
      // Invalidate flight provider so detail page picks up changes
      ref.invalidate(flightDetailProvider(widget.flightId));
    } catch (e) {
      // Silently fail — auto-save is best-effort
    }
  }

}

class _FuelPresetButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const _FuelPresetButton({
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? AppColors.accent.withValues(alpha: 0.5)
                : AppColors.divider,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppColors.accent : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
