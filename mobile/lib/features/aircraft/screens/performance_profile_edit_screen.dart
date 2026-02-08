import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/aircraft.dart';
import '../../../services/aircraft_providers.dart';
import '../../flights/widgets/flight_section_header.dart';
import '../../flights/widgets/flight_field_row.dart';
import '../../flights/widgets/flight_edit_dialogs.dart';

class PerformanceProfileEditScreen extends ConsumerStatefulWidget {
  final int aircraftId;
  final int profileId;

  const PerformanceProfileEditScreen({
    super.key,
    required this.aircraftId,
    required this.profileId,
  });

  @override
  ConsumerState<PerformanceProfileEditScreen> createState() =>
      _PerformanceProfileEditScreenState();
}

class _PerformanceProfileEditScreenState
    extends ConsumerState<PerformanceProfileEditScreen> {
  PerformanceProfile? _profile;
  bool _loaded = false;
  bool _saving = false;

  Future<void> _saveField(Map<String, dynamic> updates) async {
    setState(() => _saving = true);
    try {
      final service = ref.read(aircraftServiceProvider);
      final updated = await service.updateProfile(
          widget.aircraftId, widget.profileId, updates);
      setState(() => _profile = updated);
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
              onPressed: () => context
                  .go('/aircraft/${widget.aircraftId}/profiles'),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context
                  .go('/aircraft/${widget.aircraftId}/profiles'),
            ),
          ),
          body: Center(child: Text('Error: $e')),
        ),
        data: (aircraft) {
          if (aircraft != null && !_loaded) {
            final p = aircraft.performanceProfiles
                .where((p) => p.id == widget.profileId)
                .firstOrNull;
            if (p != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _profile = p;
                  _loaded = true;
                });
              });
            }
          }
          return _buildScaffold();
        },
      );
    }
    return _buildScaffold();
  }

  Widget _buildScaffold() {
    final p = _profile;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.go('/aircraft/${widget.aircraftId}/profiles'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.go('/aircraft/${widget.aircraftId}/profiles'),
        ),
        title: Text(p.name),
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
          const FlightSectionHeader(title: 'General'),
          FlightFieldRow(
            label: 'Name',
            value: p.name,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Profile Name',
                  currentValue: p.name,
                  hintText: 'e.g. Economy Cruise');
              if (result != null) {
                _saveField({'name': result});
              }
            },
          ),

          const FlightSectionHeader(title: 'Cruise'),
          FlightFieldRow(
            label: 'True Airspeed',
            value: p.cruiseTas != null
                ? '${p.cruiseTas!.round()} kt'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Cruise TAS',
                  currentValue: p.cruiseTas,
                  suffix: 'kt');
              if (result != null) {
                _saveField({'cruise_tas': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Fuel Burn',
            value: p.cruiseFuelBurn != null
                ? '${p.cruiseFuelBurn} GPH'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Cruise Fuel Burn',
                  currentValue: p.cruiseFuelBurn,
                  suffix: 'GPH');
              if (result != null) {
                _saveField({'cruise_fuel_burn': result});
              }
            },
          ),

          const FlightSectionHeader(title: 'Climb'),
          FlightFieldRow(
            label: 'Rate',
            value: p.climbRate != null
                ? '${p.climbRate!.round()} fpm'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Climb Rate',
                  currentValue: p.climbRate,
                  suffix: 'fpm');
              if (result != null) {
                _saveField({'climb_rate': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Speed',
            value: p.climbSpeed != null
                ? '${p.climbSpeed!.round()} kt'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Climb Speed',
                  currentValue: p.climbSpeed,
                  suffix: 'kt');
              if (result != null) {
                _saveField({'climb_speed': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Fuel Flow',
            value: p.climbFuelFlow != null
                ? '${p.climbFuelFlow} GPH'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Climb Fuel Flow',
                  currentValue: p.climbFuelFlow,
                  suffix: 'GPH');
              if (result != null) {
                _saveField({'climb_fuel_flow': result});
              }
            },
          ),

          const FlightSectionHeader(title: 'Descent'),
          FlightFieldRow(
            label: 'Rate',
            value: p.descentRate != null
                ? '${p.descentRate!.round()} fpm'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Descent Rate',
                  currentValue: p.descentRate,
                  suffix: 'fpm');
              if (result != null) {
                _saveField({'descent_rate': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Speed',
            value: p.descentSpeed != null
                ? '${p.descentSpeed!.round()} kt'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Descent Speed',
                  currentValue: p.descentSpeed,
                  suffix: 'kt');
              if (result != null) {
                _saveField({'descent_speed': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Fuel Flow',
            value: p.descentFuelFlow != null
                ? '${p.descentFuelFlow} GPH'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Descent Fuel Flow',
                  currentValue: p.descentFuelFlow,
                  suffix: 'GPH');
              if (result != null) {
                _saveField({'descent_fuel_flow': result});
              }
            },
          ),

          // Actions
          const FlightSectionHeader(title: 'Actions'),
          FlightFieldRow(
            label: p.isDefault ? 'Default Profile' : 'Set as Default',
            value: p.isDefault ? 'Yes' : '',
            valueColor: p.isDefault ? AppColors.success : null,
            onTap: p.isDefault
                ? null
                : () async {
                    try {
                      final service = ref.read(aircraftServiceProvider);
                      await service.setDefaultProfile(
                          widget.aircraftId, widget.profileId);
                      ref.invalidate(
                          aircraftDetailProvider(widget.aircraftId));
                      if (mounted) {
                        context.go(
                            '/aircraft/${widget.aircraftId}/profiles');
                      }
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
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Delete Profile?'),
                  content: Text('Delete "${p.name}"?'),
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
              if (confirmed == true) {
                try {
                  final service = ref.read(aircraftServiceProvider);
                  await service.deleteProfile(
                      widget.aircraftId, widget.profileId);
                  ref.invalidate(
                      aircraftDetailProvider(widget.aircraftId));
                  if (mounted) {
                    context.go(
                        '/aircraft/${widget.aircraftId}/profiles');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Row(
                children: [
                  Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                  SizedBox(width: 8),
                  Text('Delete Profile',
                      style: TextStyle(fontSize: 14, color: AppColors.error)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
