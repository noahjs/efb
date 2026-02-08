import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/airport_providers.dart';
import 'flight_route_map_native.dart'
    if (dart.library.html) 'flight_route_map_web.dart' as platform_route_map;

class FlightRouteMap extends ConsumerStatefulWidget {
  final String? departureIdentifier;
  final String? destinationIdentifier;

  const FlightRouteMap({
    super.key,
    this.departureIdentifier,
    this.destinationIdentifier,
  });

  @override
  ConsumerState<FlightRouteMap> createState() => _FlightRouteMapState();
}

class _FlightRouteMapState extends ConsumerState<FlightRouteMap> {
  @override
  Widget build(BuildContext context) {
    final dep = widget.departureIdentifier;
    final dest = widget.destinationIdentifier;

    if (dep == null || dep.isEmpty || dest == null || dest.isEmpty) {
      return _placeholder('Set departure and destination to see route');
    }

    final depAirport = ref.watch(airportDetailProvider(dep));
    final destAirport = ref.watch(airportDetailProvider(dest));

    return depAirport.when(
      loading: () => _placeholder('Loading...'),
      error: (_, _) => _placeholder('Could not load airports'),
      data: (depData) {
        if (depData == null) return _placeholder('Departure airport not found');
        return destAirport.when(
          loading: () => _placeholder('Loading...'),
          error: (_, _) => _placeholder('Could not load airports'),
          data: (destData) {
            if (destData == null) {
              return _placeholder('Destination airport not found');
            }
            final depLat = (depData['latitude'] as num?)?.toDouble();
            final depLng = (depData['longitude'] as num?)?.toDouble();
            final destLat = (destData['latitude'] as num?)?.toDouble();
            final destLng = (destData['longitude'] as num?)?.toDouble();

            if (depLat == null ||
                depLng == null ||
                destLat == null ||
                destLng == null) {
              return _placeholder('Airport coordinates unavailable');
            }

            return platform_route_map.PlatformRouteMapView(
              depId: dep,
              depLat: depLat,
              depLng: depLng,
              destId: dest,
              destLat: destLat,
              destLng: destLng,
            );
          },
        );
      },
    );
  }

  Widget _placeholder(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}
