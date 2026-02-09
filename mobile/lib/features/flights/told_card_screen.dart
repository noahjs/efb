import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/aircraft.dart';
import '../../models/flight.dart';
import '../../services/flight_providers.dart';
import '../../services/aircraft_providers.dart';
import '../../services/told_providers.dart';

class ToldCardScreen extends ConsumerWidget {
  final int flightId;
  final ToldMode mode;

  const ToldCardScreen({
    super.key,
    required this.flightId,
    required this.mode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flightAsync = ref.watch(flightDetailProvider(flightId));
    final params = ToldParams(flightId: flightId, mode: mode);
    final notifier = ref.watch(toldNotifierProvider(params));

    return flightAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('TOLD Card')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('TOLD Card')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (flight) {
        if (flight == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('TOLD Card')),
            body: const Center(child: Text('Flight not found')),
          );
        }

        Aircraft? aircraft;
        if (flight.aircraftId != null) {
          final acAsync =
              ref.watch(aircraftDetailProvider(flight.aircraftId!));
          aircraft = acAsync.whenData((a) => a).value;
        }

        return ListenableBuilder(
          listenable: notifier,
          builder: (context, _) =>
              _buildCard(context, flight, aircraft, notifier.state),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    Flight flight,
    Aircraft? aircraft,
    ToldState toldState,
  ) {
    final result = toldState.result;
    final modeLabel = mode == ToldMode.takeoff ? 'TAKEOFF' : 'LANDING';
    final airportId = mode == ToldMode.takeoff
        ? flight.departureIdentifier
        : flight.destinationIdentifier;
    final airportName =
        toldState.airportData?['name'] as String? ?? airportId ?? '--';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('TOLD Card'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Column(
                  children: [
                    Text(
                      '$modeLabel PERFORMANCE',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$airportName - Rwy ${toldState.runwayEndIdentifier ?? '--'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              // Aircraft info
              _cardRow(
                'Aircraft',
                '${aircraft?.tailNumber ?? '--'} (${aircraft?.aircraftType ?? '--'})',
              ),
              // Environment
              _cardRow(
                'Elevation',
                '${toldState.runwayElevation?.round() ?? '--'}\' MSL',
              ),
              _cardRow(
                'PA',
                '${result?.pressureAltitude.round() ?? '--'}\' MSL',
              ),
              _cardRow(
                'Altimeter',
                '${toldState.altimeter?.toStringAsFixed(2) ?? '--'} inHg',
              ),
              _cardRow(
                'OAT',
                '${toldState.tempC?.round() ?? '--'}°C',
              ),
              _cardRow(
                'Wind',
                '${toldState.windDir?.round() ?? '--'}° at '
                    '${toldState.windSpeed?.round() ?? '--'} kts',
              ),
              const Divider(color: AppColors.divider, height: 1),
              // Weights
              _cardRow(
                'Actual Weight',
                '${result?.weight.round() ?? '--'} lbs',
                valueColor:
                    result?.isOverweight == true ? AppColors.error : null,
              ),
              _cardRow(
                'Max Weight',
                '${result?.maxWeight?.round() ?? '--'} lbs',
              ),
              const Divider(color: AppColors.divider, height: 1),
              // Config
              _cardRow('Surface', _surfaceLabel(toldState.surfaceType)),
              _cardRow('Safety Factor', '${toldState.safetyFactor}x'),
              _cardRow(
                'Flaps',
                toldState.flapCode?.toUpperCase() ?? '--',
              ),
              const Divider(color: AppColors.divider, height: 1),
              // Results
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _resultRow(
                      mode == ToldMode.takeoff ? 'VR' : 'VAPP',
                      '${result?.vrKias?.round() ?? '--'} KIAS',
                    ),
                    const SizedBox(height: 8),
                    _resultRow(
                      'TOT DIST',
                      '${result?.totalDistanceFt?.round() ?? '--'} ft',
                      valueColor: result?.exceedsRunway == true
                          ? AppColors.error
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _resultRow(
                      'GND ROLL',
                      '${result?.groundRollFt?.round() ?? '--'} ft',
                    ),
                  ],
                ),
              ),
              // Timestamp
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  result != null
                      ? 'Calculated: ${DateFormat('MMM d, yyyy HH:mm').format(result.calculatedAt)}'
                      : '',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (toldState.metarRaw != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'METAR: ${toldState.metarRaw}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _surfaceLabel(String type) {
    const labels = {
      'paved_dry': 'Paved / Dry',
      'paved_wet': 'Paved / Wet',
      'grass_dry': 'Grass / Dry',
      'grass_wet': 'Grass / Wet',
    };
    return labels[type] ?? type;
  }
}
