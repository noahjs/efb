import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  _RunwayEnd({
    required this.identifier,
    required this.heading,
    required this.latitude,
    required this.longitude,
  });
}

class _RunwayPair {
  final _RunwayEnd end1;
  final _RunwayEnd? end2;

  _RunwayPair({required this.end1, this.end2});

  bool contains(String id) => end1.identifier == id || end2?.identifier == id;
}

class _Platform3dViewScreenState extends State<Platform3dViewScreen> {
  GoogleMapController? _mapController;
  late final List<_RunwayPair> _runwayPairs;
  String? _selectedEndId;

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
        if (id != null && heading != null && lat != null && lng != null) {
          parsed.add(_RunwayEnd(
            identifier: id,
            heading: heading,
            latitude: lat,
            longitude: lng,
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

  CameraPosition _cameraForRunwayEnd(_RunwayEnd end) {
    final reciprocal = (end.heading + 180) % 360;
    final recipRad = reciprocal * pi / 180;
    const offsetMeters = 930.0;
    final latOffset = (offsetMeters / 111320) * cos(recipRad);
    final lngOffset =
        (offsetMeters / (111320 * cos(end.latitude * pi / 180))) * sin(recipRad);

    // Web: no tilt support, just bearing rotation
    return CameraPosition(
      target: LatLng(end.latitude + latOffset, end.longitude + lngOffset),
      bearing: end.heading,
      tilt: 0,
      zoom: 15.5,
    );
  }

  CameraPosition get _initialCamera {
    return CameraPosition(
      target: LatLng(_airportLat, _airportLng),
      zoom: 14,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final end = _findEnd(_selectedEndId);
    if (end != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _mapController?.animateCamera(
            CameraUpdate.newCameraPosition(_cameraForRunwayEnd(end)),
          );
        }
      });
    }
  }

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
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_cameraForRunwayEnd(target)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            mapType: MapType.satellite,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: _onMapCreated,
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
                      const SizedBox(width: 48),
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
