import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/weight_balance.dart';

class WBEnvelopeChart extends StatelessWidget {
  final List<WBEnvelope> envelopes;
  final WBCalculationResult result;
  final String axis;
  final double? maxLandingWeight;
  final double? maxZeroFuelWeight;
  final double? maxTakeoffWeight;
  final double? maxRampWeight;

  const WBEnvelopeChart({
    super.key,
    required this.envelopes,
    required this.result,
    this.axis = 'longitudinal',
    this.maxLandingWeight,
    this.maxZeroFuelWeight,
    this.maxTakeoffWeight,
    this.maxRampWeight,
  });

  @override
  Widget build(BuildContext context) {
    final relevantEnvelopes =
        envelopes.where((e) => e.axis == axis).toList();

    if (relevantEnvelopes.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'No envelope data configured',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    return Container(
      height: 260,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              axis == 'longitudinal' ? 'CG ENVELOPE' : 'LATERAL CG ENVELOPE',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CustomPaint(
                size: Size.infinite,
                painter: _EnvelopePainter(
                  envelopes: relevantEnvelopes,
                  result: result,
                  axis: axis,
                  weightLimits: _buildWeightLimits(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<({String label, double weight, Color color})> _buildWeightLimits() {
    final limits = <({String label, double weight, Color color})>[];
    if (maxZeroFuelWeight != null) {
      limits.add((label: 'Max ZFW', weight: maxZeroFuelWeight!, color: AppColors.info));
    }
    if (maxLandingWeight != null) {
      limits.add((label: 'Max LDW', weight: maxLandingWeight!, color: AppColors.accent));
    }
    if (maxTakeoffWeight != null) {
      limits.add((label: 'Max TOW', weight: maxTakeoffWeight!, color: AppColors.warning));
    }
    if (maxRampWeight != null) {
      limits.add((label: 'Max Ramp', weight: maxRampWeight!, color: Colors.purple));
    }
    return limits;
  }
}

class _EnvelopePainter extends CustomPainter {
  final List<WBEnvelope> envelopes;
  final WBCalculationResult result;
  final String axis;
  final List<({String label, double weight, Color color})> weightLimits;

  _EnvelopePainter({
    required this.envelopes,
    required this.result,
    required this.axis,
    this.weightLimits = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (envelopes.isEmpty) return;

    // Collect all points to determine bounds
    final allPoints = envelopes.expand((e) => e.points).toList();
    if (allPoints.isEmpty) return;

    // Data points to plot
    final dataPoints = _getDataPoints();

    double minCg = allPoints.map((p) => p.cg).reduce(min);
    double maxCg = allPoints.map((p) => p.cg).reduce(max);
    double minW = allPoints.map((p) => p.weight).reduce(min);
    double maxW = allPoints.map((p) => p.weight).reduce(max);

    // Include data points in bounds
    for (final dp in dataPoints) {
      minCg = min(minCg, dp.cg);
      maxCg = max(maxCg, dp.cg);
      minW = min(minW, dp.weight);
      maxW = max(maxW, dp.weight);
    }

    // Include weight limits in bounds
    for (final limit in weightLimits) {
      minW = min(minW, limit.weight);
      maxW = max(maxW, limit.weight);
    }

    // Add margin
    final cgRange = maxCg - minCg;
    final wRange = maxW - minW;
    minCg -= cgRange * 0.1;
    maxCg += cgRange * 0.1;
    minW -= wRange * 0.1;
    maxW += wRange * 0.1;

    // Mapping functions (CG on x-axis, Weight on y-axis, inverted)
    final chartArea = Rect.fromLTWH(36, 0, size.width - 44, size.height - 20);
    double mapCg(double cg) =>
        chartArea.left +
        (cg - minCg) / (maxCg - minCg) * chartArea.width;
    double mapW(double w) =>
        chartArea.bottom -
        (w - minW) / (maxW - minW) * chartArea.height;

    // Draw axes
    final axisPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 0.5;
    canvas.drawLine(
        Offset(chartArea.left, chartArea.top),
        Offset(chartArea.left, chartArea.bottom),
        axisPaint);
    canvas.drawLine(
        Offset(chartArea.left, chartArea.bottom),
        Offset(chartArea.right, chartArea.bottom),
        axisPaint);

    // Draw axis labels
    _drawText(canvas, '${minW.round()}', Offset(0, chartArea.bottom - 6),
        AppColors.textMuted, 9);
    _drawText(canvas, '${maxW.round()}', Offset(0, chartArea.top + 2),
        AppColors.textMuted, 9);
    _drawText(canvas, '${minCg.toStringAsFixed(1)}',
        Offset(chartArea.left - 4, chartArea.bottom + 4),
        AppColors.textMuted, 9);
    _drawText(canvas, '${maxCg.toStringAsFixed(1)}',
        Offset(chartArea.right - 16, chartArea.bottom + 4),
        AppColors.textMuted, 9);

    // Draw envelope polygon(s)
    for (final env in envelopes) {
      if (env.points.length < 3) continue;

      final path = Path();
      path.moveTo(mapCg(env.points[0].cg), mapW(env.points[0].weight));
      for (int i = 1; i < env.points.length; i++) {
        path.lineTo(mapCg(env.points[i].cg), mapW(env.points[i].weight));
      }
      path.close();

      // Fill
      final fillPaint = Paint()
        ..color = AppColors.success.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Stroke
      final strokePaint = Paint()
        ..color = AppColors.success.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(path, strokePaint);
    }

    // Draw weight limit lines (dotted horizontal)
    for (final limit in weightLimits) {
      final y = mapW(limit.weight);
      if (y < chartArea.top || y > chartArea.bottom) continue;

      final dashPaint = Paint()
        ..color = limit.color.withValues(alpha: 0.5)
        ..strokeWidth = 1;

      // Draw dashed line
      const dashWidth = 4.0;
      const dashGap = 3.0;
      double startX = chartArea.left;
      while (startX < chartArea.right) {
        final endX = min(startX + dashWidth, chartArea.right);
        canvas.drawLine(Offset(startX, y), Offset(endX, y), dashPaint);
        startX += dashWidth + dashGap;
      }

      // Draw label on right side
      _drawText(canvas, limit.label,
          Offset(chartArea.right - 42, y - 12), limit.color.withValues(alpha: 0.7), 8);
    }

    // Draw condition points
    final colors = {
      'ZFW': AppColors.info,
      'TOW': AppColors.warning,
      'LDW': AppColors.accent,
    };

    // Draw connecting line
    if (dataPoints.length >= 2) {
      final linePaint = Paint()
        ..color = AppColors.textMuted.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final linePath = Path();
      linePath.moveTo(
          mapCg(dataPoints[0].cg), mapW(dataPoints[0].weight));
      for (int i = 1; i < dataPoints.length; i++) {
        linePath.lineTo(
            mapCg(dataPoints[i].cg), mapW(dataPoints[i].weight));
      }
      canvas.drawPath(linePath, linePaint);
    }

    // Draw points
    for (int i = 0; i < dataPoints.length; i++) {
      final dp = dataPoints[i];
      final color = colors.values.elementAt(i % colors.length);
      final x = mapCg(dp.cg);
      final y = mapW(dp.weight);

      // Outer ring
      canvas.drawCircle(
          Offset(x, y),
          5,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      // Inner fill
      canvas.drawCircle(
          Offset(x, y),
          3,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill);

      // Label
      _drawText(canvas, colors.keys.elementAt(i % colors.length),
          Offset(x + 6, y - 6), color, 9);
    }
  }

  List<({double cg, double weight})> _getDataPoints() {
    if (axis == 'longitudinal') {
      return [
        (cg: result.zfwCg, weight: result.zfw),
        (cg: result.towCg, weight: result.tow),
        (cg: result.ldwCg, weight: result.ldw),
      ];
    } else {
      return [
        (cg: result.zfwLateralCg ?? 0, weight: result.zfw),
        (cg: result.towLateralCg ?? 0, weight: result.tow),
        (cg: result.ldwLateralCg ?? 0, weight: result.ldw),
      ];
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, Color color,
      double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _EnvelopePainter oldDelegate) =>
      oldDelegate.result != result || oldDelegate.envelopes != envelopes;
}
