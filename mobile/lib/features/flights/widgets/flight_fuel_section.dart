import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import '../../../services/aircraft_providers.dart';
import 'flight_field_row.dart';
import 'flight_edit_dialogs.dart';

/// Fuel density in lbs per gallon based on fuel type.
double _fuelDensity(String? fuelType) {
  switch (fuelType) {
    case 'jet_a':
      return 6.75;
    case 'avgas':
    case '100ll':
    case 'mogas':
      return 6.0;
    default:
      return 6.0;
  }
}

String _fmtGal(double? gal) {
  if (gal == null) return '--';
  return gal.toStringAsFixed(1);
}

String _fmtLbs(double? lbs) {
  if (lbs == null) return '--';
  final rounded = lbs.round();
  if (rounded >= 1000) {
    final s = rounded.toString();
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }
  return rounded.toString();
}

class FlightFuelSection extends ConsumerWidget {
  final Flight flight;
  final ValueChanged<Flight> onChanged;

  const FlightFuelSection({
    super.key,
    required this.flight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch aircraft details for capacity, fuel type, and presets
    double? capacityGal;
    String? fuelType;
    double? topOffGallons;
    double? tabsGallons;
    if (flight.aircraftId != null) {
      final aircraftAsync = ref.watch(aircraftDetailProvider(flight.aircraftId!));
      aircraftAsync.whenData((aircraft) {
        if (aircraft != null) {
          capacityGal = aircraft.totalUsableFuel;
          fuelType = aircraft.fuelType;
          topOffGallons = aircraft.totalUsableFuel;
          final tabsTotal = aircraft.fuelTanks
              .where((t) => t.tabFuelGallons != null)
              .fold<double>(0, (sum, t) => sum + t.tabFuelGallons!);
          tabsGallons = tabsTotal > 0 ? tabsTotal : null;
        }
      });
    }

    final density = _fuelDensity(fuelType);

    // Computed values
    final startGal = flight.startFuelGallons;
    final flightFuelGal = flight.flightFuelGallons;
    final reserveGal = flight.reserveFuelGallons;

    // Min required fuel = flight fuel + reserve
    final minReqTotal = (flightFuelGal ?? 0) + (reserveGal ?? 0);
    final double? minReqGallons = minReqTotal > 0 ? minReqTotal : null;

    double? fuelAtLandingGal;
    if (startGal != null && flightFuelGal != null) {
      fuelAtLandingGal = startGal - flightFuelGal;
    }

    double? extraFuelGal;
    if (fuelAtLandingGal != null && reserveGal != null) {
      extraFuelGal = fuelAtLandingGal - reserveGal;
    }

    // LBS conversions
    final startLbs = startGal != null ? startGal * density : null;
    final capacityLbs = capacityGal != null ? capacityGal! * density : null;
    final flightFuelLbs =
        flightFuelGal != null ? flightFuelGal * density : null;
    final fuelAtLandingLbs =
        fuelAtLandingGal != null ? fuelAtLandingGal * density : null;
    final reserveLbs = reserveGal != null ? reserveGal * density : null;
    final extraFuelLbs =
        extraFuelGal != null ? extraFuelGal * density : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with column labels
        _FuelSectionHeader(),

        // Start Fuel
        _FuelRow(
          label: 'Start',
          gallons: startGal,
          lbs: startLbs,
          capacityGal: capacityGal,
          capacityLbs: capacityLbs,
          isEditable: true,
          onTap: () async {
            final result = await _showStartFuelSheet(
              context,
              currentValue: flight.startFuelGallons,
              topOffGallons: topOffGallons,
              tabsGallons: tabsGallons,
              minReqGallons: minReqGallons,
            );
            if (result != null) {
              onChanged(flight.copyWith(startFuelGallons: result));
            }
          },
        ),

        // Flight Fuel (computed)
        _FuelRow(
          label: 'Flight Fuel',
          gallons: flightFuelGal,
          lbs: flightFuelLbs,
          isComputed: true,
        ),

        // Fuel at Landing (computed)
        _FuelRow(
          label: 'Fuel at Landing',
          gallons: fuelAtLandingGal,
          lbs: fuelAtLandingLbs,
          isComputed: true,
          isBold: true,
        ),

        // Reserve Fuel (editable, indented)
        _FuelRow(
          label: 'Reserve Fuel',
          gallons: reserveGal,
          lbs: reserveLbs,
          isIndented: true,
          isEditable: true,
          onTap: () async {
            final result = await showNumberEditSheet(
              context,
              title: 'Reserve Fuel',
              currentValue: flight.reserveFuelGallons,
              hintText: 'e.g. 5.0',
              suffix: 'gal',
            );
            if (result != null) {
              onChanged(flight.copyWith(reserveFuelGallons: result));
            }
          },
        ),

        // Extra Fuel (computed, indented)
        _FuelRow(
          label: 'Extra Fuel',
          gallons: extraFuelGal,
          lbs: extraFuelLbs,
          isIndented: true,
          isComputed: true,
        ),
      ],
    );
  }
}

/// Custom header for the Fuel section with LBS / GAL column labels.
class _FuelSectionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      margin: const EdgeInsets.only(top: 4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'FUEL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              'LBS',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              'GAL',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A fuel-specific row with dual LBS/GAL columns and optional capacity context.
class _FuelRow extends StatelessWidget {
  final String label;
  final double? gallons;
  final double? lbs;
  final double? capacityGal;
  final double? capacityLbs;
  final bool isEditable;
  final bool isComputed;
  final bool isIndented;
  final bool isBold;
  final VoidCallback? onTap;

  const _FuelRow({
    required this.label,
    this.gallons,
    this.lbs,
    this.capacityGal,
    this.capacityLbs,
    this.isEditable = false,
    this.isComputed = false,
    this.isIndented = false,
    this.isBold = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = isEditable
        ? AppColors.accent
        : isComputed
            ? AppColors.textPrimary
            : AppColors.textSecondary;

    final fontWeight = isBold ? FontWeight.w600 : FontWeight.w400;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
          left: isIndented ? 32 : 16,
          right: 16,
          top: 12,
          bottom: capacityGal != null ? 4 : 12,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Column(
          children: [
            // Main row: label + lbs + gal
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                      color: isIndented
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    _fmtLbs(lbs),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: fontWeight,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  child: Text(
                    _fmtGal(gallons),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: fontWeight,
                      color: valueColor,
                    ),
                  ),
                ),
              ],
            ),
            // Capacity context line (e.g. "/ 142")
            if (capacityGal != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox.shrink()),
                    SizedBox(
                      width: 70,
                      child: Text(
                        capacityLbs != null ? '/ ${_fmtLbs(capacityLbs)}' : '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '/ ${_fmtGal(capacityGal)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Custom modal for editing start fuel with preset buttons (Top Off, Tabs, Min Req).
Future<double?> _showStartFuelSheet(
  BuildContext context, {
  required double? currentValue,
  double? topOffGallons,
  double? tabsGallons,
  double? minReqGallons,
}) async {
  final controller = TextEditingController(
    text: currentValue != null && currentValue > 0
        ? currentValue.toStringAsFixed(1)
        : '',
  );

  // Determine active preset
  String? active;
  if (currentValue != null && currentValue > 0) {
    if (topOffGallons != null && (currentValue - topOffGallons).abs() < 0.05) {
      active = 'topoff';
    } else if (tabsGallons != null &&
        (currentValue - tabsGallons).abs() < 0.05) {
      active = 'tabs';
    } else if (minReqGallons != null &&
        (currentValue - minReqGallons).abs() < 0.05) {
      active = 'minreq';
    }
  }

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
                  child: Text('Start Fuel',
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
            if (topOffGallons != null ||
                tabsGallons != null ||
                minReqGallons != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (topOffGallons != null)
                    Expanded(
                      child: _FuelPresetChip(
                        label: 'Top Off',
                        subtitle: '${topOffGallons.toStringAsFixed(1)} gal',
                        isActive: active == 'topoff',
                        onTap: () {
                          result = topOffGallons;
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  if (topOffGallons != null &&
                      (tabsGallons != null || minReqGallons != null))
                    const SizedBox(width: 8),
                  if (tabsGallons != null)
                    Expanded(
                      child: _FuelPresetChip(
                        label: 'Tabs',
                        subtitle: '${tabsGallons.toStringAsFixed(1)} gal',
                        isActive: active == 'tabs',
                        onTap: () {
                          result = tabsGallons;
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  if (tabsGallons != null && minReqGallons != null)
                    const SizedBox(width: 8),
                  if (minReqGallons != null)
                    Expanded(
                      child: _FuelPresetChip(
                        label: 'Min Req',
                        subtitle: '${minReqGallons.toStringAsFixed(1)} gal',
                        isActive: active == 'minreq',
                        onTap: () {
                          result = minReqGallons;
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

  return result;
}

class _FuelPresetChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const _FuelPresetChip({
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
