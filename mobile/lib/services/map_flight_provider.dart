import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/flight.dart';

const _storageKey = 'active_flight';

/// Notifier for the flight currently loaded on the map.
/// Automatically persists to SharedPreferences so the FPL
/// survives app restarts.
class ActiveFlightNotifier extends Notifier<Flight?> {
  @override
  Flight? build() {
    // Kick off async load — will update state when ready.
    _loadFromDisk();
    return null;
  }

  void set(Flight? flight) {
    state = flight;
    _saveToDisk(flight);
  }

  void clear() {
    state = null;
    _removeDisk();
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_storageKey);
    if (str == null) return;
    try {
      final json = jsonDecode(str) as Map<String, dynamic>;
      // Only restore if nothing has been set in the meantime.
      if (state == null) {
        state = Flight.fromJson(json);
      }
    } catch (_) {
      // Corrupt data — ignore.
    }
  }

  Future<void> _saveToDisk(Flight? flight) async {
    final prefs = await SharedPreferences.getInstance();
    if (flight == null) {
      prefs.remove(_storageKey);
    } else {
      prefs.setString(_storageKey, jsonEncode(flight.toFullJson()));
    }
  }

  Future<void> _removeDisk() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_storageKey);
  }
}

/// The flight currently loaded on the map (shown in FPL panel & bottom bar).
final activeFlightProvider =
    NotifierProvider<ActiveFlightNotifier, Flight?>(ActiveFlightNotifier.new);
