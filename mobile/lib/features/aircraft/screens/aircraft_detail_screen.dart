import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/aircraft.dart';
import '../../../services/aircraft_providers.dart';
import '../../../services/wb_providers.dart';
import '../../flights/widgets/flight_section_header.dart';
import '../../flights/widgets/flight_field_row.dart';
import '../../flights/widgets/flight_edit_dialogs.dart';

class AircraftDetailScreen extends ConsumerStatefulWidget {
  final int aircraftId;

  const AircraftDetailScreen({super.key, required this.aircraftId});

  @override
  ConsumerState<AircraftDetailScreen> createState() =>
      _AircraftDetailScreenState();
}

class _AircraftDetailScreenState extends ConsumerState<AircraftDetailScreen> {
  Aircraft? _aircraft;
  bool _loaded = false;
  bool _saving = false;

  void _goBackToList() {
    ref.invalidate(aircraftListProvider(''));
    context.go('/aircraft');
  }

  Future<void> _saveField(Map<String, dynamic> updates) async {
    if (_aircraft?.id == null) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(aircraftServiceProvider);
      final updated =
          await service.updateAircraft(_aircraft!.id!, updates);
      setState(() => _aircraft = updated);
      ref.invalidate(aircraftDetailProvider(widget.aircraftId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final detailAsync =
          ref.watch(aircraftDetailProvider(widget.aircraftId));
      return detailAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goBackToList,
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goBackToList,
            ),
          ),
          body: Center(
            child: Text('Error loading aircraft',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
        data: (aircraft) {
          if (aircraft != null && !_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _aircraft = aircraft;
                _loaded = true;
              });
            });
          }
          return _buildScaffold();
        },
      );
    }
    return _buildScaffold();
  }

  Widget _buildScaffold() {
    final a = _aircraft;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBackToList,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToList,
        ),
        title: Text(a.tailNumber),
        centerTitle: true,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        children: [
          // General section
          const FlightSectionHeader(title: 'General'),
          FlightFieldRow(
            label: 'Tail Number',
            value: a.tailNumber,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Tail Number',
                  currentValue: a.tailNumber,
                  hintText: 'e.g. N12345');
              if (result != null) {
                _saveField({'tail_number': result.toUpperCase()});
              }
            },
          ),
          FlightFieldRow(
            label: 'Aircraft Type',
            value: a.aircraftType,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Aircraft Type',
                  currentValue: a.aircraftType,
                  hintText: 'e.g. TBM 960');
              if (result != null) {
                _saveField({'aircraft_type': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'ICAO Type',
            value: a.icaoTypeCode ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'ICAO Type Code',
                  currentValue: a.icaoTypeCode ?? '',
                  hintText: 'e.g. TBM9');
              if (result != null) {
                _saveField({'icao_type_code': result.toUpperCase()});
              }
            },
          ),
          FlightFieldRow(
            label: 'Category',
            value: a.category,
            onTap: () async {
              final result = await showPickerSheet(context,
                  title: 'Category',
                  options: [
                    'landplane',
                    'seaplane',
                    'amphibian',
                    'helicopter',
                  ],
                  currentValue: a.category);
              if (result != null) {
                _saveField({'category': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Engine Type',
            value: _engineTypeDisplay(a.engineType),
            onTap: () async {
              final result = await showPickerSheet(context,
                  title: 'Engine Type',
                  options: ['piston', 'turboprop', 'turbojet', 'turboshaft'],
                  currentValue: a.engineType ?? '');
              if (result != null) {
                _saveField({'engine_type': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Number of Engines',
            value: '${a.numEngines ?? 1}',
            onTap: () async {
              final result = await showPickerSheet(context,
                  title: 'Number of Engines',
                  options: ['1', '2', '3', '4'],
                  currentValue: '${a.numEngines ?? 1}');
              if (result != null) {
                _saveField({'num_engines': int.parse(result)});
              }
            },
          ),
          FlightFieldRow(
            label: 'Pressurized',
            value: a.pressurized ? 'Yes' : 'No',
            onTap: () => _saveField({'pressurized': !a.pressurized}),
          ),
          FlightFieldRow(
            label: 'Service Ceiling',
            value: a.serviceCeiling != null
                ? '${_formatAltitude(a.serviceCeiling!)} ft'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Service Ceiling',
                  currentValue: a.serviceCeiling?.toDouble(),
                  hintText: 'Feet MSL',
                  suffix: 'ft');
              if (result != null) {
                _saveField({'service_ceiling': result.round()});
              }
            },
          ),
          FlightFieldRow(
            label: 'Call Sign',
            value: a.callSign ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Call Sign',
                  currentValue: a.callSign ?? '',
                  hintText: 'Optional');
              if (result != null) {
                _saveField({'call_sign': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Home Airport',
            value: a.homeAirport ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Home Airport',
                  currentValue: a.homeAirport ?? '',
                  hintText: 'e.g. BJC');
              if (result != null) {
                _saveField({'home_airport': result.toUpperCase()});
              }
            },
          ),
          FlightFieldRow(
            label: 'Color',
            value: a.color ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Color',
                  currentValue: a.color ?? '',
                  hintText: 'e.g. White/Blue');
              if (result != null) {
                _saveField({'color': result});
              }
            },
          ),

          // Performance section
          const FlightSectionHeader(title: 'Performance'),
          FlightFieldRow(
            label: 'Performance Profiles',
            value: '${a.performanceProfiles.length} profile${a.performanceProfiles.length == 1 ? '' : 's'}',
            showChevron: true,
            onTap: () =>
                context.go('/aircraft/${a.id}/profiles'),
          ),

          FlightFieldRow(
            label: 'Weight & Balance',
            value: '',
            showChevron: true,
            onTap: () => _navigateToWBProfile(a.id!),
          ),

          // Fuel section
          const FlightSectionHeader(title: 'Fuel'),
          FlightFieldRow(
            label: 'Fuel Type',
            value: _fuelTypeDisplay(a.fuelType),
            onTap: () async {
              final result = await showPickerSheet(context,
                  title: 'Fuel Type',
                  options: ['100ll', 'jet_a', 'mogas', 'diesel'],
                  currentValue: a.fuelType);
              if (result != null) {
                _saveField({'fuel_type': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Total Usable Fuel',
            value: a.totalUsableFuel != null
                ? '${a.totalUsableFuel} gal'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Total Usable Fuel',
                  currentValue: a.totalUsableFuel,
                  hintText: 'Gallons',
                  suffix: 'gal');
              if (result != null) {
                _saveField({'total_usable_fuel': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Fuel Tanks',
            value: '${a.fuelTanks.length} tank${a.fuelTanks.length == 1 ? '' : 's'}',
            showChevron: true,
            onTap: () =>
                context.go('/aircraft/${a.id}/fuel-tanks'),
          ),

          // Glide section
          const FlightSectionHeader(title: 'Glide'),
          FlightFieldRow(
            label: 'Best Glide Speed',
            value: a.bestGlideSpeed != null
                ? '${a.bestGlideSpeed!.round()} KIAS'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Best Glide Speed',
                  currentValue: a.bestGlideSpeed,
                  hintText: 'KIAS',
                  suffix: 'KIAS');
              if (result != null) {
                _saveField({'best_glide_speed': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Glide Ratio',
            value: a.glideRatio != null ? '${a.glideRatio}:1' : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Glide Ratio',
                  currentValue: a.glideRatio,
                  hintText: 'e.g. 13.8',
                  suffix: ':1');
              if (result != null) {
                _saveField({'glide_ratio': result});
              }
            },
          ),

          // Equipment section
          const FlightSectionHeader(title: 'Equipment'),
          FlightFieldRow(
            label: 'Avionics & Equipment',
            value: a.equipment?.installedAvionics ?? 'Not set',
            showChevron: true,
            onTap: () =>
                context.go('/aircraft/${a.id}/equipment'),
          ),

          // Documents section
          const FlightSectionHeader(title: 'Documents'),
          FlightFieldRow(
            label: 'Aircraft Documents',
            value: '',
            showChevron: true,
            onTap: () =>
                context.go('/aircraft/${a.id}/documents'),
          ),

          // Actions section
          const FlightSectionHeader(title: 'Actions'),
          FlightFieldRow(
            label: a.isDefault ? 'Default Aircraft' : 'Set as Default',
            value: a.isDefault ? 'Yes' : '',
            valueColor: a.isDefault ? AppColors.success : null,
            onTap: a.isDefault
                ? null
                : () async {
                    try {
                      final service = ref.read(aircraftServiceProvider);
                      final updated = await service.setDefault(a.id!);
                      setState(() => _aircraft = updated);
                      ref.invalidate(aircraftListProvider(''));
                      ref.invalidate(defaultAircraftProvider);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    }
                  },
          ),
          InkWell(
            onTap: () => _confirmDelete(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Row(
                children: [
                  Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  SizedBox(width: 8),
                  Text('Delete Aircraft',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.error,
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _navigateToWBProfile(int aircraftId) async {
    try {
      final profiles = await ref.read(wbProfilesProvider(aircraftId).future);
      if (!mounted) return;
      if (profiles.isEmpty) {
        // No profiles yet — go to the W&B screen to create one
        context.push('/aircraft/$aircraftId/wb');
        return;
      }
      final profile =
          profiles.where((p) => p.isDefault).firstOrNull ?? profiles.first;
      context.push('/aircraft/$aircraftId/wb/profiles/${profile.id}/edit');
    } catch (e) {
      if (mounted) {
        // Fallback to W&B screen on error
        context.push('/aircraft/$aircraftId/wb');
      }
    }
  }

  String _engineTypeDisplay(String? engineType) {
    switch (engineType) {
      case 'piston':
        return 'Piston';
      case 'turboprop':
        return 'Turboprop';
      case 'turbojet':
        return 'Turbojet';
      case 'turboshaft':
        return 'Turboshaft';
      default:
        return '--';
    }
  }

  String _formatAltitude(int feet) {
    if (feet >= 1000) {
      return '${(feet / 1000).toStringAsFixed(feet % 1000 == 0 ? 0 : 1)}k';
    }
    return '$feet';
  }

  String _fuelTypeDisplay(String fuelType) {
    switch (fuelType) {
      case '100ll':
        return '100LL';
      case 'jet_a':
        return 'Jet-A';
      case 'mogas':
        return 'MoGas';
      case 'diesel':
        return 'Diesel';
      default:
        return fuelType;
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Aircraft?'),
        content: Text(
            'Are you sure you want to delete ${_aircraft?.tailNumber}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && _aircraft?.id != null) {
      try {
        final service = ref.read(aircraftServiceProvider);
        await service.deleteAircraft(_aircraft!.id!);
        if (mounted) _goBackToList();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}
