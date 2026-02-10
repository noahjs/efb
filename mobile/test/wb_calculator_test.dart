import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/services/wb_calculator.dart';
import 'package:efb_mobile/models/weight_balance.dart';

/// Tests for the client-side WBCalculator — mirrors the backend computeWB
/// logic for BEW → ZFW → Ramp → TOW → LDW chain and envelope checks.
void main() {
  // ─── Test fixture: Cessna 172-ish profile ───

  WBProfile makeProfile({
    double emptyWeight = 1663,
    double emptyWeightArm = 40.6,
    double taxiFuelGallons = 1.0,
    double? fuelArm = 48,
    double maxTakeoffWeight = 2550,
    double maxLandingWeight = 2550,
    double? maxRampWeight = 2558,
    double? maxZeroFuelWeight,
    bool lateralCgEnabled = false,
    List<WBStation>? stations,
    List<WBEnvelope>? envelopes,
  }) {
    final defaultStations = [
      WBStation(
        id: 1,
        name: 'Pilot & Front Pax',
        category: 'occupant',
        arm: 37,
        maxWeight: 400,
        sortOrder: 0,
      ),
      WBStation(
        id: 2,
        name: 'Rear Passengers',
        category: 'occupant',
        arm: 73,
        maxWeight: 400,
        sortOrder: 1,
      ),
      WBStation(
        id: 3,
        name: 'Baggage',
        category: 'baggage',
        arm: 95,
        maxWeight: 120,
        sortOrder: 2,
      ),
      WBStation(
        id: 4,
        name: 'Fuel',
        category: 'fuel',
        arm: 48,
        maxWeight: 318,
        sortOrder: 3,
      ),
    ];

    final defaultEnvelope = WBEnvelope(
      id: 1,
      envelopeType: 'normal',
      axis: 'longitudinal',
      points: [
        WBEnvelopePoint(cg: 35, weight: 1500),
        WBEnvelopePoint(cg: 47, weight: 1500),
        WBEnvelopePoint(cg: 47, weight: 2550),
        WBEnvelopePoint(cg: 35, weight: 2550),
      ],
    );

    return WBProfile(
      id: 1,
      aircraftId: 1,
      name: 'Test Profile',
      isDefault: true,
      lateralCgEnabled: lateralCgEnabled,
      emptyWeight: emptyWeight,
      emptyWeightArm: emptyWeightArm,
      emptyWeightMoment: emptyWeight * emptyWeightArm,
      maxRampWeight: maxRampWeight,
      maxTakeoffWeight: maxTakeoffWeight,
      maxLandingWeight: maxLandingWeight,
      maxZeroFuelWeight: maxZeroFuelWeight,
      fuelArm: fuelArm,
      taxiFuelGallons: taxiFuelGallons,
      stations: stations ?? defaultStations,
      envelopes: envelopes ?? [defaultEnvelope],
    );
  }

  group('WBCalculator.compute — weight chain', () {
    test('BEW → ZFW with payload', () {
      final result = WBCalculator.compute(
        profile: makeProfile(),
        stationLoads: [
          StationLoad(stationId: 1, weight: 170),
          StationLoad(stationId: 2, weight: 0),
          StationLoad(stationId: 3, weight: 30),
        ],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );

      // ZFW = BEW(1663) + pilot(170) + baggage(30) = 1863
      expect(result.zfw, closeTo(1863, 0.5));
    });

    test('Ramp weight = ZFW + starting fuel', () {
      final result = WBCalculator.compute(
        profile: makeProfile(),
        stationLoads: [StationLoad(stationId: 1, weight: 170)],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );

      // ZFW = 1663 + 170 = 1833
      // Ramp = 1833 + 40*6 = 2073
      expect(result.zfw, closeTo(1833, 0.5));
      expect(result.rampWeight, closeTo(2073, 0.5));
    });

    test('TOW = Ramp - taxi fuel', () {
      final result = WBCalculator.compute(
        profile: makeProfile(taxiFuelGallons: 1),
        stationLoads: [StationLoad(stationId: 1, weight: 170)],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );

      // TOW = 2073 - 1*6 = 2067
      expect(result.tow, closeTo(2067, 0.5));
    });

    test('LDW = ZFW + ending fuel', () {
      final result = WBCalculator.compute(
        profile: makeProfile(),
        stationLoads: [StationLoad(stationId: 1, weight: 170)],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );

      // LDW = 1833 + 20*6 = 1953
      expect(result.ldw, closeTo(1953, 0.5));
    });
  });

  group('WBCalculator.compute — CG computation', () {
    test('CG computed correctly at each phase', () {
      final result = WBCalculator.compute(
        profile: makeProfile(),
        stationLoads: [
          StationLoad(stationId: 1, weight: 170), // arm 37
          StationLoad(stationId: 2, weight: 150), // arm 73
          StationLoad(stationId: 3, weight: 30), // arm 95
        ],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );

      // BEW moment = 1663 * 40.6 = 67517.8
      // Payload moment = 170*37 + 150*73 + 30*95 = 20090
      // ZFW = 2013, ZFW CG ≈ 87607.8/2013 ≈ 43.52
      expect(result.zfwCg, closeTo(43.52, 0.5));
      // Ramp CG shifts toward fuel arm (48)
      expect(result.rampCg, greaterThan(result.zfwCg));
    });

    test('zero-weight station does not affect CG', () {
      final profile = makeProfile();
      final withZero = WBCalculator.compute(
        profile: profile,
        stationLoads: [
          StationLoad(stationId: 1, weight: 170),
          StationLoad(stationId: 2, weight: 0),
          StationLoad(stationId: 3, weight: 0),
        ],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );

      final withoutZero = WBCalculator.compute(
        profile: profile,
        stationLoads: [StationLoad(stationId: 1, weight: 170)],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );

      expect(withZero.zfwCg, closeTo(withoutZero.zfwCg, 0.01));
      expect(withZero.rampCg, closeTo(withoutZero.rampCg, 0.01));
    });
  });

  group('WBCalculator.compute — envelope checks', () {
    test('within envelope when all CGs and weights are in bounds', () {
      final result = WBCalculator.compute(
        profile: makeProfile(),
        stationLoads: [StationLoad(stationId: 1, weight: 170)],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );

      expect(result.isWithinEnvelope, isTrue);
      expect(result.towCondition.withinLimits, isTrue);
      expect(result.ldwCondition.withinLimits, isTrue);
    });

    test('out of envelope when weight exceeds max_takeoff_weight', () {
      final result = WBCalculator.compute(
        profile: makeProfile(maxTakeoffWeight: 1900),
        stationLoads: [
          StationLoad(stationId: 1, weight: 200),
          StationLoad(stationId: 2, weight: 200),
        ],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 53,
        endingFuelGallons: 20,
      );

      expect(result.towCondition.withinLimits, isFalse);
      expect(result.isWithinEnvelope, isFalse);
    });

    test('uses profile fuelArm when no fuel stations exist', () {
      final result = WBCalculator.compute(
        profile: makeProfile(
          fuelArm: 48,
          stations: [
            WBStation(
              id: 1,
              name: 'Pilot',
              category: 'occupant',
              arm: 37,
              maxWeight: 400,
              sortOrder: 0,
            ),
          ],
        ),
        stationLoads: [StationLoad(stationId: 1, weight: 170)],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );

      expect(result.rampWeight, greaterThan(result.zfw));
      expect(result.rampCg, greaterThan(0));
    });
  });

  group('WBCalculator._pointInPolygon', () {
    // Access private method via a compute call that exercises it,
    // or test indirectly through envelope results
    test('point inside envelope → within limits', () {
      final result = WBCalculator.compute(
        profile: makeProfile(),
        stationLoads: [StationLoad(stationId: 1, weight: 170)],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );
      // All CGs ~40, weights ~1800-2100 → inside 35-47/1500-2550 box
      expect(result.isWithinEnvelope, isTrue);
    });

    test('point outside envelope → not within limits', () {
      // Tiny envelope that excludes normal CG range
      final result = WBCalculator.compute(
        profile: makeProfile(
          envelopes: [
            WBEnvelope(
              id: 1,
              envelopeType: 'normal',
              axis: 'longitudinal',
              points: [
                WBEnvelopePoint(cg: 35, weight: 1500),
                WBEnvelopePoint(cg: 36, weight: 1500),
                WBEnvelopePoint(cg: 36, weight: 1600),
                WBEnvelopePoint(cg: 35, weight: 1600),
              ],
            ),
          ],
        ),
        stationLoads: [StationLoad(stationId: 1, weight: 170)],
        fuelWeightPerGallon: 6.0,
        startingFuelGallons: 40,
        endingFuelGallons: 20,
      );
      expect(result.isWithinEnvelope, isFalse);
    });
  });
}
