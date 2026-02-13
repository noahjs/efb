import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/weight_balance.dart';
import '../../../services/wb_providers.dart';
import '../../../services/api_client.dart';
import '../../flights/widgets/flight_section_header.dart';
import '../../flights/widgets/flight_field_row.dart';
import '../../flights/widgets/flight_edit_dialogs.dart';

class WBProfileEditorScreen extends ConsumerStatefulWidget {
  final int aircraftId;
  final int profileId;

  const WBProfileEditorScreen({
    super.key,
    required this.aircraftId,
    required this.profileId,
  });

  @override
  ConsumerState<WBProfileEditorScreen> createState() =>
      _WBProfileEditorScreenState();
}

class _WBProfileEditorScreenState
    extends ConsumerState<WBProfileEditorScreen> {
  WBProfile? _profile;
  bool _loaded = false;
  bool _saving = false;

  Future<void> _saveField(Map<String, dynamic> updates) async {
    if (_profile?.id == null) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(wbServiceProvider);
      await service.updateProfile(
          widget.aircraftId, widget.profileId, updates);
      await _reloadProfile();
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
      final profileAsync = ref.watch(wbProfileProvider(
          (aircraftId: widget.aircraftId, profileId: widget.profileId)));
      return profileAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          body: Center(
            child: Text('Error loading profile',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
        data: (profile) {
          if (!_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _profile = profile;
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
    final p = _profile;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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
          // Profile Info
          const FlightSectionHeader(title: 'Profile Info'),
          FlightFieldRow(
            label: 'Name',
            value: p.name,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Profile Name',
                  currentValue: p.name,
                  hintText: 'e.g. Standard');
              if (result != null) _saveField({'name': result});
            },
          ),
          FlightFieldRow(
            label: 'Datum',
            value: p.datumDescription ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Datum Description',
                  currentValue: p.datumDescription ?? '',
                  hintText: 'e.g. Forward face of firewall');
              if (result != null) _saveField({'datum_description': result});
            },
          ),
          FlightFieldRow(
            label: 'Lateral CG',
            value: p.lateralCgEnabled ? 'Enabled' : 'Disabled',
            onTap: () =>
                _saveField({'lateral_cg_enabled': !p.lateralCgEnabled}),
          ),

          // Aircraft Weights
          const FlightSectionHeader(title: 'Aircraft Weights'),
          if (p.lateralCgEnabled) _buildColumnHeaders(),
          FlightFieldRow(
            label: 'Empty Weight (BEW)',
            value: '${p.emptyWeight.round()} lbs',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Basic Empty Weight',
                  currentValue: p.emptyWeight,
                  hintText: 'lbs',
                  suffix: 'lbs');
              if (result != null) _saveField({'empty_weight': result});
            },
          ),
          if (p.lateralCgEnabled)
            _buildDualArmRow(
              label: 'BEW CG',
              longValue: p.emptyWeightArm,
              latValue: p.emptyWeightLateralArm,
              onTapLong: () async {
                final result = await showNumberEditSheet(context,
                    title: 'BEW Longitudinal Arm',
                    currentValue: p.emptyWeightArm,
                    hintText: 'inches from datum',
                    suffix: 'in');
                if (result != null) _saveField({'empty_weight_arm': result});
              },
              onTapLat: () async {
                final result = await showNumberEditSheet(context,
                    title: 'BEW Lateral Arm',
                    currentValue: p.emptyWeightLateralArm,
                    hintText: 'inches from centerline',
                    suffix: 'in');
                if (result != null) {
                  _saveField({'empty_weight_lateral_arm': result});
                }
              },
            )
          else
            FlightFieldRow(
              label: 'BEW Arm',
              value: '${p.emptyWeightArm} in',
              onTap: () async {
                final result = await showNumberEditSheet(context,
                    title: 'BEW CG Arm',
                    currentValue: p.emptyWeightArm,
                    hintText: 'inches from datum',
                    suffix: 'in');
                if (result != null) _saveField({'empty_weight_arm': result});
              },
            ),
          FlightFieldRow(
            label: 'Max Takeoff Weight',
            value: '${p.maxTakeoffWeight.round()} lbs',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'MTOW',
                  currentValue: p.maxTakeoffWeight,
                  hintText: 'lbs',
                  suffix: 'lbs');
              if (result != null) _saveField({'max_takeoff_weight': result});
            },
          ),
          FlightFieldRow(
            label: 'Max Landing Weight',
            value: '${p.maxLandingWeight.round()} lbs',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'MLW',
                  currentValue: p.maxLandingWeight,
                  hintText: 'lbs',
                  suffix: 'lbs');
              if (result != null)
                _saveField({'max_landing_weight': result});
            },
          ),
          FlightFieldRow(
            label: 'Max Ramp Weight',
            value: p.maxRampWeight != null
                ? '${p.maxRampWeight!.round()} lbs'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Max Ramp Weight',
                  currentValue: p.maxRampWeight,
                  hintText: 'lbs (blank = same as MTOW)',
                  suffix: 'lbs');
              if (result != null) _saveField({'max_ramp_weight': result});
            },
          ),
          FlightFieldRow(
            label: 'Max Zero Fuel Weight',
            value: p.maxZeroFuelWeight != null
                ? '${p.maxZeroFuelWeight!.round()} lbs'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'MZFW',
                  currentValue: p.maxZeroFuelWeight,
                  hintText: 'lbs (blank if N/A)',
                  suffix: 'lbs');
              if (result != null)
                _saveField({'max_zero_fuel_weight': result});
            },
          ),
          // Fuel
          const FlightSectionHeader(title: 'Fuel'),
          if (p.lateralCgEnabled) _buildColumnHeaders(),
          if (p.lateralCgEnabled)
            _buildDualArmRow(
              label: 'Fuel Arm',
              longValue: p.fuelArm,
              latValue: p.fuelLateralArm,
              onTapLong: () async {
                final result = await showNumberEditSheet(context,
                    title: 'Fuel Longitudinal Arm',
                    currentValue: p.fuelArm,
                    hintText: 'inches from datum',
                    suffix: 'in');
                if (result != null) _saveField({'fuel_arm': result});
              },
              onTapLat: () async {
                final result = await showNumberEditSheet(context,
                    title: 'Fuel Lateral Arm',
                    currentValue: p.fuelLateralArm,
                    hintText: 'inches from centerline',
                    suffix: 'in');
                if (result != null) {
                  _saveField({'fuel_lateral_arm': result});
                }
              },
            )
          else
            FlightFieldRow(
              label: 'Fuel Arm',
              value: p.fuelArm != null ? '${p.fuelArm} in' : '--',
              onTap: () async {
                final result = await showNumberEditSheet(context,
                    title: 'Fuel Arm',
                    currentValue: p.fuelArm,
                    hintText: 'inches from datum',
                    suffix: 'in');
                if (result != null) _saveField({'fuel_arm': result});
              },
            ),
          FlightFieldRow(
            label: 'Taxi Fuel',
            value: '${p.taxiFuelGallons} gal',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Taxi Fuel',
                  currentValue: p.taxiFuelGallons,
                  hintText: 'gallons',
                  suffix: 'gal');
              if (result != null) _saveField({'taxi_fuel_gallons': result});
            },
          ),

          // Stations
          const FlightSectionHeader(title: 'Stations'),
          if (p.lateralCgEnabled) _buildColumnHeaders(),
          ...p.stations.map((s) => _buildStationRow(s)),
          InkWell(
            onTap: () => _addStation(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: const [
                  Icon(Icons.add, size: 18, color: AppColors.accent),
                  SizedBox(width: 8),
                  Text('Add Station',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.accent)),
                ],
              ),
            ),
          ),

          // Envelopes
          const FlightSectionHeader(title: 'Envelopes'),
          ...p.envelopes.map((e) => FlightFieldRow(
                label:
                    '${e.envelopeType} (${e.axis})',
                value: '${e.points.length} points',
                showChevron: true,
                onTap: () => _editEnvelope(e),
              )),
          InkWell(
            onTap: () => _addEnvelope(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: const [
                  Icon(Icons.add, size: 18, color: AppColors.accent),
                  SizedBox(width: 8),
                  Text('Add Envelope',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.accent)),
                ],
              ),
            ),
          ),

          // Notes
          const FlightSectionHeader(title: 'Notes'),
          FlightFieldRow(
            label: 'Notes',
            value: p.notes ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Notes',
                  currentValue: p.notes ?? '',
                  hintText: 'Optional notes');
              if (result != null) _saveField({'notes': result});
            },
          ),

          // Delete
          const FlightSectionHeader(title: 'Actions'),
          InkWell(
            onTap: () => _confirmDelete(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: const Row(
                children: [
                  Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                  SizedBox(width: 8),
                  Text('Delete Profile',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.error)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDualArmRow({
    required String label,
    required double? longValue,
    required double? latValue,
    required VoidCallback onTapLong,
    required VoidCallback onTapLat,
    String suffix = 'in',
  }) {
    return InkWell(
      onTap: onTapLong,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: label.contains('\n')
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.split('\n')[0],
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          label.split('\n')[1],
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapLat,
              child: SizedBox(
                width: 90,
                child: Text(
                  latValue != null ? '$latValue $suffix' : '--',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapLong,
              child: SizedBox(
                width: 90,
                child: Text(
                  longValue != null ? '$longValue $suffix' : '--',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          SizedBox(
            width: 90,
            child: Text(
              'LAT.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              'LONG.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationRow(WBStation station) {
    final lateral = _profile?.lateralCgEnabled ?? false;
    if (lateral) {
      return _buildDualArmRow(
        label: '${station.name}\n${station.category}',
        longValue: station.arm,
        latValue: station.lateralArm,
        onTapLong: () => _editStation(station),
        onTapLat: () => _editStation(station),
      );
    }
    return FlightFieldRow(
      label: station.name,
      value: '${station.category} | ${station.arm} in',
      showChevron: true,
      onTap: () => _editStation(station),
    );
  }

  Future<void> _addStation() async {
    final nameController = TextEditingController();
    final armController = TextEditingController();
    final latArmController = TextEditingController();
    String category = 'seat';
    final lateral = _profile?.lateralCgEnabled ?? false;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBottomState) => Padding(
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
                  const Text('Add Station',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: () {
                      final arm = double.tryParse(armController.text);
                      if (nameController.text.isEmpty || arm == null) return;
                      final data = <String, dynamic>{
                        'name': nameController.text,
                        'category': category,
                        'arm': arm,
                        'sort_order': _profile?.stations.length ?? 0,
                      };
                      if (lateral) {
                        final latArm =
                            double.tryParse(latArmController.text);
                        if (latArm != null) data['lateral_arm'] = latArm;
                      }
                      Navigator.pop(ctx, data);
                    },
                    child: const Text('Add',
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
                    const InputDecoration(hintText: 'Station name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                dropdownColor: AppColors.surface,
                decoration:
                    const InputDecoration(labelText: 'Category'),
                items: ['seat', 'baggage', 'fuel', 'other']
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c,
                            style: const TextStyle(
                                color: AppColors.textPrimary))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setBottomState(() => category = v);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: armController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                    hintText: lateral
                        ? 'Longitudinal arm (inches from datum)'
                        : 'Arm (inches from datum)'),
              ),
              if (lateral) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: latArmController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                      hintText: 'Lateral arm (inches from centerline)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      try {
        final service = ref.read(wbServiceProvider);
        await service.createStation(
            widget.aircraftId, widget.profileId, result);
        _reloadProfile();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add station: $e')),
          );
        }
      }
    }
  }

  Future<void> _editStation(WBStation station) async {
    if (station.id == null) return;
    final lateral = _profile?.lateralCgEnabled ?? false;
    final nameController = TextEditingController(text: station.name);
    final armController = TextEditingController(text: station.arm.toString());
    final latArmController =
        TextEditingController(text: station.lateralArm?.toString() ?? '');
    final maxWeightController =
        TextEditingController(text: station.maxWeight?.toString() ?? '');
    final defaultWeightController =
        TextEditingController(text: station.defaultWeight?.toString() ?? '');
    String category = station.category;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBottomState) => Padding(
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
                  const Text('Edit Station',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'save'),
                    child: const Text('Save',
                        style: TextStyle(color: AppColors.accent)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['seat', 'baggage', 'fuel', 'other']
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c,
                            style: const TextStyle(
                                color: AppColors.textPrimary))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setBottomState(() => category = v);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: armController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                    labelText: lateral
                        ? 'Longitudinal Arm (in)'
                        : 'Arm (in)'),
              ),
              if (lateral) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: latArmController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration:
                      const InputDecoration(labelText: 'Lateral Arm (in)'),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: maxWeightController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration:
                    const InputDecoration(labelText: 'Max Weight (lbs)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: defaultWeightController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration:
                    const InputDecoration(labelText: 'Default Weight (lbs)'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'delete'),
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 18),
                  label: const Text('Delete Station',
                      style: TextStyle(color: AppColors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == 'save') {
      final updates = <String, dynamic>{};
      if (nameController.text != station.name) {
        updates['name'] = nameController.text;
      }
      if (category != station.category) {
        updates['category'] = category;
      }
      final arm = double.tryParse(armController.text);
      if (arm != null && arm != station.arm) {
        updates['arm'] = arm;
      }
      if (lateral) {
        final latArm = double.tryParse(latArmController.text);
        if (latArm != station.lateralArm) {
          updates['lateral_arm'] = latArm;
        }
      }
      final maxW = double.tryParse(maxWeightController.text);
      if (maxW != station.maxWeight) {
        updates['max_weight'] = maxW;
      }
      final defW = double.tryParse(defaultWeightController.text);
      if (defW != station.defaultWeight) {
        updates['default_weight'] = defW;
      }
      if (updates.isNotEmpty) {
        try {
          final service = ref.read(wbServiceProvider);
          await service.updateStation(
              widget.aircraftId, widget.profileId, station.id!, updates);
          _reloadProfile();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update: $e')),
            );
          }
        }
      }
    } else if (result == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Delete Station?'),
          content: Text(
              'Are you sure you want to delete "${station.name}"? This cannot be undone.'),
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
          final service = ref.read(wbServiceProvider);
          await service.deleteStation(
              widget.aircraftId, widget.profileId, station.id!);
          _reloadProfile();
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

  Future<void> _addEnvelope() async {
    final pointsController = TextEditingController();
    String envelopeType = 'normal';
    String axis = 'longitudinal';

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBottomState) => Padding(
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
                  const Text('Add Envelope',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: () {
                      final points = _parseEnvelopePoints(
                          pointsController.text);
                      if (points.isEmpty) return;
                      Navigator.pop(ctx, {
                        'envelope_type': envelopeType,
                        'axis': axis,
                        'points': points,
                      });
                    },
                    child: const Text('Save',
                        style: TextStyle(color: AppColors.accent)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: envelopeType,
                dropdownColor: AppColors.surface,
                decoration:
                    const InputDecoration(labelText: 'Type'),
                items: ['normal', 'utility', 'aerobatic']
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t,
                            style: const TextStyle(
                                color: AppColors.textPrimary))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setBottomState(() => envelopeType = v);
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: axis,
                dropdownColor: AppColors.surface,
                decoration:
                    const InputDecoration(labelText: 'Axis'),
                items: ['longitudinal', 'lateral']
                    .map((a) => DropdownMenuItem(
                        value: a,
                        child: Text(a,
                            style: const TextStyle(
                                color: AppColors.textPrimary))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setBottomState(() => axis = v);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pointsController,
                maxLines: 5,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText:
                      'CG, Weight (one pair per line)\ne.g.\n180.0, 1800\n190.0, 3400\n195.0, 3400\n195.0, 1800',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      try {
        final service = ref.read(wbServiceProvider);
        await service.upsertEnvelope(
            widget.aircraftId, widget.profileId, result);
        _reloadProfile();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add envelope: $e')),
          );
        }
      }
    }
  }

  Future<void> _editEnvelope(WBEnvelope envelope) async {
    final existingText = envelope.points
        .map((p) => '${p.cg}, ${p.weight}')
        .join('\n');
    final pointsController = TextEditingController(text: existingText);

    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
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
                Text(
                    '${envelope.envelopeType} (${envelope.axis})',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                TextButton(
                  onPressed: () {
                    final points = _parseEnvelopePoints(
                        pointsController.text);
                    Navigator.pop(ctx, points);
                  },
                  child: const Text('Save',
                      style: TextStyle(color: AppColors.accent)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsController,
              maxLines: 8,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'CG, Weight (one pair per line)',
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final service = ref.read(wbServiceProvider);
        await service.upsertEnvelope(
            widget.aircraftId, widget.profileId, {
          'envelope_type': envelope.envelopeType,
          'axis': envelope.axis,
          'points': result,
        });
        _reloadProfile();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save envelope: $e')),
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> _parseEnvelopePoints(String text) {
    final points = <Map<String, dynamic>>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(',');
      if (parts.length != 2) continue;
      final cg = double.tryParse(parts[0].trim());
      final weight = double.tryParse(parts[1].trim());
      if (cg != null && weight != null) {
        points.add({'cg': cg, 'weight': weight});
      }
    }
    return _sortPolygonPoints(points);
  }

  /// Sorts points into counter-clockwise polygon order by angle from centroid.
  /// Prevents bowtie/hourglass shapes when user enters points in wrong order.
  List<Map<String, dynamic>> _sortPolygonPoints(
      List<Map<String, dynamic>> points) {
    if (points.length < 3) return points;

    // Compute centroid
    double cx = 0, cy = 0;
    for (final p in points) {
      cx += (p['cg'] as double);
      cy += (p['weight'] as double);
    }
    cx /= points.length;
    cy /= points.length;

    // Sort by angle from centroid
    final sorted = List<Map<String, dynamic>>.from(points);
    sorted.sort((a, b) {
      final angleA =
          _atan2((a['weight'] as double) - cy, (a['cg'] as double) - cx);
      final angleB =
          _atan2((b['weight'] as double) - cy, (b['cg'] as double) - cx);
      return angleA.compareTo(angleB);
    });
    return sorted;
  }

  static double _atan2(double y, double x) {
    // Use dart:math atan2, returns -pi to pi
    return y == 0 && x == 0 ? 0 : math.atan2(y, x);
  }

  Future<void> _reloadProfile() async {
    try {
      final api = ref.read(apiClientProvider);
      final json =
          await api.getWBProfile(widget.aircraftId, widget.profileId);
      final profile = WBProfile.fromJson(json);
      if (mounted) {
        setState(() => _profile = profile);
      }
      // Invalidate providers so other screens stay in sync
      ref.invalidate(wbProfileProvider(
          (aircraftId: widget.aircraftId, profileId: widget.profileId)));
      ref.invalidate(wbProfilesProvider(widget.aircraftId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reload: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Profile?'),
        content: Text(
            'Are you sure you want to delete "${_profile?.name}"? This cannot be undone.'),
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

    if (confirmed == true && _profile?.id != null) {
      try {
        final service = ref.read(wbServiceProvider);
        await service.deleteProfile(widget.aircraftId, widget.profileId);
        ref.invalidate(wbProfilesProvider(widget.aircraftId));
        if (mounted) context.pop();
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
