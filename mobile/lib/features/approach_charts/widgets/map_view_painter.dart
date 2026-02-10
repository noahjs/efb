import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/approach_chart.dart';

class MapViewCard extends StatelessWidget {
  final ApproachChartData chart;

  const MapViewCard({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    final hasCoords =
        chart.legs.any((l) => l.fixLatitude != null && l.fixLongitude != null);
    if (!hasCoords) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'MAP VIEW',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  'NOT TO SCALE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 340,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.divider, width: 0.5),
                ),
                child: CustomPaint(
                  painter: _MapViewPainter(chart: chart),
                  size: const Size(double.infinity, 340),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Geographic extent
// ---------------------------------------------------------------------------

class _GeoExtent {
  final double minLat, maxLat, minLon, maxLon;
  const _GeoExtent(this.minLat, this.maxLat, this.minLon, this.maxLon);
}

_GeoExtent _computeExtent(ApproachChartData chart) {
  final lats = <double>[];
  final lons = <double>[];

  for (final l in chart.legs) {
    if (l.fixLatitude != null && l.fixLongitude != null) {
      lats.add(l.fixLatitude!);
      lons.add(l.fixLongitude!);
    }
  }
  if (chart.runway?.thresholdLatitude != null) {
    lats.add(chart.runway!.thresholdLatitude!);
    lons.add(chart.runway!.thresholdLongitude!);
  }
  if (chart.ils?.localizerLatitude != null) {
    lats.add(chart.ils!.localizerLatitude!);
    lons.add(chart.ils!.localizerLongitude!);
  }
  if (chart.ils?.gsLatitude != null) {
    lats.add(chart.ils!.gsLatitude!);
    lons.add(chart.ils!.gsLongitude!);
  }

  if (lats.isEmpty) {
    return const _GeoExtent(39.5, 40.2, -105.2, -104.2);
  }

  // Extra-wide padding so labels have room on both sides of the course line
  const latPad = 0.15;
  const lonPad = 0.35;
  final latR = lats.reduce(math.max) - lats.reduce(math.min);
  final lonR = lons.reduce(math.max) - lons.reduce(math.min);
  return _GeoExtent(
    lats.reduce(math.min) - math.max(latR * latPad, 0.04),
    lats.reduce(math.max) + math.max(latR * latPad, 0.04),
    lons.reduce(math.min) - math.max(lonR * lonPad, 0.08),
    lons.reduce(math.max) + math.max(lonR * lonPad, 0.08),
  );
}

// ---------------------------------------------------------------------------
// Map View Painter
// ---------------------------------------------------------------------------

class _MapViewPainter extends CustomPainter {
  final ApproachChartData chart;

  _MapViewPainter({required this.chart});

  static final _coursePaint = Paint()
    ..color = AppColors.textPrimary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final _missedCoursePaint = Paint()
    ..color = AppColors.textMuted
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _gridPaint = Paint()
    ..color = AppColors.textMuted.withValues(alpha: 0.12)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;
  static final _tickPaint = Paint()
    ..color = AppColors.textMuted.withValues(alpha: 0.4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  static final _rwyPaint = Paint()
    ..color = AppColors.textPrimary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  static final _locPaint = Paint()
    ..color = AppColors.textPrimary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  static final _leaderPaint = Paint()
    ..color = AppColors.textMuted.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const pad = 16.0;
    final px = pad;
    final py = pad;
    final pw = w - pad * 2;
    final ph = h - pad * 2;

    final ext = _computeExtent(chart);
    final mapIdx = chart.legs.indexWhere((l) => l.isMap);

    // Projection
    final cosLat =
        math.cos(((ext.minLat + ext.maxLat) / 2) * math.pi / 180);
    Offset geoToXY(double lat, double lon) {
      final nLon = (lon - ext.minLon) / (ext.maxLon - ext.minLon);
      final nLat = (lat - ext.minLat) / (ext.maxLat - ext.minLat);
      final geoA =
          ((ext.maxLon - ext.minLon) * cosLat) / (ext.maxLat - ext.minLat);
      final viewA = pw / ph;
      double sx, sy, ox = 0, oy = 0;
      if (geoA > viewA) {
        sx = pw;
        sy = pw / geoA;
        oy = (ph - sy) / 2;
      } else {
        sy = ph;
        sx = ph * geoA;
        ox = (pw - sx) / 2;
      }
      return Offset(px + ox + nLon * sx, py + ph - (oy + nLat * sy));
    }

    // ── Lat/lon grid ──
    final step = 10 / 60;
    for (var lat = (ext.minLat / step).ceil() * step;
        lat <= ext.maxLat;
        lat += step) {
      final p1 = geoToXY(lat, ext.minLon);
      final p2 = geoToXY(lat, ext.maxLon);
      if (p1.dy > py + 5 && p1.dy < py + ph - 5) {
        canvas.drawLine(p1, p2, _gridPaint);
        canvas.drawLine(Offset(0, p1.dy), Offset(5, p1.dy), _tickPaint);
      }
    }
    for (var lon = (ext.minLon / step).ceil() * step;
        lon <= ext.maxLon;
        lon += step) {
      final p1 = geoToXY(ext.minLat, lon);
      final p2 = geoToXY(ext.maxLat, lon);
      if (p1.dx > px + 5 && p1.dx < px + pw - 5) {
        canvas.drawLine(p1, p2, _gridPaint);
        canvas.drawLine(Offset(p1.dx, h), Offset(p1.dx, h - 5), _tickPaint);
      }
    }

    // ── Course lines ──
    final vis = chart.legs
        .where((l) => l.fixLatitude != null && l.fixLongitude != null)
        .toList();

    for (int i = 0; i < vis.length - 1; i++) {
      final l = vis[i];
      final n = vis[i + 1];
      final p1 = geoToXY(l.fixLatitude!, l.fixLongitude!);
      final p2 = geoToXY(n.fixLatitude!, n.fixLongitude!);
      final nIdx = chart.legs.indexOf(n);
      final isMissed = mapIdx >= 0 && nIdx > mapIdx;

      if (isMissed) {
        _drawDashedLine(canvas, p1, p2,
            paint: _missedCoursePaint, dashLen: 6, gapLen: 4);
      } else {
        canvas.drawLine(p1, p2, _coursePaint);
      }
    }

    // ── Compute perpendicular direction for label placement ──
    // Use the average course direction to determine left/right sides
    final appFixes = vis.where((l) {
      final idx = chart.legs.indexOf(l);
      return mapIdx < 0 || idx <= mapIdx;
    }).toList();

    double perpDx = 1, perpDy = 0; // default: labels go horizontal
    if (appFixes.length >= 2) {
      final first = geoToXY(appFixes.first.fixLatitude!, appFixes.first.fixLongitude!);
      final last = geoToXY(appFixes.last.fixLatitude!, appFixes.last.fixLongitude!);
      final cdx = last.dx - first.dx;
      final cdy = last.dy - first.dy;
      final clen = math.sqrt(cdx * cdx + cdy * cdy);
      if (clen > 1) {
        // Perpendicular to course line
        perpDx = -cdy / clen;
        perpDy = cdx / clen;
      }
    }

    // ── Course bearing label (one, on the longest approach segment) ──
    double bestSegLen = 0;
    int bestSegIdx = -1;
    for (int i = 0; i < vis.length - 1; i++) {
      final nIdx = chart.legs.indexOf(vis[i + 1]);
      if (mapIdx >= 0 && nIdx > mapIdx) continue;
      if (vis[i + 1].magneticCourse == null) continue;
      final p1 = geoToXY(vis[i].fixLatitude!, vis[i].fixLongitude!);
      final p2 = geoToXY(vis[i + 1].fixLatitude!, vis[i + 1].fixLongitude!);
      final len = (p2 - p1).distance;
      if (len > bestSegLen) {
        bestSegLen = len;
        bestSegIdx = i;
      }
    }
    if (bestSegIdx >= 0 && bestSegLen > 40) {
      final p1 = geoToXY(vis[bestSegIdx].fixLatitude!, vis[bestSegIdx].fixLongitude!);
      final p2 = geoToXY(vis[bestSegIdx + 1].fixLatitude!, vis[bestSegIdx + 1].fixLongitude!);
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawBoxedText(
          canvas, '${vis[bestSegIdx + 1].magneticCourse!.round()}°', mid);
    }

    // ── Runway ──
    if (chart.runway?.thresholdLatitude != null) {
      final rp = geoToXY(
          chart.runway!.thresholdLatitude!, chart.runway!.thresholdLongitude!);
      final bear = (chart.runway!.runwayBearing ?? 0) * math.pi / 180;
      const rLen = 28.0;
      const rW = 5.0;
      final dx = math.sin(bear);
      final dy = -math.cos(bear);
      final nx = dy;
      final ny = dx;

      final corners = [
        Offset(rp.dx - nx * rW / 2, rp.dy - ny * rW / 2),
        Offset(rp.dx + nx * rW / 2, rp.dy + ny * rW / 2),
        Offset(rp.dx + nx * rW / 2 + dx * rLen, rp.dy + ny * rW / 2 + dy * rLen),
        Offset(rp.dx - nx * rW / 2 + dx * rLen, rp.dy - ny * rW / 2 + dy * rLen),
      ];

      final rwyFillPath = Path()
        ..moveTo(corners[0].dx, corners[0].dy)
        ..lineTo(corners[1].dx, corners[1].dy)
        ..lineTo(corners[2].dx, corners[2].dy)
        ..lineTo(corners[3].dx, corners[3].dy)
        ..close();
      canvas.drawPath(
        rwyFillPath,
        Paint()..color = AppColors.textPrimary.withValues(alpha: 0.3),
      );
      for (int i = 0; i < 4; i++) {
        canvas.drawLine(corners[i], corners[(i + 1) % 4], _rwyPaint);
      }

      // Runway label — strip "RW" prefix, place offset from runway
      var rwyLabel = chart.runway!.runwayIdentifier;
      if (rwyLabel.startsWith('RW')) rwyLabel = rwyLabel.substring(2);
      if (rwyLabel.isNotEmpty) {
        final labelPos = Offset(
          rp.dx + dx * rLen / 2 + nx * 14,
          rp.dy + dy * rLen / 2 + ny * 14,
        );
        _drawText(
          canvas,
          rwyLabel,
          labelPos,
          const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
          align: TextAlign.center,
        );
      }
    }

    // ── Localizer feather ──
    if (chart.ils?.localizerLatitude != null) {
      final lp = geoToXY(
          chart.ils!.localizerLatitude!, chart.ils!.localizerLongitude!);
      final bear = (chart.ils!.localizerBearing ?? 0) * math.pi / 180;
      const fLen = 26.0;
      final dx = math.sin(bear);
      final dy = -math.cos(bear);
      final nx = dy;
      final ny = dx;

      canvas.drawLine(
        Offset(lp.dx - nx * fLen, lp.dy - ny * fLen),
        Offset(lp.dx + nx * fLen, lp.dy + ny * fLen),
        _locPaint,
      );

      final locTickPaint = Paint()
        ..color = AppColors.textPrimary
        ..strokeWidth = 1.0;
      for (final t in [-1.0, -0.7, -0.4, 0.4, 0.7, 1.0]) {
        final bx = lp.dx + nx * fLen * t;
        final by = lp.dy + ny * fLen * t;
        canvas.drawLine(
          Offset(bx, by),
          Offset(bx + dx * 6, by + dy * 6),
          locTickPaint,
        );
      }
    }

    // ── Fix symbols and labels ──
    // Collect named fixes in order, assign alternating sides
    int sideCounter = 0;
    for (final leg in chart.legs) {
      if (leg.fixLatitude == null || leg.fixLongitude == null) continue;
      if (leg.fixIdentifier == null || leg.fixIdentifier!.startsWith('RW')) {
        continue;
      }

      final p = geoToXY(leg.fixLatitude!, leg.fixLongitude!);
      final legIdx = chart.legs.indexOf(leg);
      final isMissedFix = mapIdx >= 0 && legIdx > mapIdx;
      final color = isMissedFix ? AppColors.textMuted : AppColors.textPrimary;

      // Triangle symbol
      _drawTriangle(canvas, p, color);

      // Determine which side to place the label
      final side = (sideCounter % 2 == 0) ? 1.0 : -1.0;
      sideCounter++;

      // Leader line offset (perpendicular to course)
      const leaderLen = 30.0;
      final leaderEnd = Offset(
        p.dx + perpDx * leaderLen * side,
        p.dy + perpDy * leaderLen * side,
      );

      // Draw leader line
      canvas.drawLine(p, leaderEnd, _leaderPaint);

      // Build compact label: "FIXNAME (ROLE)"
      final role = leg.roleLabel;
      final nameText = role != null
          ? '${leg.fixIdentifier!}  ($role)'
          : leg.fixIdentifier!;

      // Label alignment depends on side
      final labelAlign = side > 0 ? TextAlign.left : TextAlign.right;
      final labelX = side > 0 ? leaderEnd.dx + 4 : leaderEnd.dx - 4;

      // Fix name + role on one line
      _drawText(
        canvas,
        nameText,
        Offset(labelX, leaderEnd.dy - 7),
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        align: labelAlign,
      );

      // Altitude on second line (compact)
      if (leg.altitude1 != null) {
        _drawText(
          canvas,
          '${leg.altitude1}\'',
          Offset(labelX, leaderEnd.dy + 5),
          TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isMissedFix
                ? AppColors.textMuted
                : AppColors.textSecondary,
          ),
          align: labelAlign,
        );
      }
    }

    // ── Holding pattern ──
    final hLeg = chart.legs.cast<ApproachLeg?>().firstWhere(
          (l) =>
              (l!.pathTermination == 'HM' || l.pathTermination == 'HF') &&
              l.fixLatitude != null &&
              l.magneticCourse != null,
          orElse: () => null,
        );
    if (hLeg != null) {
      final hp = geoToXY(hLeg.fixLatitude!, hLeg.fixLongitude!);
      final hc = (hLeg.magneticCourse ?? 0) * math.pi / 180;
      const tLen = 36.0;
      const tW = 16.0;
      final dx = math.sin(hc);
      final dy = math.cos(hc);
      final right = hLeg.turnDirection == 'R' ? 1.0 : -1.0;
      final nx = dy * right;
      final ny = -dx * right;
      final ex = hp.dx + dx * tLen;
      final ey = hp.dy - dy * tLen;

      final holdPaint = Paint()
        ..color = AppColors.textMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      _drawDashedLine(canvas, hp, Offset(ex, ey),
          paint: holdPaint, dashLen: 4, gapLen: 3);
      _drawDashedLine(
        canvas,
        Offset(hp.dx + nx * tW, hp.dy + ny * tW),
        Offset(ex + nx * tW, ey + ny * tW),
        paint: holdPaint,
        dashLen: 4,
        gapLen: 3,
      );

      final cr = tW / 2;
      final ba = math.atan2(ny, nx);
      final cx1 = hp.dx + nx * cr;
      final cy1 = hp.dy + ny * cr;
      final cx2 = ex + nx * cr;
      final cy2 = ey + ny * cr;

      for (var a = 0.0; a < math.pi; a += math.pi / 12) {
        canvas.drawLine(
          Offset(cx1 + cr * math.cos(ba + a * right),
              cy1 + cr * math.sin(ba + a * right)),
          Offset(cx1 + cr * math.cos(ba + (a + math.pi / 12) * right),
              cy1 + cr * math.sin(ba + (a + math.pi / 12) * right)),
          holdPaint,
        );
        canvas.drawLine(
          Offset(cx2 + cr * math.cos(ba + math.pi + a * right),
              cy2 + cr * math.sin(ba + math.pi + a * right)),
          Offset(cx2 + cr * math.cos(ba + math.pi + (a + math.pi / 12) * right),
              cy2 + cr * math.sin(ba + math.pi + (a + math.pi / 12) * right)),
          holdPaint,
        );
      }
    }

    // ── ILS identification box (top-right) ──
    if (chart.ils != null) {
      const boxW = 120.0;
      const boxH = 24.0;
      final bx = w - boxW - 8;
      const by = 4.0;

      final boxRect = Rect.fromLTWH(bx, by, boxW, boxH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(3)),
        Paint()..color = AppColors.surface,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(3)),
        Paint()
          ..color = AppColors.textPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      final bearing = chart.ils!.localizerBearing?.round() ?? 0;
      final freq = chart.ils!.frequencyDisplay;
      final ilsId = chart.ils!.localizerIdentifier;

      _drawText(
        canvas,
        '$bearing°  $freq  $ilsId',
        Offset(bx + boxW / 2, by + 5),
        const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        align: TextAlign.center,
      );

      final typeLabel = chart.approach.routeType == 'I' ? 'ILS DME' : 'LOC';
      _drawText(
        canvas,
        typeLabel,
        Offset(bx + boxW / 2, by + boxH + 2),
        const TextStyle(fontSize: 8, color: AppColors.textMuted),
        align: TextAlign.center,
      );

      // Course dashes inside box
      final lineY = by + boxH / 2;
      final dashPaint = Paint()
        ..color = AppColors.textPrimary
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(bx + 4, lineY), Offset(bx + 14, lineY), dashPaint);
      canvas.drawLine(
          Offset(bx + boxW - 14, lineY), Offset(bx + boxW - 4, lineY), dashPaint);
    }
  }

  // ── Drawing helpers ──

  void _drawTriangle(Canvas canvas, Offset center, Color color) {
    const sz = 6.0;
    final path = Path()
      ..moveTo(center.dx, center.dy - sz)
      ..lineTo(center.dx - sz * 0.866, center.dy + sz * 0.5)
      ..lineTo(center.dx + sz * 0.866, center.dy + sz * 0.5)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawBoxedText(Canvas canvas, String text, Offset center) {
    const style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final boxW = tp.width + 10;
    final boxH = tp.height + 6;
    final rect = Rect.fromCenter(center: center, width: boxW, height: boxH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = AppColors.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()
        ..color = AppColors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    tp.paint(
        canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end, {
    required Paint paint,
    double dashLen = 5,
    double gapLen = 4,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1) return;
    final ux = dx / dist;
    final uy = dy / dist;

    var d = 0.0;
    while (d < dist) {
      final segEnd = math.min(d + dashLen, dist);
      canvas.drawLine(
        Offset(start.dx + ux * d, start.dy + uy * d),
        Offset(start.dx + ux * segEnd, start.dy + uy * segEnd),
        paint,
      );
      d += dashLen + gapLen;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();

    double dx;
    switch (align) {
      case TextAlign.center:
        dx = position.dx - tp.width / 2;
      case TextAlign.right:
        dx = position.dx - tp.width;
      default:
        dx = position.dx;
    }
    tp.paint(canvas, Offset(dx, position.dy));
  }

  @override
  bool shouldRepaint(covariant _MapViewPainter oldDelegate) => true;
}
