import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';

class FlightWeightsSection extends StatelessWidget {
  const FlightWeightsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlightSectionHeader(title: 'Weights (lbs)'),
        FlightFieldRow(
          label: 'Zero Fuel Weight',
          value: '--',
          valueColor: AppColors.textSecondary,
        ),
        FlightFieldRow(
          label: 'Ramp Weight',
          value: '--',
          valueColor: AppColors.textSecondary,
        ),
        FlightFieldRow(
          label: 'Takeoff Weight',
          value: '--',
          valueColor: AppColors.textSecondary,
        ),
        FlightFieldRow(
          label: 'Landing Weight',
          value: '--',
          valueColor: AppColors.textSecondary,
        ),
      ],
    );
  }
}
