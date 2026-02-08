import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';
import 'flight_edit_dialogs.dart';

class FlightPayloadSection extends StatelessWidget {
  final Flight flight;
  final ValueChanged<Flight> onChanged;

  const FlightPayloadSection({
    super.key,
    required this.flight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalPeopleWeight = flight.peopleCount * flight.avgPersonWeight;
    final totalPayload = totalPeopleWeight + flight.cargoWeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Payload'),
        FlightFieldRow(
          label: 'People',
          value: '${flight.peopleCount}',
          onTap: () async {
            final result = await showNumberEditSheet(
              context,
              title: 'Number of People',
              currentValue: flight.peopleCount.toDouble(),
              hintText: 'e.g. 2',
            );
            if (result != null) {
              onChanged(flight.copyWith(peopleCount: result.toInt()));
            }
          },
        ),
        FlightFieldRow(
          label: 'Avg Person Weight',
          value: '${flight.avgPersonWeight.toStringAsFixed(0)} lbs',
          onTap: () async {
            final result = await showNumberEditSheet(
              context,
              title: 'Average Person Weight',
              currentValue: flight.avgPersonWeight,
              hintText: 'e.g. 170',
              suffix: 'lbs',
            );
            if (result != null) {
              onChanged(flight.copyWith(avgPersonWeight: result));
            }
          },
        ),
        FlightFieldRow(
          label: 'People Weight',
          value: '${totalPeopleWeight.toStringAsFixed(0)} lbs',
          valueColor: AppColors.textSecondary,
        ),
        FlightFieldRow(
          label: 'Cargo',
          value: '${flight.cargoWeight.toStringAsFixed(0)} lbs',
          onTap: () async {
            final result = await showNumberEditSheet(
              context,
              title: 'Cargo Weight',
              currentValue: flight.cargoWeight,
              hintText: 'e.g. 50',
              suffix: 'lbs',
            );
            if (result != null) {
              onChanged(flight.copyWith(cargoWeight: result));
            }
          },
        ),
        FlightFieldRow(
          label: 'Total Payload',
          value: '${totalPayload.toStringAsFixed(0)} lbs',
          valueColor: AppColors.textSecondary,
        ),
      ],
    );
  }
}
