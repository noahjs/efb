import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// A single particle in the wind flow animation.
class _Particle {
  double lat;
  double lng;
  List<List<double>> trail; // [[lng, lat], ...]
  int age;
  int maxAge;
  double speed; // current wind speed (knots) — drives color & trail length

  _Particle({
    required this.lat,
    required this.lng,
    required this.maxAge,
  })  : trail = [
          [lng, lat]
        ],
        age = 0,
        speed = 0;
}

/// Wind field data point for interpolation.
class WindFieldPoint {
  final double lat;
  final double lng;
  final double direction; // degrees, wind FROM
  final double speed; // knots

  const WindFieldPoint({
    required this.lat,
    required this.lng,
    required this.direction,
    required this.speed,
  });
}

/// Animates ~150 color-coded particle streaks flowing along wind vectors.
///
/// Writes GeoJSON directly to the `wind-streamlines` Mapbox source.
/// Runs at ~12fps via a periodic timer.
///
/// Trail length and color scale with wind speed:
///   < 15 kt → green, short trails
///   15–30 kt → yellow, medium trails
///   30–50 kt → orange, long trails
///   ≥ 50 kt → red, longest trails
class WindParticleAnimator {
  static const int _particleCount = 200;
  static const int _fps = 12;
  static const int _maxAge = 100;
  static const int _minTrail = 6;
  static const int _maxTrail = 20;

  MapboxMap? _map;
  Timer? _timer;
  final _random = Random();
  final List<_Particle> _particles = [];
  int _tickCount = 0;

  // Wind field grid for interpolation
  List<WindFieldPoint> _windField = [];
  double _minLat = 0, _maxLat = 0, _minLng = 0, _maxLng = 0;

  bool get isRunning => _timer != null;

  void attach(MapboxMap map) => _map = map;

  /// Update the wind field data used for particle advection.
  void updateWindField(
    List<WindFieldPoint> field, {
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) {
    _windField = field;
    _minLat = minLat;
    _maxLat = maxLat;
    _minLng = minLng;
    _maxLng = maxLng;
  }

  /// Start the animation loop.
  void start() {
    if (_timer != null) return;
    if (_windField.isEmpty) {
      debugPrint('[EFB] WindParticleAnimator.start() called but wind field is empty');
      return;
    }
    debugPrint('[EFB] WindParticleAnimator starting: ${_windField.length} field points');
    _tickCount = 0;
    _initParticles();
    _timer = Timer.periodic(
      const Duration(milliseconds: 1000 ~/ _fps),
      (_) => _tick(),
    );
  }

  /// Stop the animation and clear particles.
  void stop() {
    debugPrint('[EFB] WindParticleAnimator stopping');
    _timer?.cancel();
    _timer = null;
    _particles.clear();
    _clearSource();
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(_spawnParticle());
    }
  }

  _Particle _spawnParticle() {
    final lat = _minLat + _random.nextDouble() * (_maxLat - _minLat);
    final lng = _minLng + _random.nextDouble() * (_maxLng - _minLng);
    return _Particle(
      lat: lat,
      lng: lng,
      maxAge: (_maxAge * 0.6 + _random.nextDouble() * _maxAge * 0.4).toInt(),
    );
  }

  /// Trail length scales with wind speed: calm → short, strong → long.
  static int _trailLengthForSpeed(double speed) {
    return (_minTrail + (speed / 60) * (_maxTrail - _minTrail))
        .round()
        .clamp(_minTrail, _maxTrail);
  }

  /// Color hex by wind speed bracket (matches wind barb palette).
  static String _colorForSpeed(double speed) {
    if (speed < 15) return '#4CAF50';
    if (speed < 30) return '#FFC107';
    if (speed < 50) return '#FF9800';
    return '#F44336';
  }

  void _tick() {
    if (_windField.isEmpty || _map == null) return;
    _tickCount++;

    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      p.age++;

      // Respawn if aged out or out of bounds
      if (p.age >= p.maxAge ||
          p.lat < _minLat ||
          p.lat > _maxLat ||
          p.lng < _minLng ||
          p.lng > _maxLng) {
        _particles[i] = _spawnParticle();
        continue;
      }

      // Get interpolated wind at current position
      final wind = _interpolateWind(p.lat, p.lng);
      if (wind == null || wind.speed < 1) {
        p.age = p.maxAge; // mark for respawn
        continue;
      }

      p.speed = wind.speed;

      // Advance along wind vector (wind direction is FROM, so add 180 for movement)
      final moveDir = (wind.direction + 180) % 360;
      final moveRad = moveDir * pi / 180;

      // Step size proportional to wind speed (faster winds = longer streaks)
      final stepDeg = 0.04 + (wind.speed / 60) * 0.12;
      final dLat = stepDeg * cos(moveRad);
      final dLng = stepDeg * sin(moveRad) / cos(p.lat * pi / 180);

      p.lat += dLat;
      p.lng += dLng;

      // Add to trail, keep length proportional to speed
      p.trail.add([p.lng, p.lat]);
      final maxLen = _trailLengthForSpeed(p.speed);
      while (p.trail.length > maxLen) {
        p.trail.removeAt(0);
      }
    }

    _pushToSource();
  }

  /// Bilinear-style interpolation using inverse-distance weighting of nearest points.
  WindFieldPoint? _interpolateWind(double lat, double lng) {
    if (_windField.isEmpty) return null;

    double bestDist = double.infinity;
    WindFieldPoint? best;
    double totalWeight = 0;
    double weightedSpeed = 0;
    double weightedSinDir = 0;
    double weightedCosDir = 0;

    for (final pt in _windField) {
      final dLat = pt.lat - lat;
      final dLng = pt.lng - lng;
      final dist = dLat * dLat + dLng * dLng;
      if (dist < 0.0001) {
        return pt;
      }
      final w = 1.0 / dist;
      totalWeight += w;
      weightedSpeed += pt.speed * w;
      weightedSinDir += sin(pt.direction * pi / 180) * w;
      weightedCosDir += cos(pt.direction * pi / 180) * w;

      if (dist < bestDist) {
        bestDist = dist;
        best = pt;
      }
    }

    if (best == null || totalWeight == 0) return null;

    final interpSpeed = weightedSpeed / totalWeight;
    final interpDir =
        (atan2(weightedSinDir / totalWeight, weightedCosDir / totalWeight) *
                180 /
                pi +
            360) %
        360;

    return WindFieldPoint(
      lat: lat,
      lng: lng,
      direction: interpDir,
      speed: interpSpeed,
    );
  }

  void _pushToSource() {
    final map = _map;
    if (map == null) return;

    final features = <Map<String, dynamic>>[];
    for (final p in _particles) {
      if (p.trail.length < 2) continue;
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': p.trail,
        },
        'properties': {
          'color': _colorForSpeed(p.speed),
        },
      });
    }

    final geojson = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    map.style
        .setStyleSourceProperty('wind-streamlines', 'data', geojson)
        .then((_) {
      if (_tickCount == 1) {
        debugPrint('[EFB] Particle source updated: ${features.length} trails');
      }
    }).catchError((e) {
      if (_tickCount <= 3) {
        debugPrint('[EFB] Failed to update particle source: $e');
      }
    });
  }

  void _clearSource() {
    final map = _map;
    if (map == null) return;
    try {
      map.style.setStyleSourceProperty(
        'wind-streamlines',
        'data',
        '{"type":"FeatureCollection","features":[]}',
      );
    } catch (_) {}
  }
}
