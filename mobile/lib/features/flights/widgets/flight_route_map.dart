import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_client.dart';
import 'flight_route_map_native.dart'
    if (dart.library.html) 'flight_route_map_web.dart' as platform_route_map;

class FlightRouteMap extends ConsumerStatefulWidget {
  final String? departureIdentifier;
  final String? destinationIdentifier;
  final String? routeString;

  const FlightRouteMap({
    super.key,
    this.departureIdentifier,
    this.destinationIdentifier,
    this.routeString,
  });

  @override
  ConsumerState<FlightRouteMap> createState() => _FlightRouteMapState();
}

class _FlightRouteMapState extends ConsumerState<FlightRouteMap> {
  List<_RoutePoint>? _resolvedPoints;
  bool _loading = false;
  String? _lastRouteKey;

  String get _routeKey =>
      '${widget.departureIdentifier}|${widget.routeString}|${widget.destinationIdentifier}';

  @override
  void didUpdateWidget(FlightRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_routeKey != _lastRouteKey) {
      _resolveRoute();
    }
  }

  @override
  void initState() {
    super.initState();
    _resolveRoute();
  }

  Future<void> _resolveRoute() async {
    final dep = widget.departureIdentifier;
    final dest = widget.destinationIdentifier;
    if (dep == null || dep.isEmpty || dest == null || dest.isEmpty) {
      setState(() {
        _resolvedPoints = null;
        _lastRouteKey = _routeKey;
      });
      return;
    }

    setState(() => _loading = true);
    _lastRouteKey = _routeKey;

    // Build the full identifier list: departure + route waypoints + destination
    final identifiers = <String>[dep];
    final route = widget.routeString;
    if (route != null && route.isNotEmpty) {
      // Split route string by spaces, filter out common non-waypoint tokens
      final tokens = route.split(RegExp(r'\s+'));
      for (final token in tokens) {
        final t = token.toUpperCase().trim();
        if (t.isEmpty) continue;
        // Skip common route string keywords that aren't waypoints
        if (t == 'DCT' || t == 'DIRECT' || t == dep.toUpperCase() || t == dest.toUpperCase()) {
          continue;
        }
        identifiers.add(t);
      }
    }
    identifiers.add(dest);

    try {
      final api = ref.read(apiClientProvider);
      final resolved = await api.resolveWaypoints(identifiers);
      if (!mounted || _routeKey != _lastRouteKey) return;

      final points = <_RoutePoint>[];
      for (final wp in resolved) {
        final lat = (wp['latitude'] as num?)?.toDouble();
        final lng = (wp['longitude'] as num?)?.toDouble();
        final id = wp['identifier'] as String? ?? '';
        if (lat != null && lng != null) {
          points.add(_RoutePoint(
            identifier: id,
            latitude: lat,
            longitude: lng,
            isEndpoint: id.toUpperCase() == dep.toUpperCase() ||
                id.toUpperCase() == dest.toUpperCase(),
          ));
        }
      }

      setState(() {
        _resolvedPoints = points;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedPoints = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dep = widget.departureIdentifier;
    final dest = widget.destinationIdentifier;

    if (dep == null || dep.isEmpty || dest == null || dest.isEmpty) {
      return _placeholder('Set departure and destination to see route');
    }

    if (_loading || _resolvedPoints == null) {
      return _placeholder('Loading route...');
    }

    final points = _resolvedPoints!;
    if (points.length < 2) {
      return _placeholder('Could not resolve route');
    }

    return platform_route_map.PlatformRouteMapView(
      routePoints: points.map((p) => p.toMap()).toList(),
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

class _RoutePoint {
  final String identifier;
  final double latitude;
  final double longitude;
  final bool isEndpoint;

  const _RoutePoint({
    required this.identifier,
    required this.latitude,
    required this.longitude,
    required this.isEndpoint,
  });

  Map<String, dynamic> toMap() => {
        'identifier': identifier,
        'latitude': latitude,
        'longitude': longitude,
        'isEndpoint': isEndpoint,
      };
}
