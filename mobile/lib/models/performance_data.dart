class PerformanceData {
  final int version;
  final String? source;
  final List<FlapSetting> flapSettings;

  const PerformanceData({
    this.version = 1,
    this.source,
    this.flapSettings = const [],
  });

  factory PerformanceData.fromJson(Map<String, dynamic> json) {
    return PerformanceData(
      version: (json['version'] as int?) ?? 1,
      source: json['source'] as String?,
      flapSettings: (json['flap_settings'] as List<dynamic>?)
              ?.map((e) => FlapSetting.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class FlapSetting {
  final String name;
  final String code;
  final bool isDefault;
  final List<PerformanceDataPoint> table;
  final WindCorrection windCorrection;
  final Map<String, double> surfaceFactors;
  final double slopeCorrectionPerPercent;

  const FlapSetting({
    required this.name,
    required this.code,
    this.isDefault = false,
    this.table = const [],
    this.windCorrection = const WindCorrection(),
    this.surfaceFactors = const {},
    this.slopeCorrectionPerPercent = 0.0,
  });

  factory FlapSetting.fromJson(Map<String, dynamic> json) {
    final surfMap = <String, double>{};
    final rawSurf = json['surface_factors'] as Map<String, dynamic>?;
    if (rawSurf != null) {
      for (final e in rawSurf.entries) {
        surfMap[e.key] = (e.value as num).toDouble();
      }
    }

    return FlapSetting(
      name: (json['name'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      isDefault: (json['is_default'] as bool?) ?? false,
      table: (json['table'] as List<dynamic>?)
              ?.map((e) =>
                  PerformanceDataPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      windCorrection: json['wind_correction'] != null
          ? WindCorrection.fromJson(
              json['wind_correction'] as Map<String, dynamic>)
          : const WindCorrection(),
      surfaceFactors: surfMap,
      slopeCorrectionPerPercent:
          (json['slope_correction_per_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PerformanceDataPoint {
  final double pressureAltitude;
  final double temperatureC;
  final double weightLbs;
  final double groundRollFt;
  final double totalDistanceFt;
  final double vrKias;
  final double v50Kias;

  const PerformanceDataPoint({
    required this.pressureAltitude,
    required this.temperatureC,
    required this.weightLbs,
    required this.groundRollFt,
    required this.totalDistanceFt,
    required this.vrKias,
    required this.v50Kias,
  });

  factory PerformanceDataPoint.fromJson(Map<String, dynamic> json) {
    return PerformanceDataPoint(
      pressureAltitude: (json['pressure_altitude'] as num).toDouble(),
      temperatureC: (json['temperature_c'] as num).toDouble(),
      weightLbs: (json['weight_lbs'] as num).toDouble(),
      groundRollFt: (json['ground_roll_ft'] as num).toDouble(),
      totalDistanceFt: (json['total_distance_ft'] as num).toDouble(),
      vrKias: (json['vr_kias'] as num).toDouble(),
      v50Kias: (json['v50_kias'] as num).toDouble(),
    );
  }
}

class WindCorrection {
  final double headwindFactorPerKt;
  final double tailwindFactorPerKt;

  const WindCorrection({
    this.headwindFactorPerKt = -0.015,
    this.tailwindFactorPerKt = 0.035,
  });

  factory WindCorrection.fromJson(Map<String, dynamic> json) {
    return WindCorrection(
      headwindFactorPerKt:
          (json['headwind_factor_per_kt'] as num?)?.toDouble() ?? -0.015,
      tailwindFactorPerKt:
          (json['tailwind_factor_per_kt'] as num?)?.toDouble() ?? 0.035,
    );
  }
}
