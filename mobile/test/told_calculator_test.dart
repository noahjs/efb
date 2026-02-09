import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/services/told_calculator.dart';
import 'package:efb_mobile/models/performance_data.dart';

/// Builds a minimal 3D lookup table for testing interpolation.
/// Grid: altitudes × temps × weights, each combo gets deterministic values.
List<PerformanceDataPoint> _buildTestTable({
  List<double> altitudes = const [0, 4000, 8000],
  List<double> temps = const [0, 20, 40],
  List<double> weights = const [5000, 6000, 7000],
}) {
  final points = <PerformanceDataPoint>[];
  for (final a in altitudes) {
    for (final t in temps) {
      for (final w in weights) {
        // Simple formulas that increase with each axis so we can verify
        // interpolation direction and monotonicity.
        final baseRoll = 500 + a * 0.05 + t * 2 + w * 0.04;
        points.add(PerformanceDataPoint(
          pressureAltitude: a,
          temperatureC: t,
          weightLbs: w,
          groundRollFt: baseRoll,
          totalDistanceFt: baseRoll * 1.5,
          vrKias: 70 + w * 0.002,
          v50Kias: 85 + w * 0.002,
        ));
      }
    }
  }
  return points;
}

FlapSetting _buildTestFlapSetting({
  List<PerformanceDataPoint>? table,
}) {
  return FlapSetting(
    name: 'TO',
    code: 'to',
    isDefault: true,
    table: table ?? _buildTestTable(),
    windCorrection: const WindCorrection(
      headwindFactorPerKt: -0.015,
      tailwindFactorPerKt: 0.035,
    ),
    surfaceFactors: const {
      'paved_dry': 1.0,
      'paved_wet': 1.15,
      'grass_dry': 1.20,
      'grass_wet': 1.30,
    },
    slopeCorrectionPerPercent: 0.05,
  );
}

void main() {
  group('ToldCalculator.pressureAltitude', () {
    test('returns field elevation at standard pressure', () {
      expect(ToldCalculator.pressureAltitude(5000, 29.92), 5000.0);
    });

    test('increases altitude with lower altimeter', () {
      // 29.92 - 28.92 = 1.00 → +1000 ft
      expect(ToldCalculator.pressureAltitude(5000, 28.92), 6000.0);
    });

    test('decreases altitude with higher altimeter', () {
      // 29.92 - 30.92 = -1.00 → -1000 ft
      expect(ToldCalculator.pressureAltitude(5000, 30.92), 4000.0);
    });

    test('handles sea level', () {
      expect(ToldCalculator.pressureAltitude(0, 29.92), 0.0);
    });

    test('handles fractional altimeter', () {
      // 29.92 - 29.42 = 0.50 → +500 ft
      final pa = ToldCalculator.pressureAltitude(2000, 29.42);
      expect(pa, closeTo(2500, 0.01));
    });
  });

  group('ToldCalculator.headwindComponent', () {
    test('direct headwind returns full wind speed', () {
      // Wind from 360, runway heading 360 → 0° diff → cos(0) = 1
      final hw = ToldCalculator.headwindComponent(360, 20, 360);
      expect(hw, closeTo(20, 0.01));
    });

    test('direct tailwind returns negative full wind speed', () {
      // Wind from 180, runway heading 360 → 180° diff → cos(180) = -1
      final hw = ToldCalculator.headwindComponent(180, 20, 360);
      expect(hw, closeTo(-20, 0.01));
    });

    test('pure crosswind returns zero headwind', () {
      // Wind from 090, runway heading 360 → 90° diff → cos(90) ≈ 0
      final hw = ToldCalculator.headwindComponent(90, 20, 360);
      expect(hw, closeTo(0, 0.01));
    });

    test('45-degree angle returns cos(45) component', () {
      final hw = ToldCalculator.headwindComponent(45, 20, 360);
      expect(hw, closeTo(20 * cos(45 * pi / 180), 0.01));
    });

    test('zero wind returns zero', () {
      expect(ToldCalculator.headwindComponent(270, 0, 180), 0.0);
    });
  });

  group('ToldCalculator.crosswindComponent', () {
    test('pure crosswind returns full wind speed', () {
      final xw = ToldCalculator.crosswindComponent(90, 20, 360);
      expect(xw, closeTo(20, 0.01));
    });

    test('direct headwind returns zero crosswind', () {
      final xw = ToldCalculator.crosswindComponent(360, 20, 360);
      expect(xw, closeTo(0, 0.01));
    });

    test('direct tailwind returns zero crosswind', () {
      final xw = ToldCalculator.crosswindComponent(180, 20, 360);
      expect(xw, closeTo(0, 0.01));
    });

    test('crosswind is always positive (left or right)', () {
      final left = ToldCalculator.crosswindComponent(270, 20, 360);
      final right = ToldCalculator.crosswindComponent(90, 20, 360);
      expect(left, greaterThan(0));
      expect(right, greaterThan(0));
      expect(left, closeTo(right, 0.01));
    });
  });

  group('ToldCalculator.interpolate', () {
    late List<PerformanceDataPoint> table;

    setUp(() {
      table = _buildTestTable();
    });

    test('returns null for empty table', () {
      expect(ToldCalculator.interpolate([], 0, 0, 5000), isNull);
    });

    test('returns exact values at a grid point', () {
      // At (0, 0, 5000): groundRoll = 500 + 0 + 0 + 200 = 700
      final result = ToldCalculator.interpolate(table, 0, 0, 5000);
      expect(result, isNotNull);
      expect(result![0], closeTo(700, 0.01)); // ground roll
      expect(result[1], closeTo(1050, 0.01)); // total distance (700 * 1.5)
      expect(result[2], closeTo(80, 0.01)); // vr (70 + 5000*0.002)
      expect(result[3], closeTo(95, 0.01)); // v50 (85 + 5000*0.002)
    });

    test('interpolates midpoint between two weights', () {
      // Between 5000 and 6000 at midpoint 5500
      final lo = ToldCalculator.interpolate(table, 0, 0, 5000);
      final hi = ToldCalculator.interpolate(table, 0, 0, 6000);
      final mid = ToldCalculator.interpolate(table, 0, 0, 5500);
      expect(mid, isNotNull);
      for (int i = 0; i < 4; i++) {
        expect(mid![i], closeTo((lo![i] + hi![i]) / 2, 0.01));
      }
    });

    test('interpolates midpoint between two temperatures', () {
      final lo = ToldCalculator.interpolate(table, 0, 0, 5000);
      final hi = ToldCalculator.interpolate(table, 0, 20, 5000);
      final mid = ToldCalculator.interpolate(table, 0, 10, 5000);
      expect(mid, isNotNull);
      for (int i = 0; i < 4; i++) {
        expect(mid![i], closeTo((lo![i] + hi![i]) / 2, 0.01));
      }
    });

    test('interpolates midpoint between two altitudes', () {
      final lo = ToldCalculator.interpolate(table, 0, 0, 5000);
      final hi = ToldCalculator.interpolate(table, 4000, 0, 5000);
      final mid = ToldCalculator.interpolate(table, 2000, 0, 5000);
      expect(mid, isNotNull);
      for (int i = 0; i < 4; i++) {
        expect(mid![i], closeTo((lo![i] + hi![i]) / 2, 0.01));
      }
    });

    test('clamps below minimum altitude', () {
      final atMin = ToldCalculator.interpolate(table, 0, 0, 5000);
      final belowMin = ToldCalculator.interpolate(table, -1000, 0, 5000);
      expect(belowMin, isNotNull);
      for (int i = 0; i < 4; i++) {
        expect(belowMin![i], closeTo(atMin![i], 0.01));
      }
    });

    test('clamps above maximum weight', () {
      final atMax = ToldCalculator.interpolate(table, 0, 0, 7000);
      final aboveMax = ToldCalculator.interpolate(table, 0, 0, 9000);
      expect(aboveMax, isNotNull);
      for (int i = 0; i < 4; i++) {
        expect(aboveMax![i], closeTo(atMax![i], 0.01));
      }
    });

    test('higher altitude produces longer ground roll', () {
      final low = ToldCalculator.interpolate(table, 0, 20, 6000);
      final high = ToldCalculator.interpolate(table, 8000, 20, 6000);
      expect(high![0], greaterThan(low![0]));
    });

    test('higher weight produces longer ground roll', () {
      final light = ToldCalculator.interpolate(table, 0, 20, 5000);
      final heavy = ToldCalculator.interpolate(table, 0, 20, 7000);
      expect(heavy![0], greaterThan(light![0]));
    });

    test('higher temperature produces longer ground roll', () {
      final cool = ToldCalculator.interpolate(table, 0, 0, 6000);
      final hot = ToldCalculator.interpolate(table, 0, 40, 6000);
      expect(hot![0], greaterThan(cool![0]));
    });
  });

  group('ToldCalculator.calculate', () {
    late FlapSetting flapSetting;

    setUp(() {
      flapSetting = _buildTestFlapSetting();
    });

    test('returns valid result at standard conditions', () {
      final result = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
      );

      expect(result.groundRollFt, isNotNull);
      expect(result.totalDistanceFt, isNotNull);
      expect(result.vrKias, isNotNull);
      expect(result.v50Kias, isNotNull);
      expect(result.pressureAltitude, 0.0);
      expect(result.weight, 6000.0);
      expect(result.isOverweight, false);
      expect(result.exceedsRunway, false);
    });

    test('headwind reduces distances', () {
      final noWind = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        windDir: 0,
        windSpeed: 0,
      );

      final headwind = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        windDir: 360,
        windSpeed: 10,
      );

      expect(headwind.groundRollFt!, lessThan(noWind.groundRollFt!));
      expect(headwind.totalDistanceFt!, lessThan(noWind.totalDistanceFt!));
    });

    test('tailwind increases distances', () {
      final noWind = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        windDir: 0,
        windSpeed: 0,
      );

      final tailwind = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        windDir: 180,
        windSpeed: 10,
      );

      expect(tailwind.groundRollFt!, greaterThan(noWind.groundRollFt!));
      expect(tailwind.totalDistanceFt!, greaterThan(noWind.totalDistanceFt!));
    });

    test('wet surface increases distances', () {
      final dry = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        surfaceType: 'paved_dry',
      );

      final wet = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        surfaceType: 'paved_wet',
      );

      expect(wet.groundRollFt!, greaterThan(dry.groundRollFt!));
      // Wet should be 15% more
      expect(
        wet.groundRollFt! / dry.groundRollFt!,
        closeTo(1.15, 0.01),
      );
    });

    test('grass surface increases distances more than paved wet', () {
      final pavedWet = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        surfaceType: 'paved_wet',
      );

      final grassDry = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        surfaceType: 'grass_dry',
      );

      expect(grassDry.groundRollFt!, greaterThan(pavedWet.groundRollFt!));
    });

    test('upslope increases distances (positive slope correction)', () {
      final flat = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        slopePercent: 0,
      );

      final upslope = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        slopePercent: 2,
      );

      expect(upslope.groundRollFt!, greaterThan(flat.groundRollFt!));
    });

    test('safety factor scales distances', () {
      final noSafety = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        safetyFactor: 1.0,
      );

      final withSafety = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        safetyFactor: 1.5,
      );

      expect(
        withSafety.groundRollFt! / noSafety.groundRollFt!,
        closeTo(1.5, 0.01),
      );
    });

    test('detects overweight condition', () {
      final result = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 8000,
        runwayHeading: 360,
        maxWeight: 7615,
      );

      expect(result.isOverweight, true);
    });

    test('not overweight when under max', () {
      final result = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        maxWeight: 7615,
      );

      expect(result.isOverweight, false);
    });

    test('detects exceeds runway condition', () {
      final result = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 7000,
        runwayHeading: 360,
        runwayAvailableFt: 100, // very short runway
      );

      expect(result.exceedsRunway, true);
    });

    test('does not exceed long runway', () {
      final result = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 5000,
        runwayHeading: 360,
        runwayAvailableFt: 50000,
      );

      expect(result.exceedsRunway, false);
    });

    test('pressure altitude is computed correctly in result', () {
      final result = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 5000,
        altimeterInHg: 28.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
      );

      expect(result.pressureAltitude, closeTo(6000, 0.01));
    });

    test('V-speeds are not affected by wind or surface', () {
      final base = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
      );

      final withFactors = ToldCalculator.calculate(
        flapSetting: flapSetting,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
        windDir: 360,
        windSpeed: 15,
        surfaceType: 'grass_wet',
        slopePercent: 2,
        safetyFactor: 1.5,
      );

      expect(withFactors.vrKias, closeTo(base.vrKias!, 0.01));
      expect(withFactors.v50Kias, closeTo(base.v50Kias!, 0.01));
    });

    test('returns result with null distances for empty table', () {
      final emptyFlap = FlapSetting(
        name: 'Empty',
        code: 'empty',
        table: const [],
      );

      final result = ToldCalculator.calculate(
        flapSetting: emptyFlap,
        fieldElevation: 0,
        altimeterInHg: 29.92,
        temperatureC: 20,
        weightLbs: 6000,
        runwayHeading: 360,
      );

      expect(result.groundRollFt, isNull);
      expect(result.totalDistanceFt, isNull);
      expect(result.vrKias, isNull);
      expect(result.v50Kias, isNull);
      expect(result.weight, 6000.0);
    });
  });

  group('PerformanceData.fromJson', () {
    test('parses valid JSON structure', () {
      final json = {
        'version': 1,
        'source': 'Test POH',
        'flap_settings': [
          {
            'name': 'TO',
            'code': 'to',
            'is_default': true,
            'table': [
              {
                'pressure_altitude': 0.0,
                'temperature_c': 0.0,
                'weight_lbs': 5000.0,
                'ground_roll_ft': 750.0,
                'total_distance_ft': 1100.0,
                'vr_kias': 76.0,
                'v50_kias': 91.0,
              }
            ],
            'wind_correction': {
              'headwind_factor_per_kt': -0.015,
              'tailwind_factor_per_kt': 0.035,
            },
            'surface_factors': {
              'paved_dry': 1.0,
              'paved_wet': 1.15,
            },
            'slope_correction_per_percent': 0.05,
          }
        ],
      };

      final data = PerformanceData.fromJson(json);
      expect(data.version, 1);
      expect(data.source, 'Test POH');
      expect(data.flapSettings, hasLength(1));

      final flap = data.flapSettings[0];
      expect(flap.name, 'TO');
      expect(flap.code, 'to');
      expect(flap.isDefault, true);
      expect(flap.table, hasLength(1));
      expect(flap.table[0].groundRollFt, 750.0);
      expect(flap.windCorrection.headwindFactorPerKt, -0.015);
      expect(flap.surfaceFactors['paved_wet'], 1.15);
      expect(flap.slopeCorrectionPerPercent, 0.05);
    });

    test('handles missing optional fields gracefully', () {
      final json = <String, dynamic>{
        'flap_settings': <dynamic>[],
      };

      final data = PerformanceData.fromJson(json);
      expect(data.version, 1);
      expect(data.source, isNull);
      expect(data.flapSettings, isEmpty);
    });
  });
}
