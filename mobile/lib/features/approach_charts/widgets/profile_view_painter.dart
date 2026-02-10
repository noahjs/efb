import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/approach_chart.dart';

class ProfileViewCard extends StatelessWidget {
  final ApproachChartData chart;

  const ProfileViewCard({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PROFILE VIEW',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 320,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.divider,
                    width: 0.5,
                  ),
                ),
                child: CustomPaint(
                  painter: _ProfilePainter(chart: chart),
                  size: const Size(double.infinity, 320),
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
// Processed fix data
// ---------------------------------------------------------------------------

class _Fix {
  final String name;
  final double distFromThreshold; // NM
  final int altitude;
  final ApproachLeg leg;
  final bool isFaf;

  _Fix({
    required this.name,
    required this.distFromThreshold,
    required this.altitude,
    required this.leg,
    this.isFaf = false,
  });
}

// ---------------------------------------------------------------------------
// Profile Painter — Jeppesen-inspired
// ---------------------------------------------------------------------------

class _ProfilePainter extends CustomPainter {
  final ApproachChartData chart;

  _ProfilePainter({required this.chart});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Layout ──
    // Top: small info area (GS angle, TCH)
    // Middle: profile graphic (step-downs, GS line)
    // Ground line
    // Bottom strip: fix names row → distance boxes row
    const topPad = 8.0;
    const bottomStrip = 54.0; // fix names + distance boxes
    final groundY = h - bottomStrip;
    final profileTop = topPad + 4;
    final profileH = groundY - profileTop;

    // Horizontal: approach fills 75%, missed 25%
    const leftMargin = 0.04;
    const threshFrac = 0.12;
    const approachRight = 0.72;
    const missedLeft = 0.76;

    // ── Build fix list ──
    final mapIdx = chart.legs.indexWhere((l) => l.isMap);
    final appLegs = (mapIdx >= 0
            ? chart.legs.sublist(0, mapIdx)
            : chart.legs)
        .where((l) =>
            l.fixIdentifier != null &&
            l.fixIdentifier!.isNotEmpty &&
            !l.fixIdentifier!.startsWith('RW'))
        .toList();

    if (appLegs.isEmpty) return;

    final mapLeg = mapIdx >= 0 ? chart.legs[mapIdx] : null;
    final missLegs = mapIdx >= 0
        ? chart.legs
            .sublist(mapIdx + 1)
            .where((l) => l.fixIdentifier != null)
            .toList()
        : <ApproachLeg>[];

    final tdze = chart.runway?.thresholdElevation ?? 0;
    final tch = chart.ils?.thresholdCrossingHeight ?? 50;
    final fafLeg = chart.findFaf();
    final fafName = fafLeg?.fixIdentifier ?? '';

    // Cumulative distances from threshold
    final fixes = <_Fix>[];
    double cum = mapLeg != null
        ? (ApproachChartData.parseDist(mapLeg.routeDistanceOrTime) ?? 0)
        : 0;
    for (int i = appLegs.length - 1; i >= 0; i--) {
      fixes.insert(
        0,
        _Fix(
          name: appLegs[i].fixIdentifier!,
          distFromThreshold: cum,
          altitude: appLegs[i].altitude1 ?? tdze,
          leg: appLegs[i],
          isFaf: appLegs[i].fixIdentifier == fafName,
        ),
      );
      cum += ApproachChartData.parseDist(appLegs[i].routeDistanceOrTime) ?? 0;
    }
    final totalDist = math.max(cum, 1.0);

    // Altitude range
    final maxAlt = math.max(
      chart.legs.fold<int>(0, (m, l) => math.max(m, l.altitude1 ?? 0)),
      tdze + 1000,
    );
    final altRange = (maxAlt - tdze + 400).toDouble();

    // ── Coordinate helpers ──
    double dist2x(double d) =>
        threshFrac * w + (d / totalDist) * (approachRight - threshFrac) * w;
    double alt2y(double alt) =>
        groundY - ((alt - tdze) / altRange) * profileH;
    final threshX = dist2x(0);

    // ── Ground line ──
    final groundPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.7)
      ..strokeWidth = 1.0;
    canvas.drawLine(
        Offset(leftMargin * w, groundY), Offset(w, groundY), groundPaint);

    // Subtle ground fill
    canvas.drawRect(
      Rect.fromLTRB(leftMargin * w, groundY, w, groundY + 2),
      Paint()..color = AppColors.textMuted.withValues(alpha: 0.15),
    );

    // ── TDZE label left of threshold ──
    _drawText(
      canvas,
      '$tdze\'',
      Offset(threshX - 6, groundY - 14),
      const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
      align: TextAlign.right,
    );
    _drawText(
      canvas,
      'TDZE',
      Offset(threshX - 6, groundY - 26),
      const TextStyle(
        fontSize: 7,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.3,
      ),
      align: TextAlign.right,
    );

    // ── Threshold marker ──
    final threshPaint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(threshX, groundY),
      Offset(threshX, groundY - 8),
      threshPaint,
    );
    // Threshold bars
    canvas.drawLine(
      Offset(threshX - 4, groundY + 1),
      Offset(threshX + 4, groundY + 1),
      threshPaint,
    );

    // ── Step-down depiction ──
    final stepPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.8)
      ..strokeWidth = 1.2;

    for (int i = 0; i < fixes.length - 1; i++) {
      final f1 = fixes[i];
      final f2 = fixes[i + 1];
      final x1 = dist2x(f1.distFromThreshold);
      final x2 = dist2x(f2.distFromThreshold);
      final y1 = alt2y(f1.altitude.toDouble());
      final y2 = alt2y(f2.altitude.toDouble());

      // Horizontal line at lower altitude between fixes
      final stepAlt = math.min(f1.altitude, f2.altitude).toDouble();
      final sy = alt2y(stepAlt);
      canvas.drawLine(Offset(x1, sy), Offset(x2, sy), stepPaint);

      // Vertical drop at the transition point
      if (f1.altitude != f2.altitude) {
        canvas.drawLine(Offset(x2, y1), Offset(x2, y2), stepPaint);
      }
    }

    // Last fix to threshold
    if (fixes.isNotEmpty) {
      final lastFix = fixes.last;
      final lastX = dist2x(lastFix.distFromThreshold);
      final lastY = alt2y(lastFix.altitude.toDouble());
      canvas.drawLine(Offset(lastX, lastY), Offset(threshX, lastY), stepPaint);
    }

    // ── GS line (ILS) ──
    final fafFix = fixes.cast<_Fix?>().firstWhere(
          (f) => f!.isFaf,
          orElse: () => fixes.isNotEmpty ? fixes.last : null,
        );
    final isIls = chart.approach.routeType == 'I';

    if (isIls && fafFix != null) {
      final gsx1 = dist2x(fafFix.distFromThreshold);
      final gsy1 = alt2y(fafFix.altitude.toDouble());
      final gsy2 = alt2y((tdze + tch).toDouble());

      // GS line — prominent
      final gsPaint = Paint()
        ..color = AppColors.accent
        ..strokeWidth = 2.5;
      canvas.drawLine(Offset(gsx1, gsy1), Offset(threshX, gsy2), gsPaint);

      // GS intercept arrow (downward at FAF)
      final arrowPaint = Paint()
        ..color = AppColors.accent
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(gsx1 + 8, gsy1 - 10),
        Offset(gsx1 + 8, gsy1 + 4),
        arrowPaint,
      );
      final arrowHead = Path()
        ..moveTo(gsx1 + 5, gsy1 + 1)
        ..lineTo(gsx1 + 8, gsy1 + 4)
        ..lineTo(gsx1 + 11, gsy1 + 1);
      canvas.drawPath(arrowHead, arrowPaint);

      // Course label on GS line
      final courseLeg = chart.legs.firstWhere(
        (l) => l.magneticCourse != null && !l.isMap && !l.isMissedApproach,
        orElse: () => chart.legs.first,
      );
      if (courseLeg.magneticCourse != null) {
        final crsText = '${courseLeg.magneticCourse!.round()}°';
        // Position 40% along the GS line
        final t = 0.4;
        final crsX = gsx1 + (threshX - gsx1) * t;
        final crsY = gsy1 + (gsy2 - gsy1) * t;
        _drawBoxedLabel(canvas, crsText, Offset(crsX, crsY - 14));
      }
    }

    // ── GS/TCH info block (top-right of approach zone) ──
    if (isIls && chart.ils?.gsAngle != null) {
      final infoX = approachRight * w - 4;
      _drawText(
        canvas,
        'GS ${chart.ils!.gsAngle!.toStringAsFixed(2)}°',
        Offset(infoX, profileTop),
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        align: TextAlign.right,
      );
      _drawText(
        canvas,
        'TCH $tch\'',
        Offset(infoX, profileTop + 16),
        const TextStyle(
          fontSize: 9,
          color: AppColors.textSecondary,
        ),
        align: TextAlign.right,
      );
    }

    // ── Fix altitude labels (above step lines) ──
    for (int i = 0; i < fixes.length; i++) {
      final f = fixes[i];
      final fx = dist2x(f.distFromThreshold);
      final fy = alt2y(f.altitude.toDouble());

      // Vertical reference tick (subtle, from step to ground)
      canvas.drawLine(
        Offset(fx, groundY),
        Offset(fx, fy),
        Paint()
          ..color = AppColors.textMuted.withValues(alpha: 0.25)
          ..strokeWidth = 0.5,
      );

      if (f.isFaf) {
        // FAF: prominent altitude label + maltese cross
        _drawText(
          canvas,
          '${f.altitude}\'',
          Offset(fx + 10, fy - 14),
          const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        );
        _drawMalteseCross(canvas, Offset(fx, groundY - 10));
      } else {
        // Other fixes: altitude label above the step line
        _drawText(
          canvas,
          '${f.altitude}\'',
          Offset(fx + 6, fy - 14),
          const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        );
      }
    }

    // ── MAP symbol at threshold ──
    if (mapLeg != null) {
      _drawMapSymbol(canvas, Offset(threshX, groundY - 10));
    }

    // ── Bottom strip: vertical dividers, fix names, distance boxes ──
    final stripTop = groundY + 3;

    // Draw vertical dividers from ground into bottom strip
    for (final f in fixes) {
      final fx = dist2x(f.distFromThreshold);
      canvas.drawLine(
        Offset(fx, stripTop),
        Offset(fx, h - 2),
        Paint()
          ..color = AppColors.textMuted.withValues(alpha: 0.2)
          ..strokeWidth = 0.5,
      );
    }
    // Also at threshold
    canvas.drawLine(
      Offset(threshX, stripTop),
      Offset(threshX, h - 2),
      Paint()
        ..color = AppColors.textMuted.withValues(alpha: 0.2)
        ..strokeWidth = 0.5,
    );

    // Distance boxes between fixes (in the middle of bottom strip)
    final distY = stripTop + 10;
    // FAF-to-MAP distance
    if (mapLeg != null && fafFix != null) {
      final fafDist =
          ApproachChartData.parseDist(mapLeg.routeDistanceOrTime) ?? 0;
      if (fafDist > 0) {
        final mx = (dist2x(fafFix.distFromThreshold) + threshX) / 2;
        _drawDistanceBox(canvas, fafDist.toStringAsFixed(1), Offset(mx, distY));
      }
    }
    for (int i = 0; i < fixes.length - 1; i++) {
      final d =
          (fixes[i].distFromThreshold - fixes[i + 1].distFromThreshold).abs();
      if (d > 0) {
        final mx = (dist2x(fixes[i].distFromThreshold) +
                dist2x(fixes[i + 1].distFromThreshold)) /
            2;
        _drawDistanceBox(canvas, d.toStringAsFixed(1), Offset(mx, distY));
      }
    }

    // Fix names at the bottom
    final nameY = stripTop + 26;
    final drawnNameRects = <Rect>[];
    for (int i = fixes.length - 1; i >= 0; i--) {
      final f = fixes[i];
      final fx = dist2x(f.distFromThreshold);

      final tp = TextPainter(
        text: TextSpan(
          text: f.name,
          style: TextStyle(
            fontSize: 9,
            fontWeight: f.isFaf ? FontWeight.w800 : FontWeight.w600,
            color: f.isFaf ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      var drawX = fx - tp.width / 2;
      final drawRect = Rect.fromLTWH(drawX, nameY, tp.width, tp.height);

      // Check overlap with previously drawn names, shift if needed
      for (final prev in drawnNameRects) {
        if (drawRect.overlaps(prev.inflate(4))) {
          // Shift to the left of the previous label
          drawX = prev.left - tp.width - 6;
          break;
        }
      }

      drawnNameRects.add(Rect.fromLTWH(drawX, nameY, tp.width, tp.height));
      tp.paint(canvas, Offset(drawX, nameY));
    }

    // ── Missed approach section ──
    if (missLegs.isNotEmpty) {
      final missStartX = missedLeft * w;

      // Dashed separator
      _drawDashedLine(
        canvas,
        Offset(missStartX, groundY),
        Offset(missStartX, profileTop),
      );

      // "MISSED APCH" header
      _drawText(
        canvas,
        'MISSED APCH',
        Offset(missStartX + (w - missStartX) / 2, profileTop - 2),
        const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.3,
        ),
        align: TextAlign.center,
      );

      // Find hold fix
      final holdLeg = missLegs.cast<ApproachLeg?>().firstWhere(
            (l) =>
                l!.pathTermination == 'HM' || l.pathTermination == 'HF',
            orElse: () => missLegs.isNotEmpty ? missLegs.last : null,
          );
      final missAlt = holdLeg?.altitude1 ?? 10000;
      final missFix = holdLeg?.fixIdentifier ?? '';

      // Climb arrow — centered in missed zone
      final arrowX = missStartX + (w - missStartX) * 0.35;
      final ay1 = groundY - 6;
      final ay2 = alt2y(missAlt.toDouble());

      final missedPaint = Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.7)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(arrowX, ay1), Offset(arrowX, ay2), missedPaint);

      // Arrow head
      final arrowHead = Path()
        ..moveTo(arrowX - 5, ay2 + 8)
        ..lineTo(arrowX, ay2)
        ..lineTo(arrowX + 5, ay2 + 8);
      canvas.drawPath(arrowHead, missedPaint);

      // Missed info labels — right of arrow
      final infoX = arrowX + 12;

      _drawText(
        canvas,
        '$missAlt\'',
        Offset(infoX, ay2 - 2),
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );

      final mc = mapLeg?.magneticCourse;
      if (mc != null) {
        _drawText(
          canvas,
          '${mc.round()}°',
          Offset(infoX, ay2 + 14),
          const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        );
      }

      if (missFix.isNotEmpty) {
        _drawText(
          canvas,
          missFix,
          Offset(infoX, ay2 + 28),
          const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        );
      }
    }
  }

  // ── Drawing helpers ──

  void _drawMalteseCross(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    const s = 6.0;
    // Four arms of the maltese cross
    canvas.drawLine(
        Offset(center.dx, center.dy - s), Offset(center.dx, center.dy + s), paint);
    canvas.drawLine(
        Offset(center.dx - s, center.dy), Offset(center.dx + s, center.dy), paint);
    canvas.drawLine(
        Offset(center.dx - s * 0.7, center.dy - s * 0.7),
        Offset(center.dx + s * 0.7, center.dy + s * 0.7),
        paint);
    canvas.drawLine(
        Offset(center.dx + s * 0.7, center.dy - s * 0.7),
        Offset(center.dx - s * 0.7, center.dy + s * 0.7),
        paint);
  }

  void _drawMapSymbol(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = AppColors.error
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const r = 5.0;
    canvas.drawCircle(center, r, paint);
    canvas.drawLine(
        Offset(center.dx - r, center.dy), Offset(center.dx + r, center.dy), paint);
    canvas.drawLine(
        Offset(center.dx, center.dy - r), Offset(center.dx, center.dy + r), paint);
  }

  void _drawDistanceBox(Canvas canvas, String text, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final boxW = tp.width + 12;
    final boxH = tp.height + 6;
    final rect = Rect.fromCenter(center: center, width: boxW, height: boxH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = AppColors.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = AppColors.divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    tp.paint(
        canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawBoxedLabel(Canvas canvas, String text, Offset center) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final boxW = tp.width + 12;
    final boxH = tp.height + 6;
    final rect = Rect.fromCenter(center: center, width: boxW, height: boxH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = AppColors.surface,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = AppColors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    tp.paint(
        canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end) {
    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1) return;
    final ux = dx / dist;
    final uy = dy / dist;

    var d = 0.0;
    while (d < dist) {
      final segEnd = math.min(d + 4, dist);
      canvas.drawLine(
        Offset(start.dx + ux * d, start.dy + uy * d),
        Offset(start.dx + ux * segEnd, start.dy + uy * segEnd),
        paint,
      );
      d += 7;
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
  bool shouldRepaint(covariant _ProfilePainter oldDelegate) => true;
}
