import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/flight.dart';
import '../../services/api_client.dart';
import '../../services/flight_providers.dart';
import '../../services/aircraft_providers.dart';
import '../../services/logbook_providers.dart';
import 'widgets/flight_stats_bar.dart';
import 'widgets/flight_quick_actions.dart';
import 'widgets/flight_departure_section.dart';
import 'widgets/flight_aircraft_section.dart';
import 'widgets/flight_route_section.dart';
import 'widgets/flight_payload_section.dart';
import 'widgets/flight_fuel_section.dart';
import 'widgets/flight_weights_section.dart';
import 'widgets/flight_services_section.dart';
import 'widgets/flight_log_section.dart';
import 'widgets/flight_actions_section.dart';
import 'widgets/flight_filing_bar.dart';

class FlightDetailScreen extends ConsumerStatefulWidget {
  final int? flightId;

  const FlightDetailScreen({super.key, required this.flightId});

  @override
  ConsumerState<FlightDetailScreen> createState() =>
      _FlightDetailScreenState();
}

class _FlightDetailScreenState extends ConsumerState<FlightDetailScreen> {
  Flight _flight = const Flight();
  bool _loaded = false;
  bool _saving = false;

  bool get _isNew => widget.flightId == null && _flight.id == null;

  void _goBackToList() {
    ref.invalidate(flightsListProvider(''));
    context.go('/flights');
  }

  @override
  void initState() {
    super.initState();
    if (widget.flightId == null) {
      _flight = Flight(etd: DateTime.now().toIso8601String());
      _loaded = true;
      _applyDefaultAircraft();
    }
  }

  Future<void> _applyDefaultAircraft() async {
    final aircraft = await ref.read(defaultAircraftProvider.future);
    if (aircraft == null || !mounted) return;
    final dp = aircraft.defaultProfile;
    setState(() {
      _flight = _flight.copyWith(
        aircraftId: aircraft.id,
        aircraftIdentifier: aircraft.tailNumber,
        aircraftType: aircraft.aircraftType,
        performanceProfileId: dp?.id,
        performanceProfile: dp?.name,
        trueAirspeed: dp?.cruiseTas?.round(),
        fuelBurnRate: dp?.cruiseFuelBurn,
      );
    });
  }

  Future<void> _refreshFlight() async {
    if (_flight.id == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final json = await api.getFlight(_flight.id!);
      if (mounted) {
        setState(() => _flight = Flight.fromJson(json));
      }
    } catch (_) {}
  }

  Future<void> _saveField(Flight updated) async {
    setState(() {
      _flight = updated;
      _saving = true;
    });

    try {
      final service = ref.read(flightServiceProvider);
      if (_isNew) {
        final created = await service.createFlight(updated.toJson());
        setState(() => _flight = created);
      } else {
        final saved =
            await service.updateFlight(_flight.id!, updated.toJson());
        setState(() => _flight = saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Load existing flight from provider
    if (widget.flightId != null && !_loaded) {
      final flightAsync = ref.watch(flightDetailProvider(widget.flightId!));
      return flightAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _goBackToList(),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _goBackToList(),
            ),
          ),
          body: Center(
            child: Text('Error loading flight',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
        data: (flight) {
          if (flight != null && !_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _flight = flight;
                _loaded = true;
              });
            });
          }
          return _buildScaffold();
        },
      );
    }

    return _buildScaffold();
  }

  Widget _buildScaffold() {
    final dep = _flight.departureIdentifier ?? '----';
    final dest = _flight.destinationIdentifier ?? '----';
    final title = _isNew ? 'New Flight' : '$dep - $dest';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBackToList(),
        ),
        title: Text(title),
        centerTitle: true,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          FlightStatsBar(
            flight: _flight,
            onRecalculate: () => _saveField(_flight),
            apiClient: ref.read(apiClientProvider),
          ),
          Expanded(
            child: ListView(
              children: [
                const FlightQuickActions(),
                FlightDepartureSection(
                  flight: _flight,
                  onChanged: _saveField,
                ),
                FlightAircraftSection(
                  flight: _flight,
                  onChanged: _saveField,
                ),
                FlightRouteSection(
                  flight: _flight,
                  onChanged: _saveField,
                  apiClient: ref.read(apiClientProvider),
                ),
                FlightPayloadSection(
                  flight: _flight,
                  onChanged: _saveField,
                ),
                FlightFuelSection(
                  flight: _flight,
                  onChanged: _saveField,
                ),
                const FlightWeightsSection(),
                const FlightServicesSection(),
                FlightLogSection(
                  flight: _flight,
                  onChanged: _saveField,
                ),
                FlightActionsSection(
                  isNewFlight: _isNew,
                  onCopy: _handleCopy,
                  onDelete: _handleDelete,
                  onAddNext: () => context.go('/flights/new'),
                  onLogToLogbook: _handleLogToLogbook,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FlightFilingBar(
        flight: _flight,
        api: ref.read(apiClientProvider),
        onFlightUpdated: _refreshFlight,
      ),
    );
  }

  Future<void> _handleCopy() async {
    if (_flight.id == null) return;
    try {
      final service = ref.read(flightServiceProvider);
      final copy = await service.copyFlight(_flight.id!);
      if (mounted) {
        context.go('/flights/${copy.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to copy: $e')),
        );
      }
    }
  }

  Future<void> _handleLogToLogbook() async {
    try {
      // Extract date from ETD (ISO string → YYYY-MM-DD)
      String? date;
      DateTime? depTime;
      if (_flight.etd != null) {
        try {
          depTime = DateTime.parse(_flight.etd!);
          date =
              '${depTime.year}-${depTime.month.toString().padLeft(2, '0')}-${depTime.day.toString().padLeft(2, '0')}';
        } catch (_) {}
      }

      // Estimate total time: ETE + 0.2 hours for taxi/runup
      double? totalTime;
      if (_flight.eteMinutes != null) {
        totalTime = (_flight.eteMinutes! / 60.0) + 0.2;
        totalTime = (totalTime * 10).round() / 10;
      }

      // Estimate day/night (6:00–19:00 local = day)
      bool isDayDeparture = true;
      bool isDayArrival = true;
      if (depTime != null) {
        isDayDeparture = depTime.hour >= 6 && depTime.hour < 19;
        if (_flight.eteMinutes != null) {
          final arrTime =
              depTime.add(Duration(minutes: _flight.eteMinutes!));
          isDayArrival = arrTime.hour >= 6 && arrTime.hour < 19;
        }
      }

      final data = <String, dynamic>{
        'date': date,
        'aircraft_id': _flight.aircraftId,
        'aircraft_identifier': _flight.aircraftIdentifier,
        'aircraft_type': _flight.aircraftType,
        'from_airport': _flight.departureIdentifier,
        'to_airport': _flight.destinationIdentifier,
        'route': _flight.routeString,
        'distance': _flight.distanceNm,
        'total_time': totalTime ?? 0,
        'day_takeoffs': isDayDeparture ? 1 : 0,
        'night_takeoffs': isDayDeparture ? 0 : 1,
        'day_landings_full_stop': isDayArrival ? 1 : 0,
        'night_landings_full_stop': isDayArrival ? 0 : 1,
        'all_landings': 1,
      };

      final service = ref.read(logbookServiceProvider);
      final entry = await service.createEntry(data);
      if (mounted && entry.id != null) {
        context.go('/logbook/${entry.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create logbook entry: $e')),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    if (_flight.id == null) return;
    try {
      final service = ref.read(flightServiceProvider);
      await service.deleteFlight(_flight.id!);
      if (mounted) {
        _goBackToList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}
