import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// A custom-painted runway diagram showing the airport's actual runway layout.
/// Color-coded by tower status: blue = towered, magenta = non-towered,
/// matching sectional chart conventions.
class RunwayDiagramIcon extends StatelessWidget {
  final List<Map<String, dynamic>> runways;
  final bool isTowered;
  final double size;

  const RunwayDiagramIcon({
    super.key,
    required this.runways,
    required this.isTowered,
    this.size = 60,
  });

  static const _toweredColor = Color.fromARGB(255, 50, 100, 235);
  static const _nonToweredColor = Color.fromARGB(255, 200, 50, 220);

  @override
  Widget build(BuildContext context) {
    final color = isTowered ? _toweredColor : _nonToweredColor;

    if (runways.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: const Icon(Icons.flight, color: AppColors.textMuted, size: 28),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _RunwayDiagramPainter(
          runways: runways,
          color: color,
        ),
      ),
    );
  }
}

class _RunwayDiagramPainter extends CustomPainter {
  final List<Map<String, dynamic>> runways;
  final Color color;

  _RunwayDiagramPainter({required this.runways, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.38;

    // Draw subtle background circle
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius + 4, bgPaint);

    // Draw faint border ring
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;
    canvas.drawCircle(center, maxRadius + 4, ringPaint);

    // Extract runway data: heading and length
    final rwyData = <({double heading, double length})>[];
    double maxLength = 0;

    for (final rwy in runways) {
      final heading = _extractHeading(rwy);
      if (heading == null) continue;

      final length = (rwy['length'] as num?)?.toDouble() ?? 3000;
      maxLength = max(maxLength, length);
      rwyData.add((heading: heading, length: length));
    }

    if (rwyData.isEmpty || maxLength == 0) return;

    // Group parallels (within 5° heading) for perpendicular offset
    final groups = <List<int>>[];
    final assigned = <int>{};

    for (int i = 0; i < rwyData.length; i++) {
      if (assigned.contains(i)) continue;
      final group = [i];
      assigned.add(i);

      for (int j = i + 1; j < rwyData.length; j++) {
        if (assigned.contains(j)) continue;
        if (_headingsParallel(rwyData[i].heading, rwyData[j].heading)) {
          group.add(j);
          assigned.add(j);
        }
      }
      groups.add(group);
    }

    // Draw each runway
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (final group in groups) {
      final perpOffset = group.length > 1 ? 4.0 : 0.0;

      for (int gi = 0; gi < group.length; gi++) {
        final idx = group[gi];
        final rwy = rwyData[idx];

        // Scale length relative to longest runway (min 20%)
        final scaledLength =
            maxRadius * max(0.2, rwy.length / maxLength);

        // Convert heading to canvas angle (heading 0° = north/up)
        final angleRad = (rwy.heading - 90) * pi / 180;

        // Calculate perpendicular offset for parallel runways
        final perpAngle = angleRad + pi / 2;
        final offsetAmount =
            (gi - (group.length - 1) / 2) * perpOffset;
        final perpDx = cos(perpAngle) * offsetAmount;
        final perpDy = sin(perpAngle) * offsetAmount;

        final rwyCenter = Offset(
          center.dx + perpDx,
          center.dy + perpDy,
        );

        final dx = cos(angleRad) * scaledLength;
        final dy = sin(angleRad) * scaledLength;

        canvas.drawLine(
          Offset(rwyCenter.dx - dx, rwyCenter.dy - dy),
          Offset(rwyCenter.dx + dx, rwyCenter.dy + dy),
          paint,
        );
      }
    }
  }

  /// Extract heading from runway data. Tries 'ends' array first,
  /// then falls back to deriving from the runway identifier.
  double? _extractHeading(Map<String, dynamic> rwy) {
    // Try to get heading from runway ends
    final ends = rwy['ends'] as List<dynamic>?;
    if (ends != null && ends.isNotEmpty) {
      final end = ends[0] as Map<String, dynamic>;
      final heading = end['heading'] as num?;
      if (heading != null) return heading.toDouble();
    }

    // Fall back to deriving from identifier (e.g. "17/35" or "17L/35R")
    final id = rwy['identifier'] as String?;
    if (id == null) return null;

    // Take the first runway number
    final match = RegExp(r'(\d{1,2})').firstMatch(id);
    if (match == null) return null;

    final rwyNum = int.tryParse(match.group(1)!);
    if (rwyNum == null) return null;

    return (rwyNum * 10).toDouble();
  }

  /// Check if two headings are within 5° of being parallel
  /// (accounting for reciprocal headings).
  bool _headingsParallel(double h1, double h2) {
    final diff = ((h1 - h2) % 180).abs();
    return diff <= 5 || (180 - diff) <= 5;
  }

  @override
  bool shouldRepaint(covariant _RunwayDiagramPainter oldDelegate) {
    return oldDelegate.runways != runways || oldDelegate.color != color;
  }
}
