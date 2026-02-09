import 'dart:io' show Platform;
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
}

class _Platform3dViewScreenState extends State<Platform3dViewScreen> {
  GoogleMapController? _mapController;
  late final List<_RunwayEnd> _runwayEnds;
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
    _runwayEnds = _extractRunwayEnds();
    _runwayPairs = _groupIntoPairs();
    if (_runwayEnds.isNotEmpty) {
      _selectedEndId = _runwayEnds.first.identifier;
    }
  }

  List<_RunwayEnd> _extractRunwayEnds() {
    final runways = widget.airport['runways'] as List<dynamic>? ?? [];
    final ends = <_RunwayEnd>[];

    for (final runway in runways) {
      final runwayEnds = runway['ends'] as List<dynamic>? ?? [];
      for (final end in runwayEnds) {
        final id = end['identifier'] as String?;
        final heading = (end['true_heading'] as num?)?.toDouble();
        final lat = (end['latitude'] as num?)?.toDouble();
        final lng = (end['longitude'] as num?)?.toDouble();
        if (id != null && heading != null && lat != null && lng != null) {
          ends.add(_RunwayEnd(
            identifier: id,
            heading: heading,
            latitude: lat,
            longitude: lng,
          ));
        }
      }
    }

    return ends;
  }

  List<_RunwayPair> _groupIntoPairs() {
    final runways = widget.airport['runways'] as List<dynamic>? ?? [];
    final pairs = <_RunwayPair>[];

    for (final runway in runways) {
      final ends = runway['ends'] as List<dynamic>? ?? [];
      final runwayEndObjs = <_RunwayEnd>[];

      for (final end in ends) {
        final id = end['identifier'] as String?;
        final heading = (end['true_heading'] as num?)?.toDouble();
        final lat = (end['latitude'] as num?)?.toDouble();
        final lng = (end['longitude'] as num?)?.toDouble();
        if (id != null && heading != null && lat != null && lng != null) {
          runwayEndObjs.add(_RunwayEnd(
            identifier: id,
            heading: heading,
            latitude: lat,
            longitude: lng,
          ));
        }
      }

      if (runwayEndObjs.length == 2) {
        pairs.add(_RunwayPair(end1: runwayEndObjs[0], end2: runwayEndObjs[1]));
      } else if (runwayEndObjs.length == 1) {
        pairs.add(_RunwayPair(end1: runwayEndObjs[0]));
      }
    }

    return pairs;
  }

  CameraPosition _cameraForRunwayEnd(_RunwayEnd end) {
    final reciprocal = (end.heading + 180) % 360;
    final recipRad = reciprocal * pi / 180;
    const offsetMeters = 930.0; // ~0.5 NM
    final latOffset = (offsetMeters / 111320) * cos(recipRad);
    final lngOffset =
        (offsetMeters / (111320 * cos(end.latitude * pi / 180))) * sin(recipRad);

    return CameraPosition(
      target: LatLng(end.latitude + latOffset, end.longitude + lngOffset),
      bearing: end.heading,
      tilt: 60,
      zoom: 15.5,
    );
  }

  CameraPosition get _initialCamera {
    if (_runwayEnds.isNotEmpty) {
      // Use the first end of the longest runway
      final runways = widget.airport['runways'] as List<dynamic>? ?? [];
      _RunwayEnd? bestEnd;
      int bestLength = 0;

      for (final runway in runways) {
        final length = (runway['length'] as num?)?.toInt() ?? 0;
        final ends = runway['ends'] as List<dynamic>? ?? [];
        if (length > bestLength && ends.isNotEmpty) {
          final end = ends.first;
          final id = end['identifier'] as String?;
          final heading = (end['true_heading'] as num?)?.toDouble();
          final lat = (end['latitude'] as num?)?.toDouble();
          final lng = (end['longitude'] as num?)?.toDouble();
          if (id != null && heading != null && lat != null && lng != null) {
            bestLength = length;
            bestEnd = _RunwayEnd(
              identifier: id,
              heading: heading,
              latitude: lat,
              longitude: lng,
            );
          }
        }
      }

      if (bestEnd != null) return _cameraForRunwayEnd(bestEnd);
      return _cameraForRunwayEnd(_runwayEnds.first);
    }

    return CameraPosition(
      target: LatLng(_airportLat, _airportLng),
      tilt: 60,
      zoom: 15.5,
    );
  }

  void _animateToEnd(_RunwayEnd end) {
    setState(() => _selectedEndId = end.identifier);
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_cameraForRunwayEnd(end)),
    );
  }

  bool get _isSupported => Platform.isIOS || Platform.isAndroid;

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
          // Full-screen Google Map
          GoogleMap(
            initialCameraPosition: _initialCamera,
            mapType: MapType.satellite,
            buildingsEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
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

          // Info chips + runway buttons below top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 52,
            left: 12,
            right: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info chips (left side)
                if (_elevation != null)
                  _InfoChip(
                    label: '${_elevation!.round()}\' MSL',
                    icon: Icons.terrain,
                  ),
                const Spacer(),
                // Runway end buttons (right side)
                if (_runwayPairs.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _runwayPairs.map((pair) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _RunwayPairButton(
                          pair: pair,
                          selectedEndId: _selectedEndId,
                          onEndTap: _animateToEnd,
                        ),
                      );
                    }).toList(),
                  ),
              ],
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

class _RunwayPairButton extends StatelessWidget {
  final _RunwayPair pair;
  final String? selectedEndId;
  final void Function(_RunwayEnd) onEndTap;

  const _RunwayPairButton({
    required this.pair,
    required this.selectedEndId,
    required this.onEndTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _endButton(pair.end1),
            if (pair.end2 != null) ...[
              Container(width: 1, color: AppColors.divider),
              _endButton(pair.end2!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _endButton(_RunwayEnd end) {
    final isSelected = end.identifier == selectedEndId;
    return GestureDetector(
      onTap: () => onEndTap(end),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
        child: Text(
          end.identifier,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
