import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/aircraft.dart';
import '../../../models/route_profile.dart';
import '../../../services/aircraft_providers.dart';
import '../../../services/airport_providers.dart';
import '../../../services/map_flight_provider.dart';
import '../../../services/profile_providers.dart';

class FlightProfileChart extends ConsumerStatefulWidget {
  const FlightProfileChart({super.key});

  @override
  ConsumerState<FlightProfileChart> createState() =>
      _FlightProfileChartState();
}

class _FlightProfileChartState extends ConsumerState<FlightProfileChart> {
  double? _scrubX; // normalized 0..1 along the chart width

  @override
  Widget build(BuildContext context) {
    final flight = ref.watch(activeFlightProvider);
    final waypoints = _parseWaypoints(flight?.routeString);

    if (waypoints.length < 2) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Add at least two waypoints to view profile',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final altitude = flight?.cruiseAltitude ?? 5500;
    final tas = flight?.trueAirspeed ?? 120;

    // Try to get performance profile for climb/descent visualization
    PerformanceProfile? perf;
    if (flight?.aircraftId != null) {
      final aircraftAsync =
          ref.watch(aircraftDetailProvider(flight!.aircraftId!));
      final aircraft = aircraftAsync.value;
      if (aircraft != null) {
        perf = aircraft.performanceProfiles
                .where((p) => p.id == flight.performanceProfileId)
                .firstOrNull ??
            aircraft.defaultProfile;
      }
    }

    // Resolve waypoints to coordinates
    final resolvedAsync =
        ref.watch(resolvedRouteProvider(waypoints.join(',')));

    return resolvedAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Failed to resolve route',
            style: TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ),
      ),
      data: (resolved) {
        final coords = <Map<String, double>>[];
        for (final wp in resolved) {
          if (wp is Map &&
              wp['latitude'] != null &&
              wp['longitude'] != null) {
            coords.add({
              'lat': (wp['latitude'] as num).toDouble(),
              'lng': (wp['longitude'] as num).toDouble(),
            });
          }
        }

        if (coords.length < 2) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'Could not resolve waypoint coordinates',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          );
        }

        final params = RouteProfileParams(
          waypoints: coords,
          identifiers: waypoints,
          altitude: altitude,
          tas: tas,
        );

        final profileAsync = ref.watch(routeProfileProvider(params));

        return profileAsync.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Loading terrain & winds...',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          error: (_, _) => const SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'Failed to load profile data',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ),
          data: (profile) {
            if (profile == null || profile.points.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'No profile data available',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              );
            }

            return _buildChart(profile, perf);
          },
        );
      },
    );
  }

  Widget _buildChart(RouteProfileData profile, PerformanceProfile? perf) {
    RouteProfilePoint? scrubPoint;
    if (_scrubX != null && profile.points.isNotEmpty) {
      final targetDist = _scrubX! * profile.totalDistanceNm;
      scrubPoint = profile.points.reduce((a, b) =>
          (a.distanceNm - targetDist).abs() <
                  (b.distanceNm - targetDist).abs()
              ? a
              : b);
    }

    // Compute TOC/TOD distances from performance profile
    double? tocDistNm;
    double? todDistNm;
    if (perf != null &&
        perf.climbRate != null &&
        perf.climbRate! > 0 &&
        perf.climbSpeed != null &&
        perf.climbSpeed! > 0 &&
        perf.descentRate != null &&
        perf.descentRate! > 0 &&
        perf.descentSpeed != null &&
        perf.descentSpeed! > 0) {
      final altToClimb =
          profile.cruiseAltitudeFt - profile.departureElevationFt;
      final altToDescend =
          profile.cruiseAltitudeFt - profile.destinationElevationFt;

      if (altToClimb > 0 && altToDescend > 0) {
        final climbDist =
            perf.climbSpeed! * (altToClimb / perf.climbRate!) / 60;
        final descentDist =
            perf.descentSpeed! * (altToDescend / perf.descentRate!) / 60;

        if (climbDist + descentDist <= profile.totalDistanceNm) {
          tocDistNm = climbDist;
          todDistNm = profile.totalDistanceNm - descentDist;
        } else {
          final scale =
              profile.totalDistanceNm / (climbDist + descentDist);
          tocDistNm = climbDist * scale;
          todDistNm = tocDistNm;
        }
      }
    }

    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final localX = details.localPosition.dx;
              const leftPad = 44.0;
              const rightPad = 12.0;
              final chartWidth = box.size.width - leftPad - rightPad;
              final normalized =
                  ((localX - leftPad) / chartWidth).clamp(0.0, 1.0);
              setState(() => _scrubX = normalized);
            },
            onHorizontalDragEnd: (_) => setState(() => _scrubX = null),
            onHorizontalDragCancel: () => setState(() => _scrubX = null),
            onTapDown: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final localX = details.localPosition.dx;
              const leftPad = 44.0;
              const rightPad = 12.0;
              final chartWidth = box.size.width - leftPad - rightPad;
              final normalized =
                  ((localX - leftPad) / chartWidth).clamp(0.0, 1.0);
              setState(() => _scrubX = normalized);
            },
            onTapUp: (_) => setState(() => _scrubX = null),
            child: CustomPaint(
              size: const Size(double.infinity, 280),
              painter: _FlightProfilePainter(
                profile: profile,
                scrubX: _scrubX,
                tocDistNm: tocDistNm,
                todDistNm: todDistNm,
              ),
            ),
          ),
          // Scrub info overlay
          if (scrubPoint != null && _scrubX != null)
            Positioned(
              top: 6,
              left: _scrubX! < 0.5 ? null : 50,
              right: _scrubX! >= 0.5 ? null : 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontFeatures: [ui.FontFeature.tabularFigures()],
                    fontSize: 11,
                    height: 1.4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${scrubPoint.distanceNm.toStringAsFixed(1)} NM',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Terrain  ${_fmtAlt(scrubPoint.elevationFt)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary),
                      ),
                      Text(
                        'Wind  ${scrubPoint.windDirection.round().toString().padLeft(3, '0')}/${scrubPoint.windSpeed.round()}kt',
                        style: const TextStyle(
                            color: AppColors.textSecondary),
                      ),
                      Text(
                        'GS  ${scrubPoint.groundspeed.round()} kt',
                        style: const TextStyle(
                            color: AppColors.textSecondary),
                      ),
                      Text(
                        scrubPoint.headwindComponent >= 0
                            ? 'Headwind  ${scrubPoint.headwindComponent.round()} kt'
                            : 'Tailwind  ${(-scrubPoint.headwindComponent).round()} kt',
                        style: TextStyle(
                          color: scrubPoint.headwindComponent >= 0
                              ? const Color(0xFFFF6B6B)
                              : const Color(0xFF51CF66),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtAlt(double ft) {
    final r = ft.round();
    if (r >= 18000) return 'FL${(r / 100).round()}';
    if (r >= 1000) {
      final thousands = r ~/ 1000;
      final remainder = r % 1000;
      if (remainder == 0) return '$thousands,000 ft';
      return '$thousands,${remainder.toString().padLeft(3, '0')} ft';
    }
    return '$r ft';
  }

  List<String> _parseWaypoints(String? routeString) {
    if (routeString == null || routeString.trim().isEmpty) return [];
    return routeString.trim().split(RegExp(r'\s+'));
  }
}

// ─── Painter ────────────────────────────────────────────────────────────────

class _FlightProfilePainter extends CustomPainter {
  final RouteProfileData profile;
  final double? scrubX;
  final double? tocDistNm;
  final double? todDistNm;

  // Layout constants
  static const double _leftPad = 44;
  static const double _rightPad = 12;
  static const double _topPad = 10;
  static const double _bottomPad = 28;

  // Colors
  static const _terrainTop = Color(0xFF6B7D4A);     // olive ridge
  static const _terrainBottom = Color(0xFF3B3D2F);   // dark earth
  static const _terrainStroke = Color(0xFF8A9A62);   // subtle ridge line
  static const _warningTint = Color(0xFFFF5252);
  static const _flightPath = Color(0xFFE040FB);      // magenta (aviation std)
  static const _flightPathFade = Color(0xBBE040FB);
  static const _gridLine = Color(0x30FFFFFF);
  static const _pillHead = Color(0xFF5A5D63);        // gray – headwind
  static const _pillTail = Color(0xFF2D8C3C);        // green – tailwind

  _FlightProfilePainter({
    required this.profile,
    this.scrubX,
    this.tocDistNm,
    this.todDistNm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.points.isEmpty) return;

    final chartLeft = _leftPad;
    final chartRight = size.width - _rightPad;
    final chartTop = _topPad;
    final chartBottom = size.height - _bottomPad;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // Altitude range
    final maxElev = profile.maxTerrainFt;
    final cruiseAlt = profile.cruiseAltitudeFt;
    final altCeiling = max(cruiseAlt + 2000, maxElev + 2000).toDouble();
    const altFloor = 0.0;
    final totalDist = profile.totalDistanceNm;
    if (totalDist <= 0) return;

    double distToX(double d) => chartLeft + (d / totalDist) * chartWidth;
    double altToY(double alt) =>
        chartBottom -
        ((alt - altFloor) / (altCeiling - altFloor)) * chartHeight;

    // Draw layers bottom-to-top so overlaps are correct
    _drawGrid(canvas, chartLeft, chartRight, chartTop, chartBottom,
        altFloor, altCeiling, totalDist, distToX, altToY);
    _drawTerrain(canvas, chartTop, chartBottom, chartWidth, distToX, altToY, cruiseAlt);
    _drawFlightPath(
        canvas, chartLeft, chartRight, distToX, altToY, cruiseAlt, totalDist);
    _drawWaypointMarkers(canvas, chartTop, chartBottom, distToX);
    _drawWindPills(canvas, chartLeft, chartRight, distToX, altToY);

    // Scrub crosshair
    if (scrubX != null) {
      final x = chartLeft + scrubX! * chartWidth;
      canvas.drawLine(
        Offset(x, chartTop),
        Offset(x, chartBottom),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }

    // Chart border
    canvas.drawRect(
      Rect.fromLTRB(chartLeft, chartTop, chartRight, chartBottom),
      Paint()
        ..color = AppColors.divider.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  // ── Grid ──────────────────────────────────────────────────────────────────

  void _drawGrid(
    Canvas canvas,
    double chartLeft,
    double chartRight,
    double chartTop,
    double chartBottom,
    double altFloor,
    double altCeiling,
    double totalDist,
    double Function(double) distToX,
    double Function(double) altToY,
  ) {
    final gridPaint = Paint()
      ..color = _gridLine
      ..strokeWidth = 0.5;

    // Altitude gridlines
    final altStep = _niceStep(altCeiling - altFloor, 5);
    for (double alt = altStep; alt <= altCeiling; alt += altStep) {
      final y = altToY(alt);
      if (y < chartTop || y > chartBottom) continue;
      canvas.drawLine(
          Offset(chartLeft, y), Offset(chartRight, y), gridPaint);

      final label = alt >= 18000
          ? 'FL${(alt / 100).round()}'
          : _fmtThousands(alt);
      _drawLabel(canvas, label, Offset(chartLeft - 4, y),
          AppColors.textMuted, 10,
          align: TextAlign.right, maxWidth: _leftPad - 6);
    }

    // Distance gridlines
    final distStep = _niceStep(totalDist, 6);
    for (double d = 0; d <= totalDist; d += distStep) {
      final x = distToX(d);
      if (x < chartLeft || x > chartRight) continue;
      canvas.drawLine(
          Offset(x, chartTop), Offset(x, chartBottom), gridPaint);
      _drawLabel(canvas, '${d.round()}', Offset(x, chartBottom + 3),
          AppColors.textMuted, 9,
          align: TextAlign.center, maxWidth: 30);
    }
  }

  // ── Terrain ───────────────────────────────────────────────────────────────

  void _drawTerrain(
    Canvas canvas,
    double chartTop,
    double chartBottom,
    double chartWidth,
    double Function(double) distToX,
    double Function(double) altToY,
    double cruiseAlt,
  ) {
    if (profile.points.isEmpty) return;

    final terrainPath = Path();
    final warningPath = Path();
    final clearanceThreshold = cruiseAlt - 1000;

    terrainPath.moveTo(
        distToX(profile.points.first.distanceNm), chartBottom);

    for (int i = 0; i < profile.points.length; i++) {
      final p = profile.points[i];
      final x = distToX(p.distanceNm);
      final y = altToY(p.elevationFt);
      terrainPath.lineTo(x, y);

      if (p.elevationFt > clearanceThreshold) {
        if (i == 0 ||
            profile.points[i - 1].elevationFt <= clearanceThreshold) {
          warningPath.moveTo(x, chartBottom);
        }
        warningPath.lineTo(x, y);
        if (i == profile.points.length - 1 ||
            profile.points[i + 1].elevationFt <= clearanceThreshold) {
          warningPath.lineTo(x, chartBottom);
          warningPath.close();
        }
      }
    }

    terrainPath.lineTo(
        distToX(profile.points.last.distanceNm), chartBottom);
    terrainPath.close();

    // Terrain fill — earthy gradient
    final terrainBounds = terrainPath.getBounds();
    final terrainFill = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, terrainBounds.top),
        Offset(0, chartBottom),
        [_terrainTop, _terrainBottom],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(terrainPath, terrainFill);

    // Ridge line
    final topEdgePath = Path();
    topEdgePath.moveTo(distToX(profile.points.first.distanceNm),
        altToY(profile.points.first.elevationFt));
    for (int i = 1; i < profile.points.length; i++) {
      topEdgePath.lineTo(distToX(profile.points[i].distanceNm),
          altToY(profile.points[i].elevationFt));
    }
    canvas.drawPath(
      topEdgePath,
      Paint()
        ..color = _terrainStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );

    // Warning overlay
    if (!warningPath.getBounds().isEmpty) {
      canvas.drawPath(
        warningPath,
        Paint()
          ..color = _warningTint.withValues(alpha: 0.20)
          ..style = PaintingStyle.fill,
      );
    }
  }

  // ── Flight path ───────────────────────────────────────────────────────────

  void _drawFlightPath(
    Canvas canvas,
    double chartLeft,
    double chartRight,
    double Function(double) distToX,
    double Function(double) altToY,
    double cruiseAlt,
    double totalDist,
  ) {
    final cruiseY = altToY(cruiseAlt);
    final altLabel = cruiseAlt >= 18000
        ? 'FL${(cruiseAlt / 100).round()}'
        : '${cruiseAlt.round()} ft';

    if (tocDistNm != null && todDistNm != null) {
      final depElev = profile.departureElevationFt;
      final destElev = profile.destinationElevationFt;
      final pathPaint = Paint()
        ..color = _flightPath
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Climb (solid)
      canvas.drawLine(
        Offset(distToX(0), altToY(depElev)),
        Offset(distToX(tocDistNm!), cruiseY),
        pathPaint,
      );

      // Cruise (dashed)
      _drawDashedLine(canvas, distToX(tocDistNm!), distToX(todDistNm!),
          cruiseY, _flightPathFade, 2.0);

      // Descent (solid)
      canvas.drawLine(
        Offset(distToX(todDistNm!), cruiseY),
        Offset(distToX(totalDist), altToY(destElev)),
        pathPaint,
      );

      // TOC / TOD dots
      const dotR = 3.0;
      final dotPaint = Paint()..color = _flightPath;
      canvas.drawCircle(
          Offset(distToX(tocDistNm!), cruiseY), dotR, dotPaint);
      canvas.drawCircle(
          Offset(distToX(todDistNm!), cruiseY), dotR, dotPaint);

      // TOC label
      _drawLabel(
        canvas,
        'TOC',
        Offset(distToX(tocDistNm!), cruiseY - 6),
        _flightPath,
        9,
        align: TextAlign.center,
        maxWidth: 30,
        below: false,
      );

      // TOD label (skip if too close to TOC)
      if ((todDistNm! - tocDistNm!) / totalDist > 0.08) {
        _drawLabel(
          canvas,
          'TOD',
          Offset(distToX(todDistNm!), cruiseY - 6),
          _flightPath,
          9,
          align: TextAlign.center,
          maxWidth: 30,
          below: false,
        );
      }

      // Altitude label — right side
      _drawLabel(canvas, altLabel, Offset(chartRight - 2, cruiseY - 1),
          _flightPath, 10,
          align: TextAlign.right, maxWidth: 70, fontWeight: FontWeight.w600);
    } else {
      // Fallback: simple dashed cruise line
      _drawDashedLine(
          canvas, chartLeft, chartRight, cruiseY, AppColors.accent, 1.5);
      _drawLabel(canvas, 'CRZ $altLabel', Offset(chartRight - 2, cruiseY - 1),
          AppColors.accent, 10,
          align: TextAlign.right, maxWidth: 90);
    }
  }

  // ── Waypoint markers ──────────────────────────────────────────────────────

  void _drawWaypointMarkers(
    Canvas canvas,
    double chartTop,
    double chartBottom,
    double Function(double) distToX,
  ) {
    final markerPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;

    for (final marker in profile.waypointMarkers) {
      final x = distToX(marker.distanceNm);

      // Dashed vertical line
      const dashH = 4.0;
      const gapH = 4.0;
      double y = chartTop;
      while (y < chartBottom) {
        final endY = min(y + dashH, chartBottom);
        canvas.drawLine(Offset(x, y), Offset(x, endY), markerPaint);
        y += dashH + gapH;
      }

      // Identifier label below chart
      _drawLabel(
        canvas,
        marker.identifier,
        Offset(x, chartBottom + 14),
        AppColors.textSecondary,
        9,
        align: TextAlign.center,
        maxWidth: 40,
        fontWeight: FontWeight.w600,
      );
    }
  }

  // ── Wind pills ────────────────────────────────────────────────────────────

  void _drawWindPills(
    Canvas canvas,
    double chartLeft,
    double chartRight,
    double Function(double) distToX,
    double Function(double) altToY,
  ) {
    if (profile.windLayers.isEmpty) return;

    // Track placed pill rects for overlap avoidance
    final placed = <Rect>[];

    for (final layer in profile.windLayers) {
      final pillCenterY = altToY(layer.altitudeFt);

      for (final seg in layer.segments) {
        // Skip pills below terrain
        final terrainAtDist = _terrainElevationAt(seg.distanceNm);
        if (layer.altitudeFt <= terrainAtDist + 200) continue;

        final hw = seg.headwindComponent;
        if (hw.abs() < 2) continue; // skip negligible

        final isHeadwind = hw > 0;
        final magnitude = hw.abs().round();
        final label =
            isHeadwind ? '$magnitude\u2190' : '$magnitude\u2192';

        final x = distToX(seg.distanceNm);

        // Measure text
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();

        final pw = tp.width + 8;
        final ph = tp.height + 4;
        final candidate = Rect.fromCenter(
          center: Offset(x, pillCenterY),
          width: pw,
          height: ph,
        );

        // Skip if it would overlap a previously placed pill
        if (_overlaps(candidate, placed)) continue;

        // Skip if outside chart bounds
        if (candidate.left < chartLeft || candidate.right > chartRight) {
          continue;
        }

        placed.add(candidate.inflate(1)); // add 1px gutter

        final bgColor = isHeadwind ? _pillHead : _pillTail;
        canvas.drawRRect(
          RRect.fromRectAndRadius(candidate, const Radius.circular(6)),
          Paint()..color = bgColor.withValues(alpha: 0.80),
        );

        tp.paint(
          canvas,
          Offset(x - tp.width / 2, pillCenterY - tp.height / 2),
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double _terrainElevationAt(double distanceNm) {
    if (profile.points.isEmpty) return 0;
    double bestDiff = double.infinity;
    double elevation = 0;
    for (final p in profile.points) {
      final diff = (p.distanceNm - distanceNm).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        elevation = p.elevationFt;
      }
    }
    return elevation;
  }

  bool _overlaps(Rect candidate, List<Rect> placed) {
    for (final r in placed) {
      if (candidate.overlaps(r)) return true;
    }
    return false;
  }

  void _drawDashedLine(Canvas canvas, double x1, double x2, double y,
      Color color, double strokeWidth) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    const dashW = 6.0;
    const gapW = 4.0;
    double x = x1;
    while (x < x2) {
      final endX = min(x + dashW, x2);
      canvas.drawLine(Offset(x, y), Offset(endX, y), paint);
      x += dashW + gapW;
    }
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color,
    double fontSize, {
    TextAlign align = TextAlign.left,
    double maxWidth = 100,
    FontWeight fontWeight = FontWeight.normal,
    bool below = true,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    tp.layout(maxWidth: maxWidth);

    double dx;
    switch (align) {
      case TextAlign.center:
        dx = anchor.dx - tp.width / 2;
        break;
      case TextAlign.right:
        dx = anchor.dx - tp.width;
        break;
      default:
        dx = anchor.dx;
    }
    final dy = below ? anchor.dy : anchor.dy - tp.height;
    tp.paint(canvas, Offset(dx, dy));
  }

  String _fmtThousands(double alt) {
    final r = alt.round();
    if (r == 0) return '0';
    if (r % 1000 == 0) return '${r ~/ 1000}k';
    return '${(r / 1000).toStringAsFixed(1)}k';
  }

  double _niceStep(double range, int targetLines) {
    final rough = range / targetLines;
    final magnitude = pow(10, (log(rough) / ln10).floor()).toDouble();
    final residual = rough / magnitude;
    double nice;
    if (residual <= 1.5) {
      nice = 1;
    } else if (residual <= 3) {
      nice = 2;
    } else if (residual <= 7) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * magnitude;
  }

  @override
  bool shouldRepaint(covariant _FlightProfilePainter oldDelegate) =>
      oldDelegate.profile != profile ||
      oldDelegate.scrubX != scrubX ||
      oldDelegate.tocDistNm != tocDistNm ||
      oldDelegate.todDistNm != todDistNm;
}
