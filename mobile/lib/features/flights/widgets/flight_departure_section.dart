import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/flight.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';
import 'flight_edit_dialogs.dart';

class FlightDepartureSection extends StatelessWidget {
  final Flight flight;
  final ValueChanged<Flight> onChanged;

  const FlightDepartureSection({
    super.key,
    required this.flight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    String etdDisplay = 'Set ETD';
    if (flight.etd != null) {
      try {
        final date = DateTime.parse(flight.etd!);
        etdDisplay = DateFormat('MMM d, yyyy h:mm a').format(date);
      } catch (_) {
        etdDisplay = flight.etd!;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Departure & Destination'),
        FlightFieldRow(
          label: 'ETD',
          value: etdDisplay,
          onTap: () async {
            DateTime? initial;
            if (flight.etd != null) {
              try {
                initial = DateTime.parse(flight.etd!);
              } catch (_) {}
            }
            final picked = await showDateTimePickerSheet(
              context,
              title: 'Estimated Time of Departure',
              initialDate: initial,
            );
            if (picked != null) {
              onChanged(flight.copyWith(etd: picked.toIso8601String()));
            }
          },
        ),
        FlightFieldRow(
          label: 'Departure',
          value: flight.departureIdentifier ?? 'Select',
          showChevron: true,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Departure Airport',
              currentValue: flight.departureIdentifier ?? '',
              hintText: 'e.g. KAPA',
            );
            if (result != null) {
              onChanged(
                  flight.copyWith(departureIdentifier: result.toUpperCase()));
            }
          },
        ),
        FlightFieldRow(
          label: 'Destination',
          value: flight.destinationIdentifier ?? 'Select',
          showChevron: true,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Destination Airport',
              currentValue: flight.destinationIdentifier ?? '',
              hintText: 'e.g. KBJC',
            );
            if (result != null) {
              onChanged(flight.copyWith(
                  destinationIdentifier: result.toUpperCase()));
            }
          },
        ),
        FlightFieldRow(
          label: 'Alternate',
          value: flight.alternateIdentifier ?? 'None',
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Alternate Airport',
              currentValue: flight.alternateIdentifier ?? '',
              hintText: 'e.g. KDEN',
            );
            if (result != null) {
              onChanged(
                  flight.copyWith(alternateIdentifier: result.toUpperCase()));
            }
          },
        ),
      ],
    );
  }
}
