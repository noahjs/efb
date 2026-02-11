import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/route_profile.dart';
import 'api_client.dart';

/// Parameters for a route profile request.
/// Equality is based on waypoint identifiers + altitude + tas so the
/// provider deduplicates identical requests.
@immutable
class RouteProfileParams {
  final List<Map<String, double>> waypoints;
  final List<String> identifiers;
  final int altitude;
  final int tas;

  const RouteProfileParams({
    required this.waypoints,
    required this.identifiers,
    required this.altitude,
    required this.tas,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteProfileParams &&
          listEquals(identifiers, other.identifiers) &&
          altitude == other.altitude &&
          tas == other.tas;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(identifiers),
        altitude,
        tas,
      );
}

/// Fetches the route profile (elevation + wind) for a set of waypoints.
final routeProfileProvider =
    FutureProvider.family<RouteProfileData?, RouteProfileParams>(
        (ref, params) async {
  if (params.waypoints.length < 2) return null;

  final client = ref.read(apiClientProvider);
  try {
    final json = await client.getRouteProfile(
      waypoints: params.waypoints,
      altitude: params.altitude,
      tas: params.tas,
      waypointIdentifiers: params.identifiers,
    );

    if (json == null) return null;
    return RouteProfileData.fromJson(json);
  } catch (e) {
    return null;
  }
});
