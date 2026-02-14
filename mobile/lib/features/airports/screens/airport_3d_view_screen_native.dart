import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';

class Platform3dViewScreen extends StatefulWidget {
  final Map<String, dynamic> airport;

  const Platform3dViewScreen({super.key, required this.airport});

  @override
  State<Platform3dViewScreen> createState() => _Platform3dViewScreenState();
}

class _RunwayEnd {
  final String identifier;
  final double heading;
  final double latitude;
  final double longitude;
  final bool isRightTraffic;

  _RunwayEnd({
    required this.identifier,
    required this.heading,
    required this.latitude,
    required this.longitude,
    this.isRightTraffic = false,
  });
}

class _RunwayPair {
  final _RunwayEnd end1;
  final _RunwayEnd? end2;

  _RunwayPair({required this.end1, this.end2});

  bool contains(String id) => end1.identifier == id || end2?.identifier == id;
}

class _Platform3dViewScreenState extends State<Platform3dViewScreen> {
  MapboxMap? _mapboxMap;
  late final List<_RunwayPair> _runwayPairs;
  String? _selectedEndId;
  bool _patternSourceReady = false;

  double get _airportLat => (widget.airport['latitude'] as num?)?.toDouble() ?? 0;
  double get _airportLng => (widget.airport['longitude'] as num?)?.toDouble() ?? 0;
  num? get _elevation => widget.airport['elevation'] as num?;

  String get _airportName {
    final icao = widget.airport['icao_identifier'] as String? ?? '';
    final name = widget.airport['name'] as String? ?? '';
    if (icao.isNotEmpty) return '$icao — $name';
    return name;
  }

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(AppConfig.mapboxToken);
    _runwayPairs = _groupIntoPairs();
    final longest = _longestPair();
    _selectedEndId = longest?.end1.identifier ?? _runwayPairs.firstOrNull?.end1.identifier;
  }

  _RunwayPair? _longestPair() {
    final runways = widget.airport['runways'] as List<dynamic>? ?? [];
    int bestIdx = -1;
    int bestLength = 0;

    for (int i = 0; i < runways.length && i < _runwayPairs.length; i++) {
      final length = (runways[i]['length'] as num?)?.toInt() ?? 0;
      if (length > bestLength) {
        bestLength = length;
        bestIdx = i;
      }
    }

    return bestIdx >= 0 ? _runwayPairs[bestIdx] : null;
  }

  List<_RunwayPair> _groupIntoPairs() {
    final runways = widget.airport['runways'] as List<dynamic>? ?? [];
    final pairs = <_RunwayPair>[];

    for (final runway in runways) {
      final ends = runway['ends'] as List<dynamic>? ?? [];
      final parsed = <_RunwayEnd>[];

      for (final end in ends) {
        final id = end['identifier'] as String?;
        final heading = (end['heading'] as num?)?.toDouble();
        final lat = (end['latitude'] as num?)?.toDouble();
        final lng = (end['longitude'] as num?)?.toDouble();
        final tp = end['traffic_pattern'] as String?;
        if (id != null && heading != null && lat != null && lng != null) {
          parsed.add(_RunwayEnd(
            identifier: id,
            heading: heading,
            latitude: lat,
            longitude: lng,
            isRightTraffic: tp?.toLowerCase() == 'right',
          ));
        }
      }

      if (parsed.length == 2) {
        pairs.add(_RunwayPair(end1: parsed[0], end2: parsed[1]));
      } else if (parsed.length == 1) {
        pairs.add(_RunwayPair(end1: parsed[0]));
      }
    }

    return pairs;
  }

  // ── Geo helpers ──────────────────────────────────────────────

  /// Offset a lat/lng by a bearing (degrees) and distance (meters).
  static (double, double) _offset(double lat, double lng, double bearingDeg, double meters) {
    final rad = bearingDeg * pi / 180;
    final dLat = (meters / 111320) * cos(rad);
    final dLng = (meters / (111320 * cos(lat * pi / 180))) * sin(rad);
    return (lat + dLat, lng + dLng);
  }

  // ── Camera ───────────────────────────────────────────────────

  CameraOptions _cameraForRunwayEnd(_RunwayEnd end) {
    final reciprocal = (end.heading + 180) % 360;
    final recipRad = reciprocal * pi / 180;
    const offsetMeters = 930.0; // ~0.5 NM
    final latOffset = (offsetMeters / 111320) * cos(recipRad);
    final lngOffset =
        (offsetMeters / (111320 * cos(end.latitude * pi / 180))) * sin(recipRad);

    return CameraOptions(
      center: Point(coordinates: Position(
        end.longitude + lngOffset,
        end.latitude + latOffset,
      )),
      bearing: end.heading,
      pitch: 75,
      zoom: 14,
    );
  }

  // ── Traffic pattern geometry ─────────────────────────────────

  /// Build a closed-loop traffic pattern as a list of [Position] (lng, lat, altMeters).
  ///
  /// Rectangle: upwind → crosswind → downwind → base → final, with
  /// rounded-ish corners using intermediate points.
  List<Position> _trafficPatternCoords(_RunwayEnd end, _RunwayEnd? opposite) {
    const sm = 1609.34;                // 1 statute mile in meters
    const patternOffset = 1.0 * sm;    // 1 mile from runway centerline
    const legExt = 1.0 * sm;           // extend 1 mi past each end of the runway

    final altMeters = ((_elevation?.toDouble() ?? 0) + 1000) * 0.3048;
    final h = end.heading;
    final recip = (h + 180) % 360;
    final perpDir = end.isRightTraffic ? h + 90 : h - 90;

    // Use the opposite runway end as the departure end if available,
    // otherwise fall back to 1 mi from threshold.
    final departureLat = opposite?.latitude ?? end.latitude;
    final departureLng = opposite?.longitude ?? end.longitude;

    // Corner points of the rectangular pattern
    // C1 = base/final corner (1 mi behind threshold on approach side)
    final (c1Lat, c1Lng) = _offset(end.latitude, end.longitude, recip, legExt);
    // C2 = upwind/crosswind corner (1 mi past the DEPARTURE end)
    final (c2Lat, c2Lng) = _offset(departureLat, departureLng, h, legExt);
    // C3 = crosswind/downwind corner (offset from C2)
    final (c3Lat, c3Lng) = _offset(c2Lat, c2Lng, perpDir, patternOffset);
    // C4 = downwind/base corner (offset from C1)
    final (c4Lat, c4Lng) = _offset(c1Lat, c1Lng, perpDir, patternOffset);

    Position p(double la, double ln) => Position(ln, la, altMeters);

    // Path: upwind → crosswind → downwind → base → close
    return [
      p(c1Lat, c1Lng),  // start of upwind (final approach end)
      p(c2Lat, c2Lng),  // end of upwind
      p(c3Lat, c3Lng),  // end of crosswind
      p(c4Lat, c4Lng),  // end of downwind
      p(c1Lat, c1Lng),  // close loop (base to final)
    ];
  }

  /// Build arrow point features along each leg of the pattern, spaced evenly.
  List<Map<String, dynamic>> _arrowFeatures(_RunwayEnd end, _RunwayEnd? opposite) {
    final coords = _trafficPatternCoords(end, opposite);
    final features = <Map<String, dynamic>>[];

    for (int i = 0; i < coords.length - 1; i++) {
      final a = coords[i];
      final b = coords[i + 1];

      // Bearing from a → b
      final dLng = b.lng - a.lng;
      final dLat = b.lat - a.lat;
      final bearing = (atan2(dLng, dLat) * 180 / pi) % 360;

      // Place arrows at 1/3 and 2/3 along each leg
      for (final t in [0.33, 0.67]) {
        features.add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [
              a.lng + dLng * t,
              a.lat + dLat * t,
              a.alt ?? 0,
            ],
          },
          'properties': {'bearing': bearing},
        });
      }
    }

    return features;
  }

  String _patternGeoJson(_RunwayEnd end, _RunwayEnd? opposite) {
    final coords = _trafficPatternCoords(end, opposite);
    final lineCoords = coords.map((p) => [p.lng, p.lat, p.alt ?? 0]).toList();
    final arrows = _arrowFeatures(end, opposite);

    final geojson = {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': lineCoords,
          },
          'properties': {},
        },
        ...arrows,
      ],
    };
    return jsonEncode(geojson);
  }

  // ── Map lifecycle ────────────────────────────────────────────

  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
  }

  void _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _mapboxMap;
    if (map == null) return;

    // Enable 3D terrain
    await map.style.addSource(RasterDemSource(
      id: 'mapbox-terrain-dem',
      url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
    ));
    await map.style.setStyleTerrain('{"source": "mapbox-terrain-dem", "exaggeration": 1.5}');

    // Add traffic pattern source + layers
    await _addPatternLayers(map);

    // Fly to selected runway
    final end = _findEnd(_selectedEndId);
    if (end != null) {
      _updatePattern(end);
      map.flyTo(
        _cameraForRunwayEnd(end),
        MapAnimationOptions(duration: 2000),
      );
    }
  }

  Future<void> _addPatternLayers(MapboxMap map) async {
    try {
      await map.style.addSource(
        GeoJsonSource(id: 'traffic-pattern', data: '{"type":"FeatureCollection","features":[]}'),
      );

      // Pattern line glow (wider, semi-transparent underneath)
      await map.style.addLayer(LineLayer(
        id: 'traffic-pattern-glow',
        sourceId: 'traffic-pattern',
        lineColor: const Color(0xFF00E5FF).toARGB32(),
        lineWidth: 12.0,
        lineOpacity: 0.15,
        filter: ['==', ['geometry-type'], 'LineString'],
      ));

      // Pattern line — cyan, solid
      await map.style.addLayer(LineLayer(
        id: 'traffic-pattern-line',
        sourceId: 'traffic-pattern',
        lineColor: const Color(0xFF00E5FF).toARGB32(),
        lineWidth: 5.0,
        lineOpacity: 0.9,
        filter: ['==', ['geometry-type'], 'LineString'],
      ));

      // Arrow symbols along the pattern
      await map.style.addLayer(SymbolLayer(
        id: 'traffic-pattern-arrows',
        sourceId: 'traffic-pattern',
        textField: '▸',
        textSize: 24.0,
        textColor: const Color(0xFFFFFFFF).toARGB32(),
        textRotationAlignment: TextRotationAlignment.MAP,
        textAllowOverlap: true,
        textPadding: 0.0,
        filter: ['==', ['geometry-type'], 'Point'],
      ));
      // Use expression for data-driven rotation
      await map.style.setStyleLayerProperty(
        'traffic-pattern-arrows', 'text-rotate', ['get', 'bearing'],
      );

      _patternSourceReady = true;
    } catch (e) {
      debugPrint('Failed to add traffic pattern layers: $e');
    }
  }

  _RunwayEnd? _oppositeEnd(_RunwayEnd end) {
    for (final pair in _runwayPairs) {
      if (pair.end1.identifier == end.identifier) return pair.end2;
      if (pair.end2?.identifier == end.identifier) return pair.end1;
    }
    return null;
  }

  void _updatePattern(_RunwayEnd end) {
    if (!_patternSourceReady || _mapboxMap == null) return;
    final geojson = _patternGeoJson(end, _oppositeEnd(end));
    _mapboxMap!.style.setStyleSourceProperty(
      'traffic-pattern',
      'data',
      geojson,
    );
  }

  // ── Runway end lookup ────────────────────────────────────────

  _RunwayEnd? _findEnd(String? id) {
    if (id == null) return null;
    for (final pair in _runwayPairs) {
      if (pair.end1.identifier == id) return pair.end1;
      if (pair.end2?.identifier == id) return pair.end2;
    }
    return null;
  }

  void _onRunwayPairTap(_RunwayPair pair) {
    _RunwayEnd target;
    if (pair.contains(_selectedEndId ?? '')) {
      target = pair.end1.identifier == _selectedEndId
          ? (pair.end2 ?? pair.end1)
          : pair.end1;
    } else {
      target = pair.end1;
    }
    setState(() => _selectedEndId = target.identifier);
    _updatePattern(target);
    _mapboxMap?.flyTo(
      _cameraForRunwayEnd(target),
      MapAnimationOptions(duration: 1500),
    );
  }

  bool get _isSupported => Platform.isIOS || Platform.isAndroid;

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_airportName),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_in_ar, size: 48, color: AppColors.textMuted),
              SizedBox(height: 16),
              Text(
                '3D View is available on iOS and Android',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen Mapbox Map
          MapWidget(
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(_airportLng, _airportLat)),
              zoom: 12,
              pitch: 75,
            ),
            styleUri: MapboxStyles.SATELLITE_STREETS,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.surface.withValues(alpha: 0.85),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          _airportName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the close button
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Info chips below top bar
          if (_elevation != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 52,
              left: 12,
              child: _InfoChip(
                label: '${_elevation!.round()}\' MSL',
                icon: Icons.terrain,
              ),
            ),

          // Runway selector bottom bar
          if (_runwayPairs.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: AppColors.surface.withValues(alpha: 0.85),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: _runwayPairs.map((pair) {
                        final isActive = pair.contains(_selectedEndId ?? '');
                        String label;
                        if (pair.end2 == null) {
                          label = pair.end1.identifier;
                        } else if (isActive && _selectedEndId == pair.end2!.identifier) {
                          label = '${pair.end2!.identifier}/${pair.end1.identifier}';
                        } else {
                          label = '${pair.end1.identifier}/${pair.end2!.identifier}';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _onRunwayPairTap(pair),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : AppColors.surface.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isActive ? AppColors.accent : AppColors.divider,
                                  width: isActive ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? AppColors.accent : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
