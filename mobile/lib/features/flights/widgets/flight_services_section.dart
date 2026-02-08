import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';

class FlightServicesSection extends StatelessWidget {
  const FlightServicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlightSectionHeader(title: 'Services'),
        FlightFieldRow(
          label: 'Arrival FBO',
          value: 'No FBOs Available',
          valueColor: AppColors.textMuted,
        ),
        FlightFieldRow(
          label: 'Fuel Order',
          value: 'No FBOs Available',
          valueColor: AppColors.textMuted,
        ),
      ],
    );
  }
}
