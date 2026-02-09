import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import '../../../models/aircraft.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';

class FlightWeightsSection extends StatelessWidget {
  final Flight flight;
  final Aircraft? aircraft;

  const FlightWeightsSection({
    super.key,
    required this.flight,
    this.aircraft,
  });

  @override
  Widget build(BuildContext context) {
    final emptyWeight = aircraft?.emptyWeight;
    final fuelWeightPerGal = aircraft?.fuelWeightPerGallon ?? 6.7;
    final mtow = aircraft?.maxTakeoffWeight;
    final mlw = aircraft?.maxLandingWeight;

    if (emptyWeight == null) {
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

    final payloadWeight =
        flight.peopleCount * flight.avgPersonWeight + flight.cargoWeight;
    final zfw = emptyWeight + payloadWeight;
    final fuelWeight = (flight.startFuelGallons ?? 0) * fuelWeightPerGal;
    final rampWeight = zfw + fuelWeight;
    final takeoffWeight = rampWeight; // simplified, no taxi fuel
    final flightFuelWeight =
        (flight.flightFuelGallons ?? 0) * fuelWeightPerGal;
    final landingWeight = takeoffWeight - flightFuelWeight;

    final toExceeds = mtow != null && takeoffWeight > mtow;
    final ldgExceeds = mlw != null && landingWeight > mlw;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Weights (lbs)'),
        FlightFieldRow(
          label: 'Zero Fuel Weight',
          value: _fmt(zfw),
        ),
        FlightFieldRow(
          label: 'Ramp Weight',
          value: _fmt(rampWeight),
        ),
        FlightFieldRow(
          label: 'Takeoff Weight${mtow != null ? ' / ${_fmt(mtow)}' : ''}',
          value: _fmt(takeoffWeight),
          valueColor: toExceeds ? AppColors.error : null,
        ),
        FlightFieldRow(
          label: 'Landing Weight${mlw != null ? ' / ${_fmt(mlw)}' : ''}',
          value: _fmt(landingWeight),
          valueColor: ldgExceeds ? AppColors.error : null,
        ),
      ],
    );
  }

  String _fmt(double v) => v.round().toString();
}
