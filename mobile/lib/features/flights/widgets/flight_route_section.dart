import 'package:flutter/material.dart';
import '../../../models/flight.dart';
import '../../../services/api_client.dart';
import 'altitude_picker_sheet.dart';
import 'flight_route_map.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';
import 'flight_edit_dialogs.dart';
import 'preferred_route_sheet.dart';

/// Try to parse an altitude string like "4000", "FL350", "350" into feet.
int? _parseAltitude(String? alt) {
  if (alt == null || alt.isEmpty) return null;
  final cleaned = alt.toUpperCase().replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.isEmpty) return null;
  final num = int.tryParse(cleaned);
  if (num == null) return null;
  // If original had "FL" or the number is small (e.g. 350 = FL350), multiply
  if (alt.toUpperCase().contains('FL') || (num > 0 && num <= 600)) {
    return num * 100;
  }
  return num;
}

String _formatAltitudeDisplay(int ft) {
  if (ft >= 18000) return 'FL${ft ~/ 100}';
  final s = ft.toString();
  if (s.length <= 3) return "$s'";
  return "${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}'";
}

class FlightRouteSection extends StatelessWidget {
  final Flight flight;
  final ValueChanged<Flight> onChanged;
  final ApiClient apiClient;

  const FlightRouteSection({
    super.key,
    required this.flight,
    required this.onChanged,
    required this.apiClient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Route'),
        FlightFieldRow(
          label: 'Flight Rules',
          value: flight.flightRules,
          onTap: () async {
            final result = await showPickerSheet(
              context,
              title: 'Flight Rules',
              options: ['VFR', 'IFR', 'DVFR', 'SVFR'],
              currentValue: flight.flightRules,
            );
            if (result != null) {
              onChanged(flight.copyWith(flightRules: result));
            }
          },
        ),
        FlightRouteMap(
          departureIdentifier: flight.departureIdentifier,
          destinationIdentifier: flight.destinationIdentifier,
        ),
        FlightFieldRow(
          label: 'Route',
          value: flight.routeString ?? 'Direct',
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Route String',
              currentValue: flight.routeString ?? '',
              hintText: 'e.g. DCT BJC V8 DBL',
            );
            if (result != null) {
              onChanged(flight.copyWith(routeString: result));
            }
          },
        ),
        FlightFieldRow(
          label: 'Routes',
          value: 'Find Routes',
          showChevron: true,
          onTap: () async {
            final dep = flight.departureIdentifier;
            final dest = flight.destinationIdentifier;
            if (dep == null ||
                dep.isEmpty ||
                dest == null ||
                dest.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Set departure and destination first'),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            final result = await showPreferredRouteSheet(
              context,
              origin: dep,
              destination: dest,
            );
            if (result != null) {
              final altFt = _parseAltitude(result.altitude);
              onChanged(flight.copyWith(
                routeString: result.routeString,
                cruiseAltitude: altFt ?? flight.cruiseAltitude,
              ));
            }
          },
        ),
        FlightFieldRow(
          label: 'Cruise Altitude',
          value: flight.cruiseAltitude != null
              ? _formatAltitudeDisplay(flight.cruiseAltitude!)
              : 'Set',
          onTap: () async {
            final result = await showAltitudePickerSheet(
              context,
              apiClient: apiClient,
              currentAltitude: flight.cruiseAltitude,
              departureIdentifier: flight.departureIdentifier,
              destinationIdentifier: flight.destinationIdentifier,
              routeString: flight.routeString,
              trueAirspeed: flight.trueAirspeed,
              fuelBurnRate: flight.fuelBurnRate,
              performanceProfileId: flight.performanceProfileId,
            );
            if (result != null) {
              onChanged(flight.copyWith(cruiseAltitude: result));
            }
          },
        ),
      ],
    );
  }
}
