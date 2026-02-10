import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/aircraft.dart';
import '../../models/weight_balance.dart';
import '../../services/aircraft_providers.dart';
import '../../services/wb_providers.dart';
import '../../services/wb_calculator.dart';
import 'widgets/wb_alert_banner.dart';
import 'widgets/wb_weight_summary_bar.dart';
import 'widgets/wb_stations_list.dart';
import 'widgets/wb_envelope_chart.dart';
import 'widgets/wb_debug_panel.dart';

class WBScreen extends ConsumerStatefulWidget {
  final int? aircraftId;

  const WBScreen({super.key, this.aircraftId});

  @override
  ConsumerState<WBScreen> createState() => _WBScreenState();
}

class _WBScreenState extends ConsumerState<WBScreen> {
  int? _selectedAircraftId;
  bool _aircraftInitialized = false;
  WBProfile? _selectedProfile;
  Map<int, double> _stationWeights = {};
  double _startingFuelGallons = 0;
  double _endingFuelGallons = 0;
  WBCalculationResult? _calcResult;
  bool _showDebug = false;

  int? get _activeAircraftId => _selectedAircraftId ?? widget.aircraftId;

  /// Whether this screen was opened from an aircraft detail (has explicit aircraftId)
  bool get _isFromAircraft => widget.aircraftId != null;

  @override
  Widget build(BuildContext context) {
    // If we have an explicit aircraftId, initialize immediately
    if (!_aircraftInitialized && widget.aircraftId != null) {
      _selectedAircraftId = widget.aircraftId;
      _aircraftInitialized = true;
    }

    // If no explicit aircraftId, try to load the default aircraft
    if (!_aircraftInitialized && widget.aircraftId == null) {
      final defaultAsync = ref.watch(defaultAircraftProvider);
      defaultAsync.whenData((aircraft) {
        if (!_aircraftInitialized && aircraft != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedAircraftId = aircraft.id;
                _aircraftInitialized = true;
              });
            }
          });
        }
      });
      // Mark initialized even if no default aircraft exists
      if (defaultAsync.hasValue && !_aircraftInitialized) {
        _aircraftInitialized = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: _isFromAircraft
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text('Weight & Balance'),
        centerTitle: true,
        actions: [
          if (_selectedProfile != null && _activeAircraftId != null)
            IconButton(
              icon: Icon(Icons.bug_report,
                  size: 20,
                  color: _showDebug ? Colors.orange : AppColors.textMuted),
              onPressed: () => setState(() => _showDebug = !_showDebug),
            ),
          if (_selectedProfile != null && _activeAircraftId != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () {
                if (_selectedProfile?.id != null) {
                  context.push(
                      '/aircraft/$_activeAircraftId/wb/profiles/${_selectedProfile!.id}/edit');
                }
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final aircraftListAsync = ref.watch(aircraftListProvider(''));

    return aircraftListAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error loading aircraft',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
      data: (aircraftList) {
        if (aircraftList.isEmpty) {
          return _buildNoAircraft();
        }

        // If still no selection, pick the first aircraft
        if (_selectedAircraftId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedAircraftId == null) {
              setState(() {
                _selectedAircraftId = aircraftList.first.id;
                _aircraftInitialized = true;
              });
            }
          });
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Aircraft selector (always shown when accessed from tab)
            if (!_isFromAircraft)
              _buildAircraftSelector(aircraftList),
            // W&B content
            Expanded(child: _buildContent()),
          ],
        );
      },
    );
  }

  Widget _buildNoAircraft() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.airplanemode_inactive,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No aircraft configured',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add an aircraft first to use\nWeight & Balance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/aircraft/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Aircraft'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAircraftSelector(List<Aircraft> aircraftList) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedAircraftId,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surfaceLight,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          labelText: 'Aircraft',
          labelStyle: const TextStyle(
              color: AppColors.textMuted, fontSize: 13),
        ),
        dropdownColor: AppColors.surface,
        items: aircraftList
            .map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    '${a.tailNumber} — ${a.aircraftType}',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                  ),
                ))
            .toList(),
        onChanged: (id) {
          if (id != null && id != _selectedAircraftId) {
            setState(() {
              _selectedAircraftId = id;
              _selectedProfile = null;
              _stationWeights = {};
              _startingFuelGallons = 0;
              _endingFuelGallons = 0;
              _calcResult = null;
            });
          }
        },
      ),
    );
  }

  Widget _buildContent() {
    final aircraftId = _activeAircraftId;
    if (aircraftId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final profilesAsync = ref.watch(wbProfilesProvider(aircraftId));

    return profilesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildNoProfile(),
      data: (profiles) {
        if (profiles.isEmpty) {
          return _buildNoProfile();
        }

        // Auto-select the default or first profile
        if (_selectedProfile == null) {
          final defaultP = profiles.where((p) => p.isDefault).firstOrNull;
          _selectedProfile = defaultP ?? profiles.first;
          _loadProfileDetail();
        }

        return _buildLoadedContent(profiles);
      },
    );
  }

  Widget _buildNoProfile() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.balance, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No W&B profile configured',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a profile to start calculating\nweight and balance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createProfile,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedContent(List<WBProfile> profiles) {
    final aircraftId = _activeAircraftId!;
    final profile = _selectedProfile;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check if profile has stations loaded (from detail endpoint)
    if (profile.stations.isEmpty && profile.id != null) {
      final profileAsync = ref.watch(wbProfileProvider(
          (aircraftId: aircraftId, profileId: profile.id!)));
      return profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error loading profile',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        data: (fullProfile) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedProfile?.id == fullProfile.id) {
              setState(() {
                _selectedProfile = fullProfile;
                _initStationWeights(fullProfile);
                _recompute();
              });
            }
          });
          return _buildProfileBody(fullProfile, profiles);
        },
      );
    }

    return _buildProfileBody(profile, profiles);
  }

  Widget _buildProfileBody(WBProfile profile, List<WBProfile> profiles) {
    final result = _calcResult;

    return ListView(
      children: [
        // Profile selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<int>(
            value: profile.id,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            dropdownColor: AppColors.surface,
            items: profiles
                .map((p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14)),
                    ))
                .toList(),
            onChanged: (id) {
              if (id != null) {
                final newProfile = profiles.firstWhere((p) => p.id == id);
                setState(() {
                  _selectedProfile = newProfile;
                  _stationWeights = {};
                  _startingFuelGallons = 0;
                  _endingFuelGallons = 0;
                  _calcResult = null;
                });
                _loadProfileDetail();
              }
            },
          ),
        ),

        // Alert banner
        if (result != null && !result.isWithinEnvelope)
          WBAlertBanner(result: result, profile: profile),

        // Weight summary bar
        if (result != null)
          WBWeightSummaryBar(result: result, profile: profile),

        // Envelope chart
        if (result != null)
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
        if (result != null && profile.lateralCgEnabled)
          WBEnvelopeChart(
            envelopes: profile.envelopes,
            result: result,
            axis: 'lateral',
            maxLandingWeight: profile.maxLandingWeight,
            maxZeroFuelWeight: profile.maxZeroFuelWeight,
            maxTakeoffWeight: profile.maxTakeoffWeight,
            maxRampWeight: profile.maxRampWeight,
          ),

        // Debug panel
        if (_showDebug && _activeAircraftId != null)
          Builder(builder: (context) {
            final aircraft = ref
                .read(aircraftDetailProvider(_activeAircraftId!))
                .value;
            final fuelWpg = aircraft?.fuelWeightPerGallon ?? 6.7;
            return WBDebugPanel(
              profile: profile,
              stationWeights: _stationWeights,
              startingFuelGallons: _startingFuelGallons,
              endingFuelGallons: _endingFuelGallons,
              fuelWeightPerGallon: fuelWpg,
              result: result,
            );
          }),

        // Fuel inputs
        ..._buildFuelRows(),

        // Station loading (non-fuel stations only — fuel managed by starting fuel)
        WBStationsList(
          profile: profile,
          stationWeights: _stationWeights,
          hideFuelStations: true,
          onWeightChanged: (change) {
            setState(() {
              _stationWeights[change.stationId] = change.weight;
            });
            _recompute();
          },
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  List<Widget> _buildFuelRows() {
    final tripFuel = (_startingFuelGallons - _endingFuelGallons)
        .clamp(0.0, double.infinity);

    return [
      _buildFuelInputRow(
        label: 'Starting Fuel',
        gallons: _startingFuelGallons,
        onTap: () => _editFuelGallons(
          title: 'Starting Fuel',
          hint: 'Total fuel at departure',
          currentValue: _startingFuelGallons,
          onSaved: (val) {
            setState(() => _startingFuelGallons = val);
            _recompute();
          },
        ),
      ),
      _buildFuelInputRow(
        label: 'Ending Fuel',
        gallons: _endingFuelGallons,
        onTap: () => _editFuelGallons(
          title: 'Ending Fuel',
          hint: 'Fuel remaining at landing',
          currentValue: _endingFuelGallons,
          onSaved: (val) {
            setState(() => _endingFuelGallons = val);
            _recompute();
          },
        ),
      ),
      // Computed trip fuel (read-only)
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

  Widget _buildFuelInputRow({
    required String label,
    required double gallons,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textSecondary)),
            ),
            Text(
              gallons > 0
                  ? '${gallons.toStringAsFixed(1)} gal'
                  : '0 gal',
              style: TextStyle(
                fontSize: 14,
                color: gallons > 0 ? AppColors.accent : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _initStationWeights(WBProfile profile) {
    if (_stationWeights.isEmpty) {
      // Init non-fuel stations from defaults
      for (final station in profile.stations) {
        if (station.category != 'fuel' &&
            station.defaultWeight != null &&
            station.defaultWeight! > 0) {
          _stationWeights[station.id!] = station.defaultWeight!;
        }
      }
      // Init starting fuel from fuel station defaults
      final aircraftId = _activeAircraftId;
      if (aircraftId != null && _startingFuelGallons == 0) {
        final aircraft =
            ref.read(aircraftDetailProvider(aircraftId)).value;
        final fuelWpg = aircraft?.fuelWeightPerGallon ?? 6.7;
        double totalFuelWeight = 0;
        for (final station in profile.stations) {
          if (station.category == 'fuel' &&
              station.defaultWeight != null &&
              station.defaultWeight! > 0) {
            totalFuelWeight += station.defaultWeight!;
          }
        }
        if (totalFuelWeight > 0) {
          _startingFuelGallons =
              (totalFuelWeight / fuelWpg * 10).roundToDouble() / 10;
        }
      }
    }
  }

  void _recompute() {
    final aircraftId = _activeAircraftId;
    final profile = _selectedProfile;
    if (aircraftId == null || profile == null || profile.stations.isEmpty) {
      return;
    }

    final aircraft = ref.read(aircraftDetailProvider(aircraftId)).value;
    final fuelWpg = aircraft?.fuelWeightPerGallon ?? 6.7;

    // Only pass non-fuel station loads — fuel is handled by the calculator
    // via startingFuelGallons / endingFuelGallons
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

  void _loadProfileDetail() {
    final aircraftId = _activeAircraftId;
    if (aircraftId != null && _selectedProfile?.id != null) {
      ref.invalidate(wbProfileProvider(
          (aircraftId: aircraftId, profileId: _selectedProfile!.id!)));
    }
  }

  Future<void> _createProfile() async {
    final aircraftId = _activeAircraftId;
    if (aircraftId == null) return;

    final nameController = TextEditingController(text: 'Standard');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('New W&B Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, nameController.text),
                  child: const Text('Create',
                      style: TextStyle(color: AppColors.accent)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration:
                  const InputDecoration(hintText: 'Profile name'),
              onSubmitted: (val) => Navigator.pop(ctx, val),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final service = ref.read(wbServiceProvider);
        final aircraft =
            ref.read(aircraftDetailProvider(aircraftId)).value;
        final isHelicopter = aircraft?.category == 'helicopter';
        await service.createProfile(aircraftId, {
          'name': result,
          'is_default': true,
          'empty_weight': aircraft?.emptyWeight ?? 0,
          'empty_weight_arm': 0,
          'max_takeoff_weight': aircraft?.maxTakeoffWeight ?? 0,
          'max_landing_weight': aircraft?.maxLandingWeight ?? 0,
          if (isHelicopter) 'lateral_cg_enabled': true,
        });
        ref.invalidate(wbProfilesProvider(aircraftId));
        setState(() {
          _selectedProfile = null;
          _stationWeights = {};
          _calcResult = null;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create profile: $e')),
          );
        }
      }
    }
  }

  Future<void> _editFuelGallons({
    required String title,
    required String hint,
    required double currentValue,
    required ValueChanged<double> onSaved,
  }) async {
    final controller = TextEditingController(
        text: currentValue > 0 ? currentValue.toStringAsFixed(1) : '');

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                        ctx, double.tryParse(controller.text) ?? 0);
                  },
                  child: const Text('Done',
                      style: TextStyle(color: AppColors.accent)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                suffixText: 'gal',
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx, double.tryParse(val) ?? 0);
              },
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      onSaved(result);
    }
  }
}
