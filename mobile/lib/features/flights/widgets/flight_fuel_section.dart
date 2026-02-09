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
    // Fetch aircraft details for capacity and fuel type
    double? capacityGal;
    String? fuelType;
    if (flight.aircraftId != null) {
      final aircraftAsync = ref.watch(aircraftDetailProvider(flight.aircraftId!));
      aircraftAsync.whenData((aircraft) {
        if (aircraft != null) {
          capacityGal = aircraft.totalUsableFuel;
          fuelType = aircraft.fuelType;
        }
      });
    }

    final density = _fuelDensity(fuelType);

    // Computed values
    final startGal = flight.startFuelGallons;
    final flightFuelGal = flight.flightFuelGallons;
    final reserveGal = flight.reserveFuelGallons;

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

        // Fuel Policy — full width, no dual column
        FlightFieldRow(
          label: 'Fuel Policy',
          value: flight.fuelPolicy ?? 'None',
          showChevron: true,
          onTap: () async {
            final result = await showPickerSheet(
              context,
              title: 'Fuel Policy',
              options: ['Fill Tabs', 'Fill Up', 'Min Fuel', 'Manual'],
              currentValue: flight.fuelPolicy,
            );
            if (result != null) {
              onChanged(flight.copyWith(fuelPolicy: result));
            }
          },
        ),

        // Start Fuel
        _FuelRow(
          label: 'Start',
          gallons: startGal,
          lbs: startLbs,
          capacityGal: capacityGal,
          capacityLbs: capacityLbs,
          isEditable: true,
          onTap: () async {
            final result = await showNumberEditSheet(
              context,
              title: 'Start Fuel',
              currentValue: flight.startFuelGallons,
              hintText: 'e.g. 48.0',
              suffix: 'gal',
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
