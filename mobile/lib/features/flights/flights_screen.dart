import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/flight.dart';
import '../../services/flight_providers.dart';

class FlightsScreen extends ConsumerStatefulWidget {
  const FlightsScreen({super.key});

  @override
  ConsumerState<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends ConsumerState<FlightsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final flightsAsync = ref.watch(flightsListProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flights'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: AppColors.accent,
            onPressed: () => context.go('/flights/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search flights...',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppColors.textMuted, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Flights list
          Expanded(
            child: flightsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load flights',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(
                          flightsListProvider(_searchQuery)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (flights) {
                if (flights.isEmpty) {
                  return const EmptyState(
                    icon: Icons.flight_takeoff,
                    title: 'No Flights',
                    subtitle: 'Tap + to create a new flight',
                  );
                }
                return _buildGroupedList(flights);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<Flight> flights) {
    final grouped = <String, List<Flight>>{};
    final monthFormat = DateFormat('MMMM yyyy');

    for (final flight in flights) {
      String key = 'NO DATE';
      if (flight.etd != null) {
        try {
          final date = DateTime.parse(flight.etd!);
          key = monthFormat.format(date).toUpperCase();
        } catch (_) {
          // keep default
        }
      }
      grouped.putIfAbsent(key, () => []).add(flight);
    }

    final sections = grouped.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sections.fold<int>(
          0, (sum, e) => sum + 1 + e.value.length),
      itemBuilder: (context, index) {
        int cursor = 0;
        for (final section in sections) {
          if (index == cursor) {
            return _buildMonthHeader(section.key);
          }
          cursor++;
          if (index < cursor + section.value.length) {
            return _buildFlightCard(section.value[index - cursor]);
          }
          cursor += section.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMonthHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildFlightCard(Flight flight) {
    final dep = flight.departureIdentifier ?? '----';
    final dest = flight.destinationIdentifier ?? '----';
    final rules = flight.flightRules;
    final altitude = flight.cruiseAltitude != null
        ? '${flight.cruiseAltitude} ft'
        : '--';
    final tail = flight.aircraftIdentifier ?? '--';

    String etdDisplay = '--';
    if (flight.etd != null) {
      try {
        final date = DateTime.parse(flight.etd!);
        etdDisplay = DateFormat('MMM d, h:mm a').format(date);
      } catch (_) {
        etdDisplay = flight.etd!;
      }
    }

    return InkWell(
      onTap: () {
        if (flight.id != null) {
          context.go('/flights/${flight.id}');
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Departure → Destination (rules)
                  Row(
                    children: [
                      Text(dep,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward,
                            size: 14, color: AppColors.textMuted),
                      ),
                      Text(dest,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      const SizedBox(width: 8),
                      Text('($rules)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Altitude + tail
                  Text('$altitude  •  $tail',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      )),
                  const SizedBox(height: 2),
                  // ETD
                  Text(etdDisplay,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      )),
                  // Route
                  if (flight.routeString != null &&
                      flight.routeString!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        flight.routeString!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
