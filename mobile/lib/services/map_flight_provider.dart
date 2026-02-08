import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flight.dart';

/// Notifier for the flight currently loaded on the map.
class ActiveFlightNotifier extends Notifier<Flight?> {
  @override
  Flight? build() => null;

  void set(Flight? flight) => state = flight;

  void clear() => state = null;
}

/// The flight currently loaded on the map (shown in FPL panel & bottom bar).
final activeFlightProvider =
    NotifierProvider<ActiveFlightNotifier, Flight?>(ActiveFlightNotifier.new);
