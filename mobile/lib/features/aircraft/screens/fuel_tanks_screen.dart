import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/aircraft.dart';
import '../../../services/aircraft_providers.dart';
import '../../flights/widgets/flight_field_row.dart';
import '../../flights/widgets/flight_edit_dialogs.dart';

class FuelTanksScreen extends ConsumerStatefulWidget {
  final int aircraftId;

  const FuelTanksScreen({super.key, required this.aircraftId});

  @override
  ConsumerState<FuelTanksScreen> createState() => _FuelTanksScreenState();
}

class _FuelTanksScreenState extends ConsumerState<FuelTanksScreen> {
  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(aircraftDetailProvider(widget.aircraftId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goBack('/aircraft/${widget.aircraftId}'),
        ),
        title: const Text('Fuel Tanks'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: AppColors.accent,
            onPressed: _addTank,
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.textSecondary))),
        data: (aircraft) {
          if (aircraft == null) {
            return const Center(child: Text('Aircraft not found'));
          }
          final tanks = aircraft.fuelTanks;
          if (tanks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_gas_station,
                      size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('No Fuel Tanks',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Tap + to add a fuel tank',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: tanks.length,
            itemBuilder: (context, index) => _buildTankTile(tanks[index]),
          );
        },
      ),
    );
  }

  Widget _buildTankTile(FuelTank tank) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(tank.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  onPressed: () => _deleteTank(tank),
                ),
              ],
            ),
          ),
          FlightFieldRow(
            label: 'Name',
            value: tank.name,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Tank Name',
                  currentValue: tank.name,
                  hintText: 'e.g. Left Wing');
              if (result != null && tank.id != null) {
                await _updateTank(tank.id!, {'name': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Capacity',
            value: '${tank.capacityGallons} gal',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Capacity',
                  currentValue: tank.capacityGallons,
                  suffix: 'gal');
              if (result != null && tank.id != null) {
                await _updateTank(tank.id!, {'capacity_gallons': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Tab Fuel',
            value: tank.tabFuelGallons != null
                ? '${tank.tabFuelGallons} gal'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Tab Fuel',
                  currentValue: tank.tabFuelGallons,
                  suffix: 'gal');
              if (result != null && tank.id != null) {
                await _updateTank(tank.id!, {'tab_fuel_gallons': result});
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updateTank(int tankId, Map<String, dynamic> data) async {
    try {
      final service = ref.read(aircraftServiceProvider);
      await service.updateFuelTank(widget.aircraftId, tankId, data);
      ref.invalidate(aircraftDetailProvider(widget.aircraftId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteTank(FuelTank tank) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Tank?'),
        content: Text('Delete "${tank.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && tank.id != null) {
      try {
        final service = ref.read(aircraftServiceProvider);
        await service.deleteFuelTank(widget.aircraftId, tank.id!);
        ref.invalidate(aircraftDetailProvider(widget.aircraftId));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _addTank() async {
    final nameController = TextEditingController();
    final capController = TextEditingController();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
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
                const Text('New Fuel Tank',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                TextButton(
                  onPressed: () {
                    final cap =
                        double.tryParse(capController.text) ?? 0;
                    Navigator.pop(ctx, {
                      'name': nameController.text,
                      'capacity_gallons': cap,
                    });
                  },
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
                  const InputDecoration(hintText: 'e.g. Left Wing'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Capacity',
                suffixText: 'gal',
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['name'].toString().isNotEmpty) {
      try {
        final service = ref.read(aircraftServiceProvider);
        await service.createFuelTank(widget.aircraftId, result);
        ref.invalidate(aircraftDetailProvider(widget.aircraftId));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      }
    }
  }
}
