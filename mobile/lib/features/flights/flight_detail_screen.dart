import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/flight.dart';
import '../../services/api_client.dart';
import '../../services/flight_providers.dart';
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
    }
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
                ),
                if (_flight.id != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: GestureDetector(
                      onTap: () => _showCalculationDebug(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bug_report,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'View Calculation Debug',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FlightFilingBar(
        filingStatus: _flight.filingStatus,
      ),
    );
  }

  void _showCalculationDebug() {
    showCalculationDebugSheet(
      context,
      _flight.id!,
      ref.read(apiClientProvider),
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
