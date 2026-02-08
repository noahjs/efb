import 'package:flutter/material.dart';
import '../../../models/flight.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';
import 'flight_edit_dialogs.dart';

class FlightAircraftSection extends StatelessWidget {
  final Flight flight;
  final ValueChanged<Flight> onChanged;

  const FlightAircraftSection({
    super.key,
    required this.flight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tailDisplay = flight.aircraftIdentifier ?? 'Select';
    final typeDisplay = flight.aircraftType ?? '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Aircraft'),
        FlightFieldRow(
          label: 'Aircraft',
          value: '$tailDisplay  $typeDisplay',
          showChevron: true,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Aircraft Tail Number',
              currentValue: flight.aircraftIdentifier ?? '',
              hintText: 'e.g. N12345',
            );
            if (result != null) {
              onChanged(
                  flight.copyWith(aircraftIdentifier: result.toUpperCase()));
            }
          },
        ),
        FlightFieldRow(
          label: 'Aircraft Type',
          value: flight.aircraftType ?? 'Select',
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Aircraft Type',
              currentValue: flight.aircraftType ?? '',
              hintText: 'e.g. C172',
            );
            if (result != null) {
              onChanged(flight.copyWith(aircraftType: result.toUpperCase()));
            }
          },
        ),
        FlightFieldRow(
          label: 'Performance Profile',
          value: flight.performanceProfile ?? 'None',
          showChevron: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Performance profiles coming in a future update'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}
