import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/flight.dart';
import '../../../services/api_client.dart';
import '../../../services/flight_providers.dart';
import '../../../services/map_flight_provider.dart';

/// Performs a "Direct To" action — sets this identifier as the sole
/// destination of the active flight (or creates a new one).
void directTo(BuildContext context, WidgetRef ref, String identifier) {
  final flight = ref.read(activeFlightProvider);
  final updated = (flight ?? const Flight()).copyWith(
    destinationIdentifier: identifier.toUpperCase(),
    routeString: identifier.toUpperCase(),
    departureIdentifier: flight?.departureIdentifier ?? '',
  );
  _saveAndClose(context, ref, updated);
}

/// Appends an identifier to the active flight's route string.
void addToRoute(BuildContext context, WidgetRef ref, String identifier) {
  final flight = ref.read(activeFlightProvider);
  final f = flight ?? const Flight();
  final existing = f.routeString?.trim() ?? '';
  final id = identifier.toUpperCase();
  final newRoute = existing.isEmpty ? id : '$existing $id';
  final waypoints = newRoute.split(RegExp(r'\s+'));
  final updated = f.copyWith(
    routeString: newRoute,
    departureIdentifier: waypoints.first,
    destinationIdentifier: waypoints.length > 1 ? waypoints.last : waypoints.first,
  );
  _saveAndClose(context, ref, updated);
}

/// Saves the flight update and closes the sheet.
Future<void> _saveAndClose(
    BuildContext context, WidgetRef ref, Flight updated) async {
  ref.read(activeFlightProvider.notifier).set(updated);
  Navigator.of(context).pop();

  // Persist if it's a saved flight, otherwise just calculate
  try {
    if (updated.id != null) {
      final service = ref.read(flightServiceProvider);
      final saved = await service.updateFlight(updated.id!, updated.toJson());
      ref.read(activeFlightProvider.notifier).set(saved);
    } else {
      final api = ref.read(apiClientProvider);
      final result = await api.calculateFlight(
        departureIdentifier: updated.departureIdentifier,
        destinationIdentifier: updated.destinationIdentifier,
        routeString: updated.routeString,
        cruiseAltitude: updated.cruiseAltitude,
        trueAirspeed: updated.trueAirspeed,
        fuelBurnRate: updated.fuelBurnRate,
        etd: updated.etd,
        performanceProfileId: updated.performanceProfileId,
      );
      ref.read(activeFlightProvider.notifier).set(Flight(
            id: updated.id,
            aircraftId: updated.aircraftId,
            performanceProfileId: updated.performanceProfileId,
            departureIdentifier: updated.departureIdentifier,
            destinationIdentifier: updated.destinationIdentifier,
            alternateIdentifier: updated.alternateIdentifier,
            etd: updated.etd,
            aircraftIdentifier: updated.aircraftIdentifier,
            aircraftType: updated.aircraftType,
            performanceProfile: updated.performanceProfile,
            trueAirspeed: updated.trueAirspeed,
            flightRules: updated.flightRules,
            routeString: updated.routeString,
            cruiseAltitude: updated.cruiseAltitude,
            peopleCount: updated.peopleCount,
            avgPersonWeight: updated.avgPersonWeight,
            cargoWeight: updated.cargoWeight,
            fuelPolicy: updated.fuelPolicy,
            startFuelGallons: updated.startFuelGallons,
            reserveFuelGallons: updated.reserveFuelGallons,
            fuelBurnRate: updated.fuelBurnRate,
            fuelAtShutdownGallons: updated.fuelAtShutdownGallons,
            filingStatus: updated.filingStatus,
            distanceNm: (result['distance_nm'] as num?)?.toDouble(),
            eteMinutes: result['ete_minutes'] as int?,
            flightFuelGallons:
                (result['flight_fuel_gallons'] as num?)?.toDouble(),
            eta: result['eta'] as String?,
            calculatedAt: result['calculated_at'] as String?,
          ));
    }
  } catch (_) {
    // Calculation may fail for incomplete flights — that's ok
  }
}

/// Shows a "coming soon" snackbar for unimplemented features.
void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$feature coming soon'),
      duration: const Duration(seconds: 2),
    ),
  );
}
