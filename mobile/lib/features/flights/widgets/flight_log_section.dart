import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';
import 'flight_edit_dialogs.dart';

class FlightLogSection extends StatelessWidget {
  final Flight flight;
  final ValueChanged<Flight> onChanged;

  const FlightLogSection({
    super.key,
    required this.flight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Flight Log'),
        FlightFieldRow(
          label: 'Fuel at Shutdown',
          value:
              '${flight.fuelAtShutdownGallons.toStringAsFixed(1)} gal',
          onTap: () async {
            final result = await showNumberEditSheet(
              context,
              title: 'Fuel at Shutdown',
              currentValue: flight.fuelAtShutdownGallons,
              hintText: 'e.g. 20.0',
              suffix: 'gal',
            );
            if (result != null) {
              onChanged(flight.copyWith(fuelAtShutdownGallons: result));
            }
          },
        ),
        const FlightFieldRow(
          label: 'Times',
          value: 'View',
          showChevron: true,
          valueColor: AppColors.textMuted,
        ),
      ],
    );
  }
}
