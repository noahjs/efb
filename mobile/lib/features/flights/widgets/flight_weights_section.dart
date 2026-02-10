import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import '../../../models/aircraft.dart';
import '../../../services/wb_providers.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';

class FlightWeightsSection extends ConsumerWidget {
  final Flight flight;
  final Aircraft? aircraft;

  const FlightWeightsSection({
    super.key,
    required this.flight,
    this.aircraft,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emptyWeight = aircraft?.emptyWeight;
    final fuelWeightPerGal = aircraft?.fuelWeightPerGallon ?? 6.7;
    final mtow = aircraft?.maxTakeoffWeight;
    final mlw = aircraft?.maxLandingWeight;

    // Check if flight has a W&B scenario
    final hasFlightId = flight.id != null;
    final hasAircraft = flight.aircraftId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Weight & Balance'),

        // W&B navigation card (when flight is saved with an aircraft)
        if (hasFlightId && hasAircraft)
          _buildWBCard(context, ref),

        // Simple weight summary below
        if (emptyWeight != null)
          ..._buildSimpleWeights(
              emptyWeight, fuelWeightPerGal, mtow, mlw),
      ],
    );
  }

  Widget _buildWBCard(BuildContext context, WidgetRef ref) {
    // Try to peek at existing scenario data for status display
    final wbAsync = ref.watch(flightWBProvider(flight.id!));

    final statusIcon = wbAsync.whenOrNull(
      data: (data) => data.scenario.isWithinEnvelope
          ? Icons.check_circle
          : Icons.warning,
    );
    final statusColor = wbAsync.whenOrNull(
      data: (data) => data.scenario.isWithinEnvelope
          ? AppColors.success
          : AppColors.error,
    );
    final statusText = wbAsync.whenOrNull(
      data: (data) =>
          data.scenario.isWithinEnvelope ? 'Within limits' : 'Exceeds limits',
      error: (e, _) {
        final msg = e.toString();
        if (msg.contains('No W&B profile')) return 'Not configured';
        return null;
      },
    );

    return InkWell(
      onTap: () => context.push('/flights/${flight.id}/wb'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              statusIcon ?? Icons.balance,
              size: 20,
              color: statusColor ?? AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Station Loading & CG',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (statusText != null)
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 13,
                  color: statusColor ?? AppColors.textMuted,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSimpleWeights(
      double emptyWeight, double fuelWeightPerGal, double? mtow, double? mlw) {
    final payloadWeight =
        flight.peopleCount * flight.avgPersonWeight + flight.cargoWeight;
    final zfw = emptyWeight + payloadWeight;
    final fuelWeight = (flight.startFuelGallons ?? 0) * fuelWeightPerGal;
    final rampWeight = zfw + fuelWeight;
    final takeoffWeight = rampWeight;
    final flightFuelWeight =
        (flight.flightFuelGallons ?? 0) * fuelWeightPerGal;
    final landingWeight = takeoffWeight - flightFuelWeight;

    final toExceeds = mtow != null && takeoffWeight > mtow;
    final ldgExceeds = mlw != null && landingWeight > mlw;

    return [
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
    ];
  }

  String _fmt(double v) => v.round().toString();
}
