import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';
import 'flight_edit_dialogs.dart';

class FlightFuelSection extends StatelessWidget {
  final Flight flight;
  final ValueChanged<Flight> onChanged;

  const FlightFuelSection({
    super.key,
    required this.flight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Fuel'),
        FlightFieldRow(
          label: 'Fuel Policy',
          value: flight.fuelPolicy ?? 'None',
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
        FlightFieldRow(
          label: 'Start Fuel',
          value: flight.startFuelGallons != null
              ? '${flight.startFuelGallons!.toStringAsFixed(1)} gal'
              : 'Set',
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
        FlightFieldRow(
          label: 'Fuel Burn Rate',
          value: flight.fuelBurnRate != null
              ? '${flight.fuelBurnRate!.toStringAsFixed(1)} gph'
              : 'Set',
          onTap: () async {
            final result = await showNumberEditSheet(
              context,
              title: 'Fuel Burn Rate',
              currentValue: flight.fuelBurnRate,
              hintText: 'e.g. 10.5',
              suffix: 'gph',
            );
            if (result != null) {
              onChanged(flight.copyWith(fuelBurnRate: result));
            }
          },
        ),
        FlightFieldRow(
          label: 'Flight Fuel',
          value: '--',
          valueColor: AppColors.textSecondary,
        ),
        FlightFieldRow(
          label: 'Fuel at Landing',
          value: '--',
          valueColor: AppColors.textSecondary,
        ),
        FlightFieldRow(
          label: 'Reserve Fuel',
          value: flight.reserveFuelGallons != null
              ? '${flight.reserveFuelGallons!.toStringAsFixed(1)} gal'
              : 'Set',
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
        FlightFieldRow(
          label: 'Extra Fuel',
          value: '--',
          valueColor: AppColors.textSecondary,
        ),
      ],
    );
  }
}
