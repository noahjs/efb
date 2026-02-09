import 'dart:math';

import '../models/performance_data.dart';
import '../models/told_result.dart';

class ToldCalculator {
  /// Compute pressure altitude from field elevation and altimeter setting.
  static double pressureAltitude(double fieldElevation, double altimeterInHg) {
    return fieldElevation + (29.92 - altimeterInHg) * 1000;
  }

  /// Compute headwind component (positive = headwind, negative = tailwind).
  static double headwindComponent(
      double windDir, double windSpeed, double runwayHeading) {
    final angleDiff = (windDir - runwayHeading) * pi / 180;
    return windSpeed * cos(angleDiff);
  }

  /// Compute crosswind component (always positive).
  static double crosswindComponent(
      double windDir, double windSpeed, double runwayHeading) {
    final angleDiff = (windDir - runwayHeading) * pi / 180;
    return (windSpeed * sin(angleDiff)).abs();
  }

  /// Trilinear interpolation across pressure_altitude × temperature_c × weight_lbs.
  /// Returns [groundRoll, totalDistance, vr, v50].
  static List<double>? interpolate(
    List<PerformanceDataPoint> table,
    double pa,
    double tempC,
    double weightLbs,
  ) {
    if (table.isEmpty) return null;

    // Get sorted unique breakpoints
    final altitudes = table.map((p) => p.pressureAltitude).toSet().toList()
      ..sort();
    final temps = table.map((p) => p.temperatureC).toSet().toList()..sort();
    final weights = table.map((p) => p.weightLbs).toSet().toList()..sort();

    // Clamp to bounds
    final cpa = pa.clamp(altitudes.first, altitudes.last);
    final ctmp = tempC.clamp(temps.first, temps.last);
    final cwt = weightLbs.clamp(weights.first, weights.last);

    // Helper: find a data point (or null)
    PerformanceDataPoint? findPoint(double a, double t, double w) {
      for (final p in table) {
        if (p.pressureAltitude == a &&
            p.temperatureC == t &&
            p.weightLbs == w) {
          return p;
        }
      }
      return null;
    }

    // Helper: linear interpolation
    double lerp(double v0, double v1, double t) => v0 + (v1 - v0) * t;

    // Interpolate a single output value along the weight axis
    List<double>? interpWeight(double a, double t, double w) {
      final lo = weights.lastWhere((x) => x <= w, orElse: () => weights.first);
      final hi = weights.firstWhere((x) => x >= w, orElse: () => weights.last);
      final pLo = findPoint(a, t, lo);
      final pHi = findPoint(a, t, hi);
      if (pLo == null || pHi == null) return null;

      final frac = (lo == hi) ? 0.0 : (w - lo) / (hi - lo);
      return [
        lerp(pLo.groundRollFt, pHi.groundRollFt, frac),
        lerp(pLo.totalDistanceFt, pHi.totalDistanceFt, frac),
        lerp(pLo.vrKias, pHi.vrKias, frac),
        lerp(pLo.v50Kias, pHi.v50Kias, frac),
      ];
    }

    // Interpolate along temp axis
    List<double>? interpTemp(double a, double t, double w) {
      final lo = temps.lastWhere((x) => x <= t, orElse: () => temps.first);
      final hi = temps.firstWhere((x) => x >= t, orElse: () => temps.last);
      final vLo = interpWeight(a, lo, w);
      final vHi = interpWeight(a, hi, w);
      if (vLo == null || vHi == null) return null;

      final frac = (lo == hi) ? 0.0 : (t - lo) / (hi - lo);
      return List.generate(4, (i) => lerp(vLo[i], vHi[i], frac));
    }

    // Interpolate along altitude axis
    final lo = altitudes.lastWhere((x) => x <= cpa, orElse: () => altitudes.first);
    final hi =
        altitudes.firstWhere((x) => x >= cpa, orElse: () => altitudes.last);
    final vLo = interpTemp(lo, ctmp, cwt);
    final vHi = interpTemp(hi, ctmp, cwt);
    if (vLo == null || vHi == null) return null;

    final frac = (lo == hi) ? 0.0 : (cpa - lo) / (hi - lo);
    return List.generate(4, (i) => lerp(vLo[i], vHi[i], frac));
  }

  /// Full takeoff or landing calculation pipeline.
  static ToldResult calculate({
    required FlapSetting flapSetting,
    required double fieldElevation,
    required double altimeterInHg,
    required double temperatureC,
    required double weightLbs,
    required double runwayHeading,
    double windDir = 0,
    double windSpeed = 0,
    double slopePercent = 0,
    String surfaceType = 'paved_dry',
    double safetyFactor = 1.0,
    double? maxWeight,
    String? weightLimitType,
    double? runwayAvailableFt,
    String? metarRaw,
  }) {
    final pa = pressureAltitude(fieldElevation, altimeterInHg);
    final interp = interpolate(flapSetting.table, pa, temperatureC, weightLbs);

    if (interp == null) {
      return ToldResult(
        weight: weightLbs,
        pressureAltitude: pa,
        maxWeight: maxWeight,
        weightLimitType: weightLimitType,
        isOverweight:
            maxWeight != null ? weightLbs > maxWeight : false,
        calculatedAt: DateTime.now(),
        metarRaw: metarRaw,
      );
    }

    var groundRoll = interp[0];
    var totalDistance = interp[1];
    final vr = interp[2];
    final v50 = interp[3];

    // Wind correction
    final hw = headwindComponent(windDir, windSpeed, runwayHeading);
    final windCorrectionFactor = hw >= 0
        ? 1 + flapSetting.windCorrection.headwindFactorPerKt * hw
        : 1 + flapSetting.windCorrection.tailwindFactorPerKt * hw.abs();
    groundRoll *= windCorrectionFactor;
    totalDistance *= windCorrectionFactor;

    // Slope correction
    if (slopePercent != 0) {
      final slopeFactor =
          1 + flapSetting.slopeCorrectionPerPercent * slopePercent;
      groundRoll *= slopeFactor;
      totalDistance *= slopeFactor;
    }

    // Surface factor
    final surfFactor = flapSetting.surfaceFactors[surfaceType] ?? 1.0;
    groundRoll *= surfFactor;
    totalDistance *= surfFactor;

    // Safety factor
    groundRoll *= safetyFactor;
    totalDistance *= safetyFactor;

    final isOverweight =
        maxWeight != null ? weightLbs > maxWeight : false;
    final exceedsRunway = runwayAvailableFt != null
        ? totalDistance > runwayAvailableFt
        : false;

    return ToldResult(
      vrKias: vr,
      v50Kias: v50,
      groundRollFt: groundRoll,
      totalDistanceFt: totalDistance,
      weight: weightLbs,
      pressureAltitude: pa,
      maxWeight: maxWeight,
      weightLimitType: weightLimitType,
      isOverweight: isOverweight,
      exceedsRunway: exceedsRunway,
      calculatedAt: DateTime.now(),
      metarRaw: metarRaw,
    );
  }
}
