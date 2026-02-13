import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'map_view.dart';

/// Action button definition for the outer ring.
class CalloutAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const CalloutAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/// Garmin-style radial callout with two circles:
///   Inner circle — waypoint info (identifier, name, bearing/distance, elevation)
///   Outer ring — action buttons evenly distributed around the perimeter
class WaypointCallout extends StatelessWidget {
  final MapFeatureTap feature;
  final double? ownshipLat;
  final double? ownshipLng;
  final List<CalloutAction> actions;

  const WaypointCallout({
    super.key,
    required this.feature,
    this.ownshipLat,
    this.ownshipLng,
    required this.actions,
  });

  // Layout
  static const _innerR = 52.0;
  static const _orbitR = 100.0; // center of action buttons
  static const _totalSize = 2 * (_orbitR + 48); // ~296

  @override
  Widget build(BuildContext context) {
    String? bearingStr;
    String? distanceStr;
    if (ownshipLat != null && ownshipLng != null) {
      final bearing =
          _bearingDeg(ownshipLat!, ownshipLng!, feature.lat, feature.lng);
      final distance =
          _haversineNm(ownshipLat!, ownshipLng!, feature.lat, feature.lng);
      bearingStr = '${bearing.round()}\u00B0';
      distanceStr = distance < 100
          ? '${distance.toStringAsFixed(1)} NM'
          : '${distance.round()} NM';
    }

    final name = _featureName();
    final subtitle = _featureSubtitle();
    const center = _totalSize / 2;

    // Calculate button positions evenly around the orbit
    final buttonPositions = <({double x, double y, CalloutAction action})>[];
    if (actions.isNotEmpty) {
      final step = 2 * pi / actions.length;
      final start = -pi / 2; // top
      for (int i = 0; i < actions.length; i++) {
        final angle = start + i * step;
        buttonPositions.add((
          x: center + _orbitR * cos(angle),
          y: center + _orbitR * sin(angle),
          action: actions[i],
        ));
      }
    }

    return SizedBox(
      width: _totalSize,
      height: _totalSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative ring (between inner circle and buttons)
          Positioned(
            left: center - 72,
            top: center - 72,
            child: CustomPaint(
              size: const Size(144, 144),
              painter: _DecoRingPainter(color: AppColors.accent),
            ),
          ),

          // Inner info circle
          Positioned(
            left: center - _innerR,
            top: center - _innerR,
            child: Container(
              width: _innerR * 2,
              height: _innerR * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface.withValues(alpha: 0.95),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Identifier
                  Text(
                    feature.identifier,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 1.0,
                    ),
                  ),
                  // Name
                  if (name != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Bearing / Distance
                  if (bearingStr != null || distanceStr != null)
                    Text(
                      [bearingStr, distanceStr]
                          .whereType<String>()
                          .join('  \u2022  '),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  // Subtitle (elevation, frequency, type)
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Outer action buttons
          for (final bp in buttonPositions)
            Positioned(
              left: bp.x - 40,
              top: bp.y - 17,
              child: _RadialButton(
                label: bp.action.label,
                icon: bp.action.icon,
                onTap: bp.action.onTap,
              ),
            ),
        ],
      ),
    );
  }

  String? _featureName() {
    switch (feature.type) {
      case MapFeatureType.airport:
        final name = feature.properties['name'] as String?;
        if (name == null || name.isEmpty) return null;
        // Truncate long airport names
        return name.length > 16 ? '${name.substring(0, 14)}..' : name;
      case MapFeatureType.navaid:
        final name = feature.properties['name'] as String?;
        if (name == null || name.isEmpty) return null;
        return name.length > 16 ? '${name.substring(0, 14)}..' : name;
      case MapFeatureType.fix:
      case MapFeatureType.pirep:
        return null;
    }
  }

  String? _featureSubtitle() {
    switch (feature.type) {
      case MapFeatureType.airport:
        final elev = feature.properties['elevation'];
        if (elev != null) {
          final elevNum =
              elev is num ? elev.round() : int.tryParse(elev.toString());
          if (elevNum != null) return '${_fmtNum(elevNum)} ft';
        }
        return null;
      case MapFeatureType.navaid:
        final type = feature.properties['navType'] as String? ?? '';
        final freq = feature.properties['frequency'] as String? ?? '';
        final parts = [type, freq].where((s) => s.isNotEmpty);
        return parts.isNotEmpty ? parts.join(' \u2022 ') : null;
      case MapFeatureType.fix:
        return 'INT';
      case MapFeatureType.pirep:
        return null;
    }
  }

  static String _fmtNum(int n) {
    if (n.abs() < 1000) return n.toString();
    final s = n.abs().toString();
    final buf = StringBuffer();
    if (n < 0) buf.write('-');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static double _haversineNm(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 3440.065;
    final dLat = _d2r(lat2 - lat1);
    final dLng = _d2r(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_d2r(lat1)) * cos(_d2r(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _bearingDeg(
      double lat1, double lng1, double lat2, double lng2) {
    final dLng = _d2r(lng2 - lng1);
    final y = sin(dLng) * cos(_d2r(lat2));
    final x = cos(_d2r(lat1)) * sin(_d2r(lat2)) -
        sin(_d2r(lat1)) * cos(_d2r(lat2)) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  static double _d2r(double deg) => deg * pi / 180;
}

// ── Radial action button ────────────────────────────────────────────────────

class _RadialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _RadialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.accent),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Decorative ring between inner circle and buttons ────────────────────────

class _DecoRingPainter extends CustomPainter {
  final Color color;

  _DecoRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;

    // Ring stroke
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Tick marks at 8 compass points
    final tickLen = 6.0;
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final outerX = center.dx + r * cos(angle);
      final outerY = center.dy + r * sin(angle);
      final innerX = center.dx + (r - tickLen) * cos(angle);
      final innerY = center.dy + (r - tickLen) * sin(angle);
      canvas.drawLine(Offset(outerX, outerY), Offset(innerX, innerY), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DecoRingPainter oldDelegate) =>
      color != oldDelegate.color;
}
