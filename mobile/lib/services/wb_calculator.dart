import '../models/weight_balance.dart';

/// Client-side W&B calculator — mirrors the backend computeWB algorithm
/// for real-time UI feedback without network round-trips.
class WBCalculator {
  static WBCalculationResult compute({
    required WBProfile profile,
    required List<StationLoad> stationLoads,
    required double fuelWeightPerGallon,
    double startingFuelGallons = 0,
    double endingFuelGallons = 0,
  }) {
    final stations = profile.stations;
    final loadMap = <int, double>{};
    for (final load in stationLoads) {
      loadMap[load.stationId] = load.weight;
    }

    // 1. Start with BEW
    double bewWeight = profile.emptyWeight;
    double bewLongMoment = profile.emptyWeight * profile.emptyWeightArm;
    double bewLatMoment = profile.lateralCgEnabled
        ? profile.emptyWeight * (profile.emptyWeightLateralArm ?? 0)
        : 0;

    // 2. Add payload stations (non-fuel) → ZFW
    double payloadWeight = 0;
    double payloadLongMoment = 0;
    double payloadLatMoment = 0;
    for (final station in stations.where((s) => s.category != 'fuel')) {
      final weight = loadMap[station.id] ?? 0;
      if (weight > 0) {
        payloadWeight += weight;
        payloadLongMoment += weight * station.arm;
        if (profile.lateralCgEnabled) {
          payloadLatMoment += weight * (station.lateralArm ?? 0);
        }
      }
    }

    final zfw = bewWeight + payloadWeight;
    final zfwLongMoment = bewLongMoment + payloadLongMoment;
    final zfwLatMoment = bewLatMoment + payloadLatMoment;
    final zfwCg = zfw > 0 ? zfwLongMoment / zfw : 0.0;
    final zfwLatCg =
        profile.lateralCgEnabled && zfw > 0 ? zfwLatMoment / zfw : null;

    // 3. Compute fuel moment for a given gallons amount.
    //    Uses fuel stations if they exist (distributed proportionally by
    //    max_weight), otherwise falls back to profile.fuelArm.
    final fuelStations =
        stations.where((s) => s.category == 'fuel').toList();
    final totalMaxWeight =
        fuelStations.fold(0.0, (sum, s) => sum + (s.maxWeight ?? 0));

    List<double> _fuelProportions() {
      if (fuelStations.isEmpty) return [];
      if (totalMaxWeight > 0) {
        return fuelStations
            .map((s) => (s.maxWeight ?? 0) / totalMaxWeight)
            .toList();
      }
      final even = 1.0 / fuelStations.length;
      return List.filled(fuelStations.length, even);
    }

    final proportions = _fuelProportions();

    ({double weight, double longMoment, double latMoment}) fuelMoment(
        double gallons) {
      final fuelWeight = gallons * fuelWeightPerGallon;
      double longMom = 0;
      double latMom = 0;

      if (fuelStations.isNotEmpty) {
        // Use per-station arms
        for (int i = 0; i < fuelStations.length; i++) {
          final stationFuel = fuelWeight * proportions[i];
          longMom += stationFuel * fuelStations[i].arm;
          if (profile.lateralCgEnabled) {
            latMom += stationFuel * (fuelStations[i].lateralArm ?? 0);
          }
        }
      } else if (profile.fuelArm != null) {
        // Fallback: use profile-level fuel arm
        longMom = fuelWeight * profile.fuelArm!;
        if (profile.lateralCgEnabled) {
          latMom = fuelWeight * (profile.fuelLateralArm ?? 0);
        }
      }

      return (weight: fuelWeight, longMoment: longMom, latMoment: latMom);
    }

    // 4. Ramp weight = ZFW + starting fuel
    final startFuel = fuelMoment(startingFuelGallons);
    final rampWeight = zfw + startFuel.weight;
    final rampLongMoment = zfwLongMoment + startFuel.longMoment;
    final rampLatMoment = zfwLatMoment + startFuel.latMoment;
    final rampCg = rampWeight > 0 ? rampLongMoment / rampWeight : 0.0;
    final rampLatCg = profile.lateralCgEnabled && rampWeight > 0
        ? rampLatMoment / rampWeight
        : null;

    // 5. TOW = Ramp - taxi fuel
    final taxiFuel = fuelMoment(profile.taxiFuelGallons);
    final tow = rampWeight - taxiFuel.weight;
    final towLongMoment = rampLongMoment - taxiFuel.longMoment;
    final towLatMoment = rampLatMoment - taxiFuel.latMoment;
    final towCg = tow > 0 ? towLongMoment / tow : 0.0;
    final towLatCg = profile.lateralCgEnabled && tow > 0
        ? towLatMoment / tow
        : null;

    // 6. LDW = ZFW + ending fuel (computed from first principles, not subtraction)
    final endFuel = fuelMoment(endingFuelGallons);
    final ldw = zfw + endFuel.weight;
    final ldwLongMoment = zfwLongMoment + endFuel.longMoment;
    final ldwLatMoment = zfwLatMoment + endFuel.latMoment;
    final ldwCg = ldw > 0 ? ldwLongMoment / ldw : 0.0;
    final ldwLatCg = profile.lateralCgEnabled && ldw > 0
        ? ldwLatMoment / ldw
        : null;

    // Envelope checks
    final longEnvelopes =
        profile.envelopes.where((e) => e.axis == 'longitudinal').toList();
    final latEnvelopes =
        profile.envelopes.where((e) => e.axis == 'lateral').toList();

    bool checkLong(double cg, double weight) =>
        longEnvelopes.isEmpty ||
        longEnvelopes.any((env) => _pointInPolygon(cg, weight, env.points));

    bool checkLat(double? cg, double weight) {
      if (!profile.lateralCgEnabled || cg == null) return true;
      return latEnvelopes.isEmpty ||
          latEnvelopes.any((env) => _pointInPolygon(cg, weight, env.points));
    }

    bool checkWeightLimit(double weight, double? limit) =>
        limit == null || weight <= limit;

    final zfwOk = checkLong(zfwCg, zfw) &&
        checkLat(zfwLatCg, zfw) &&
        checkWeightLimit(zfw, profile.maxZeroFuelWeight);
    final rampOk = checkLong(rampCg, rampWeight) &&
        checkLat(rampLatCg, rampWeight) &&
        checkWeightLimit(
            rampWeight, profile.maxRampWeight ?? profile.maxTakeoffWeight);
    final towOk = checkLong(towCg, tow) &&
        checkLat(towLatCg, tow) &&
        checkWeightLimit(tow, profile.maxTakeoffWeight);
    final ldwOk = checkLong(ldwCg, ldw) &&
        checkLat(ldwLatCg, ldw) &&
        checkWeightLimit(ldw, profile.maxLandingWeight);

    final isWithinEnvelope = zfwOk && rampOk && towOk && ldwOk;

    return WBCalculationResult(
      zfw: _round1(zfw),
      zfwCg: _round2(zfwCg),
      zfwLateralCg: zfwLatCg != null ? _round2(zfwLatCg) : null,
      rampWeight: _round1(rampWeight),
      rampCg: _round2(rampCg),
      rampLateralCg: rampLatCg != null ? _round2(rampLatCg) : null,
      tow: _round1(tow),
      towCg: _round2(towCg),
      towLateralCg: towLatCg != null ? _round2(towLatCg) : null,
      ldw: _round1(ldw),
      ldwCg: _round2(ldwCg),
      ldwLateralCg: ldwLatCg != null ? _round2(ldwLatCg) : null,
      isWithinEnvelope: isWithinEnvelope,
      zfwCondition: WBCondition(
          weight: _round1(zfw), cg: _round2(zfwCg),
          lateralCg: zfwLatCg != null ? _round2(zfwLatCg) : null,
          withinLimits: zfwOk),
      rampCondition: WBCondition(
          weight: _round1(rampWeight), cg: _round2(rampCg),
          lateralCg: rampLatCg != null ? _round2(rampLatCg) : null,
          withinLimits: rampOk),
      towCondition: WBCondition(
          weight: _round1(tow), cg: _round2(towCg),
          lateralCg: towLatCg != null ? _round2(towLatCg) : null,
          withinLimits: towOk),
      ldwCondition: WBCondition(
          weight: _round1(ldw), cg: _round2(ldwCg),
          lateralCg: ldwLatCg != null ? _round2(ldwLatCg) : null,
          withinLimits: ldwOk),
    );
  }

  static double _round1(double v) => (v * 10).roundToDouble() / 10;
  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  /// Ray-casting point-in-polygon algorithm
  static bool _pointInPolygon(
      double x, double y, List<WBEnvelopePoint> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].cg, yi = polygon[i].weight;
      final xj = polygon[j].cg, yj = polygon[j].weight;

      final intersect =
          (yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi;
      if (intersect) inside = !inside;
    }
    return inside;
  }
}
