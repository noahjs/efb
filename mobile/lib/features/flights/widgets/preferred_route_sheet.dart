import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/flight_providers.dart';

/// Data returned when a preferred route is selected.
class SelectedRoute {
  final String routeString;
  final String? altitude;
  final String routeType;

  const SelectedRoute({
    required this.routeString,
    this.altitude,
    required this.routeType,
  });
}

/// Shows a bottom sheet with preferred routes between [origin] and [destination].
/// Returns a [SelectedRoute] if the user taps one, or null if dismissed.
Future<SelectedRoute?> showPreferredRouteSheet(
  BuildContext context, {
  required String origin,
  required String destination,
}) {
  return showModalBottomSheet<SelectedRoute>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => _PreferredRouteSheet(
        origin: origin,
        destination: destination,
        scrollController: scrollController,
      ),
    ),
  );
}

class _PreferredRouteSheet extends ConsumerStatefulWidget {
  final String origin;
  final String destination;
  final ScrollController scrollController;

  const _PreferredRouteSheet({
    required this.origin,
    required this.destination,
    required this.scrollController,
  });

  @override
  ConsumerState<_PreferredRouteSheet> createState() =>
      _PreferredRouteSheetState();
}

class _PreferredRouteSheetState extends ConsumerState<_PreferredRouteSheet> {
  String? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(preferredRoutesProvider(
      (origin: widget.origin, destination: widget.destination),
    ));

    return Column(
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                'Preferred Routes',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.origin} → ${widget.destination}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Filter chips (built from actual route types in data)
        routesAsync.when(
          data: (routes) {
            final types = routes
                .map((r) => r['route_type'] as String?)
                .where((t) => t != null && t.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList()
              ..sort();
            if (types.length <= 1) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _typeFilter == null,
                      onTap: () => setState(() => _typeFilter = null),
                    ),
                    for (final type in types)
                      _FilterChip(
                        label: type,
                        selected: _typeFilter == type,
                        onTap: () => setState(() => _typeFilter = type),
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const Divider(height: 1, color: AppColors.divider),

        // Route list
        Expanded(
          child: routesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load routes: $err',
                  style: const TextStyle(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (routes) {
              final filtered = _typeFilter != null
                  ? routes
                      .where((r) => r['route_type'] == _typeFilter)
                      .toList()
                  : routes;

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alt_route,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'No preferred routes found',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.origin} → ${widget.destination}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, index) {
                  final route = filtered[index];
                  return _RouteListTile(
                    route: route,
                    onTap: () {
                      Navigator.pop(
                        context,
                        SelectedRoute(
                          routeString: route['route_string'] as String? ?? '',
                          altitude: route['altitude'] as String?,
                          routeType: route['route_type'] as String? ?? '',
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteListTile extends StatelessWidget {
  final Map<String, dynamic> route;
  final VoidCallback onTap;

  const _RouteListTile({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = route['route_type'] as String? ?? '';
    final routeString = route['route_string'] as String? ?? '';
    final altitude = route['altitude'] as String?;
    final aircraft = route['aircraft'] as String?;
    final direction = route['direction'] as String?;
    final hours = route['hours'] as String?;

    // Build subtitle parts
    final subtitleParts = <String>[];
    if (altitude != null && altitude.isNotEmpty) subtitleParts.add(altitude);
    if (aircraft != null && aircraft.isNotEmpty) subtitleParts.add(aircraft);
    if (direction != null && direction.isNotEmpty) subtitleParts.add(direction);
    if (hours != null && hours.isNotEmpty) subtitleParts.add(hours);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _badgeColor(type),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                type,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Route details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routeString,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitleParts.join(' · '),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Color _badgeColor(String type) {
    switch (type.toUpperCase()) {
      case 'TEC':
        return AppColors.success;
      case 'H':
        return AppColors.primary;
      case 'L':
        return AppColors.info;
      case 'NAR':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }
}
