import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

/// Pure-Flutter winds aloft map using CustomPainter. Works on all platforms
/// (no Mapbox dependency). Draws wind arrows at grid points across the route
/// corridor with the route line overlaid.
class WindsMapWidget extends StatelessWidget {
  final List<BriefingWaypoint> waypoints;
  final int cruiseAltitude;
  final Map<String, dynamic>? windGridGeoJson;

  const WindsMapWidget({
    super.key,
    required this.waypoints,
    required this.cruiseAltitude,
    this.windGridGeoJson,
  });

  @override
  Widget build(BuildContext context) {
    if (waypoints.length < 2 && windGridGeoJson == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D23),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('No wind data',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: const Color(0xFF1A1D23),
        child: CustomPaint(
          painter: _WindsMapPainter(
            waypoints: waypoints,
            windGridGeoJson: windGridGeoJson,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WindsMapPainter extends CustomPainter {
  final List<BriefingWaypoint> waypoints;
  final Map<String, dynamic>? windGridGeoJson;

  _WindsMapPainter({
    required this.waypoints,
    this.windGridGeoJson,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Compute geo bounds from waypoints
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (final wp in waypoints) {
      if (wp.latitude < minLat) minLat = wp.latitude;
      if (wp.latitude > maxLat) maxLat = wp.latitude;
      if (wp.longitude < minLng) minLng = wp.longitude;
      if (wp.longitude > maxLng) maxLng = wp.longitude;
    }

    // Also include wind grid points in bounds calculation
    final features = (windGridGeoJson?['features'] as List<dynamic>?) ?? [];
    for (final f in features) {
      final coords = f['geometry']?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) continue;
      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    // Expand bounds with padding
    final latPad = (maxLat - minLat) * 0.15 + 0.3;
    final lngPad = (maxLng - minLng) * 0.15 + 0.3;
    minLat -= latPad;
    maxLat += latPad;
    minLng -= lngPad;
    maxLng += lngPad;

    // Ensure aspect ratio matches widget
    final geoWidth = maxLng - minLng;
    final geoHeight = maxLat - minLat;
    final widgetAspect = size.width / size.height;
    final geoAspect = geoWidth / geoHeight;

    if (geoAspect > widgetAspect) {
      // Geo is wider — expand height
      final needed = geoWidth / widgetAspect;
      final diff = (needed - geoHeight) / 2;
      minLat -= diff;
      maxLat += diff;
    } else {
      // Geo is taller — expand width
      final needed = geoHeight * widgetAspect;
      final diff = (needed - geoWidth) / 2;
      minLng -= diff;
      maxLng += diff;
    }

    final finalGeoW = maxLng - minLng;
    final finalGeoH = maxLat - minLat;

    // Coordinate transform: geo → pixel
    Offset toPixel(double lat, double lng) {
      final x = (lng - minLng) / finalGeoW * size.width;
      final y = (1.0 - (lat - minLat) / finalGeoH) * size.height;
      return Offset(x, y);
    }

    // Draw graticule lines
    _drawGraticule(canvas, size, minLat, maxLat, minLng, maxLng, toPixel);

    // Draw wind arrows
    for (final f in features) {
      final coords = f['geometry']?['coordinates'] as List<dynamic>?;
      final props = f['properties'] as Map<String, dynamic>?;
      if (coords == null || coords.length < 2 || props == null) continue;

      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final dir = (props['direction'] as num?)?.toDouble() ?? 0;
      final speed = (props['speed'] as num?)?.toDouble() ?? 0;
      final colorHex = props['color'] as String? ?? '#4CAF50';
      final speedLabel = props['speedLabel'] as String? ?? '';
      final tempLabel = props['tempLabel'] as String? ?? '';

      final pos = toPixel(lat, lng);
      final color = _parseHex(colorHex);

      _drawWindArrow(canvas, pos, dir, speed, color);
      _drawLabel(canvas, pos, speedLabel, color, offsetY: 14);
      if (tempLabel.isNotEmpty) {
        _drawLabel(canvas, pos, tempLabel, const Color(0xFFAABBCC),
            offsetY: 25, fontSize: 9);
      }
    }

    // Draw route line
    if (waypoints.length >= 2) {
      final routePaint = Paint()
        ..color = AppColors.primary.withAlpha(180)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final first = toPixel(waypoints[0].latitude, waypoints[0].longitude);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < waypoints.length; i++) {
        final p = toPixel(waypoints[i].latitude, waypoints[i].longitude);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, routePaint);

      // Waypoint dots + labels
      for (final wp in waypoints) {
        final p = toPixel(wp.latitude, wp.longitude);

        // Dot
        canvas.drawCircle(
            p, 4, Paint()..color = AppColors.primary);
        canvas.drawCircle(
            p,
            4,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);

        // Label
        final tp = TextPainter(
          text: TextSpan(
            text: wp.identifier,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height - 8));
      }
    }
  }

  void _drawGraticule(
    Canvas canvas,
    Size size,
    double minLat,
    double maxLat,
    double minLng,
    double maxLng,
    Offset Function(double lat, double lng) toPixel,
  ) {
    final paint = Paint()
      ..color = const Color(0xFF2A2D33)
      ..strokeWidth = 0.5;

    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final step = _niceStep(math.max(latSpan, lngSpan));

    // Lat lines
    final startLat = (minLat / step).ceil() * step;
    for (double lat = startLat; lat <= maxLat; lat += step) {
      final left = toPixel(lat, minLng);
      final right = toPixel(lat, maxLng);
      canvas.drawLine(left, right, paint);

      final tp = TextPainter(
        text: TextSpan(
          text: '${lat.toStringAsFixed(0)}°',
          style: const TextStyle(color: Color(0xFF555555), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, left.dy - tp.height / 2));
    }

    // Lng lines
    final startLng = (minLng / step).ceil() * step;
    for (double lng = startLng; lng <= maxLng; lng += step) {
      final top = toPixel(maxLat, lng);
      final bottom = toPixel(minLat, lng);
      canvas.drawLine(top, bottom, paint);

      final tp = TextPainter(
        text: TextSpan(
          text: '${lng.toStringAsFixed(0)}°',
          style: const TextStyle(color: Color(0xFF555555), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(bottom.dx - tp.width / 2, size.height - tp.height - 2));
    }
  }

  double _niceStep(double span) {
    if (span <= 3) return 0.5;
    if (span <= 8) return 1.0;
    if (span <= 15) return 2.0;
    if (span <= 30) return 5.0;
    return 10.0;
  }

  void _drawWindArrow(
      Canvas canvas, Offset center, double direction, double speed, Color color) {
    if (speed < 1) return;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Wind direction is "FROM", arrow points in the direction wind is blowing TO
    canvas.rotate((direction * math.pi / 180));

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Triangle arrow pointing up (north = 0°)
    final arrowLength = 10.0;
    final arrowHalfWidth = 4.0;
    final path = Path()
      ..moveTo(0, -arrowLength)
      ..lineTo(-arrowHalfWidth, arrowLength * 0.4)
      ..lineTo(0, arrowLength * 0.15)
      ..lineTo(arrowHalfWidth, arrowLength * 0.4)
      ..close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawLabel(Canvas canvas, Offset center, String text, Color color,
      {double offsetY = 14, double fontSize = 10}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Draw halo
    final haloPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFF1A1D23),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pos = Offset(center.dx - tp.width / 2, center.dy + offsetY);
    haloPainter.paint(canvas, pos);
    tp.paint(canvas, pos);
  }

  Color _parseHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFF4CAF50);
  }

  @override
  bool shouldRepaint(covariant _WindsMapPainter oldDelegate) {
    return oldDelegate.windGridGeoJson != windGridGeoJson ||
        oldDelegate.waypoints != waypoints;
  }
}
