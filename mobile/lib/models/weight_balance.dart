class WBProfile {
  final int? id;
  final int? aircraftId;
  final String name;
  final bool isDefault;
  final String? datumDescription;
  final bool lateralCgEnabled;
  final double emptyWeight;
  final double emptyWeightArm;
  final double emptyWeightMoment;
  final double? emptyWeightLateralArm;
  final double? emptyWeightLateralMoment;
  final double? maxRampWeight;
  final double maxTakeoffWeight;
  final double maxLandingWeight;
  final double? maxZeroFuelWeight;
  final double? fuelArm;
  final double? fuelLateralArm;
  final double taxiFuelGallons;
  final String? notes;
  final List<WBStation> stations;
  final List<WBEnvelope> envelopes;
  final String? createdAt;
  final String? updatedAt;

  const WBProfile({
    this.id,
    this.aircraftId,
    this.name = '',
    this.isDefault = false,
    this.datumDescription,
    this.lateralCgEnabled = false,
    this.emptyWeight = 0,
    this.emptyWeightArm = 0,
    this.emptyWeightMoment = 0,
    this.emptyWeightLateralArm,
    this.emptyWeightLateralMoment,
    this.maxRampWeight,
    this.maxTakeoffWeight = 0,
    this.maxLandingWeight = 0,
    this.maxZeroFuelWeight,
    this.fuelArm,
    this.fuelLateralArm,
    this.taxiFuelGallons = 1.0,
    this.notes,
    this.stations = const [],
    this.envelopes = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory WBProfile.fromJson(Map<String, dynamic> json) {
    final stationsList = json['stations'] as List<dynamic>?;
    final envelopesList = json['envelopes'] as List<dynamic>?;

    return WBProfile(
      id: json['id'] as int?,
      aircraftId: json['aircraft_id'] as int?,
      name: (json['name'] as String?) ?? '',
      isDefault: (json['is_default'] as bool?) ?? false,
      datumDescription: json['datum_description'] as String?,
      lateralCgEnabled: (json['lateral_cg_enabled'] as bool?) ?? false,
      emptyWeight: (json['empty_weight'] as num?)?.toDouble() ?? 0,
      emptyWeightArm: (json['empty_weight_arm'] as num?)?.toDouble() ?? 0,
      emptyWeightMoment:
          (json['empty_weight_moment'] as num?)?.toDouble() ?? 0,
      emptyWeightLateralArm:
          (json['empty_weight_lateral_arm'] as num?)?.toDouble(),
      emptyWeightLateralMoment:
          (json['empty_weight_lateral_moment'] as num?)?.toDouble(),
      maxRampWeight: (json['max_ramp_weight'] as num?)?.toDouble(),
      maxTakeoffWeight:
          (json['max_takeoff_weight'] as num?)?.toDouble() ?? 0,
      maxLandingWeight:
          (json['max_landing_weight'] as num?)?.toDouble() ?? 0,
      maxZeroFuelWeight:
          (json['max_zero_fuel_weight'] as num?)?.toDouble(),
      fuelArm: (json['fuel_arm'] as num?)?.toDouble(),
      fuelLateralArm: (json['fuel_lateral_arm'] as num?)?.toDouble(),
      taxiFuelGallons:
          (json['taxi_fuel_gallons'] as num?)?.toDouble() ?? 1.0,
      notes: json['notes'] as String?,
      stations: stationsList
              ?.map((s) => WBStation.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      envelopes: envelopesList
              ?.map((e) => WBEnvelope.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'is_default': isDefault,
      'datum_description': datumDescription,
      'lateral_cg_enabled': lateralCgEnabled,
      'empty_weight': emptyWeight,
      'empty_weight_arm': emptyWeightArm,
      'empty_weight_moment': emptyWeightMoment,
      'empty_weight_lateral_arm': emptyWeightLateralArm,
      'empty_weight_lateral_moment': emptyWeightLateralMoment,
      'max_ramp_weight': maxRampWeight,
      'max_takeoff_weight': maxTakeoffWeight,
      'max_landing_weight': maxLandingWeight,
      'max_zero_fuel_weight': maxZeroFuelWeight,
      'fuel_arm': fuelArm,
      'fuel_lateral_arm': fuelLateralArm,
      'taxi_fuel_gallons': taxiFuelGallons,
      'notes': notes,
    };
  }

  WBProfile copyWith({
    int? id,
    int? aircraftId,
    String? name,
    bool? isDefault,
    String? datumDescription,
    bool? lateralCgEnabled,
    double? emptyWeight,
    double? emptyWeightArm,
    double? emptyWeightMoment,
    double? emptyWeightLateralArm,
    double? emptyWeightLateralMoment,
    double? maxRampWeight,
    double? maxTakeoffWeight,
    double? maxLandingWeight,
    double? maxZeroFuelWeight,
    double? fuelArm,
    double? fuelLateralArm,
    double? taxiFuelGallons,
    String? notes,
    List<WBStation>? stations,
    List<WBEnvelope>? envelopes,
  }) {
    return WBProfile(
      id: id ?? this.id,
      aircraftId: aircraftId ?? this.aircraftId,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      datumDescription: datumDescription ?? this.datumDescription,
      lateralCgEnabled: lateralCgEnabled ?? this.lateralCgEnabled,
      emptyWeight: emptyWeight ?? this.emptyWeight,
      emptyWeightArm: emptyWeightArm ?? this.emptyWeightArm,
      emptyWeightMoment: emptyWeightMoment ?? this.emptyWeightMoment,
      emptyWeightLateralArm:
          emptyWeightLateralArm ?? this.emptyWeightLateralArm,
      emptyWeightLateralMoment:
          emptyWeightLateralMoment ?? this.emptyWeightLateralMoment,
      maxRampWeight: maxRampWeight ?? this.maxRampWeight,
      maxTakeoffWeight: maxTakeoffWeight ?? this.maxTakeoffWeight,
      maxLandingWeight: maxLandingWeight ?? this.maxLandingWeight,
      maxZeroFuelWeight: maxZeroFuelWeight ?? this.maxZeroFuelWeight,
      fuelArm: fuelArm ?? this.fuelArm,
      fuelLateralArm: fuelLateralArm ?? this.fuelLateralArm,
      taxiFuelGallons: taxiFuelGallons ?? this.taxiFuelGallons,
      notes: notes ?? this.notes,
      stations: stations ?? this.stations,
      envelopes: envelopes ?? this.envelopes,
    );
  }
}

class WBStation {
  final int? id;
  final int? wbProfileId;
  final String name;
  final String category;
  final double arm;
  final double? lateralArm;
  final double? maxWeight;
  final double? defaultWeight;
  final int? fuelTankId;
  final int sortOrder;
  final String? groupName;

  const WBStation({
    this.id,
    this.wbProfileId,
    this.name = '',
    this.category = 'seat',
    this.arm = 0,
    this.lateralArm,
    this.maxWeight,
    this.defaultWeight,
    this.fuelTankId,
    this.sortOrder = 0,
    this.groupName,
  });

  factory WBStation.fromJson(Map<String, dynamic> json) {
    return WBStation(
      id: json['id'] as int?,
      wbProfileId: json['wb_profile_id'] as int?,
      name: (json['name'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'seat',
      arm: (json['arm'] as num?)?.toDouble() ?? 0,
      lateralArm: (json['lateral_arm'] as num?)?.toDouble(),
      maxWeight: (json['max_weight'] as num?)?.toDouble(),
      defaultWeight: (json['default_weight'] as num?)?.toDouble(),
      fuelTankId: json['fuel_tank_id'] as int?,
      sortOrder: (json['sort_order'] as int?) ?? 0,
      groupName: json['group_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'arm': arm,
      'lateral_arm': lateralArm,
      'max_weight': maxWeight,
      'default_weight': defaultWeight,
      'fuel_tank_id': fuelTankId,
      'sort_order': sortOrder,
      'group_name': groupName,
    };
  }

  WBStation copyWith({
    int? id,
    int? wbProfileId,
    String? name,
    String? category,
    double? arm,
    double? lateralArm,
    double? maxWeight,
    double? defaultWeight,
    int? fuelTankId,
    int? sortOrder,
    String? groupName,
  }) {
    return WBStation(
      id: id ?? this.id,
      wbProfileId: wbProfileId ?? this.wbProfileId,
      name: name ?? this.name,
      category: category ?? this.category,
      arm: arm ?? this.arm,
      lateralArm: lateralArm ?? this.lateralArm,
      maxWeight: maxWeight ?? this.maxWeight,
      defaultWeight: defaultWeight ?? this.defaultWeight,
      fuelTankId: fuelTankId ?? this.fuelTankId,
      sortOrder: sortOrder ?? this.sortOrder,
      groupName: groupName ?? this.groupName,
    );
  }
}

class WBEnvelopePoint {
  final double weight;
  final double cg;

  const WBEnvelopePoint({required this.weight, required this.cg});

  factory WBEnvelopePoint.fromJson(Map<String, dynamic> json) {
    return WBEnvelopePoint(
      weight: (json['weight'] as num).toDouble(),
      cg: (json['cg'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'weight': weight, 'cg': cg};
}

class WBEnvelope {
  final int? id;
  final int? wbProfileId;
  final String envelopeType;
  final String axis;
  final List<WBEnvelopePoint> points;

  const WBEnvelope({
    this.id,
    this.wbProfileId,
    this.envelopeType = 'normal',
    this.axis = 'longitudinal',
    this.points = const [],
  });

  factory WBEnvelope.fromJson(Map<String, dynamic> json) {
    final pointsList = json['points'] as List<dynamic>?;
    return WBEnvelope(
      id: json['id'] as int?,
      wbProfileId: json['wb_profile_id'] as int?,
      envelopeType: (json['envelope_type'] as String?) ?? 'normal',
      axis: (json['axis'] as String?) ?? 'longitudinal',
      points: pointsList
              ?.map(
                  (p) => WBEnvelopePoint.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'envelope_type': envelopeType,
      'axis': axis,
      'points': points.map((p) => p.toJson()).toList(),
    };
  }
}

class WBScenario {
  final int? id;
  final int? wbProfileId;
  final int? flightId;
  final String name;
  final List<StationLoad> stationLoads;
  final double? startingFuelGallons;
  final double? endingFuelGallons;
  final double computedZfw;
  final double computedZfwCg;
  final double? computedZfwLateralCg;
  final double computedRampWeight;
  final double computedRampCg;
  final double? computedRampLateralCg;
  final double computedTow;
  final double computedTowCg;
  final double? computedTowLateralCg;
  final double computedLdw;
  final double computedLdwCg;
  final double? computedLdwLateralCg;
  final bool isWithinEnvelope;
  final String? createdAt;
  final String? updatedAt;

  const WBScenario({
    this.id,
    this.wbProfileId,
    this.flightId,
    this.name = '',
    this.stationLoads = const [],
    this.startingFuelGallons,
    this.endingFuelGallons,
    this.computedZfw = 0,
    this.computedZfwCg = 0,
    this.computedZfwLateralCg,
    this.computedRampWeight = 0,
    this.computedRampCg = 0,
    this.computedRampLateralCg,
    this.computedTow = 0,
    this.computedTowCg = 0,
    this.computedTowLateralCg,
    this.computedLdw = 0,
    this.computedLdwCg = 0,
    this.computedLdwLateralCg,
    this.isWithinEnvelope = true,
    this.createdAt,
    this.updatedAt,
  });

  factory WBScenario.fromJson(Map<String, dynamic> json) {
    final loadsList = json['station_loads'] as List<dynamic>?;
    return WBScenario(
      id: json['id'] as int?,
      wbProfileId: json['wb_profile_id'] as int?,
      flightId: json['flight_id'] as int?,
      name: (json['name'] as String?) ?? '',
      stationLoads: loadsList
              ?.map((l) => StationLoad.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      startingFuelGallons:
          (json['starting_fuel_gallons'] as num?)?.toDouble(),
      endingFuelGallons:
          (json['ending_fuel_gallons'] as num?)?.toDouble(),
      computedZfw: (json['computed_zfw'] as num?)?.toDouble() ?? 0,
      computedZfwCg: (json['computed_zfw_cg'] as num?)?.toDouble() ?? 0,
      computedZfwLateralCg:
          (json['computed_zfw_lateral_cg'] as num?)?.toDouble(),
      computedRampWeight:
          (json['computed_ramp_weight'] as num?)?.toDouble() ?? 0,
      computedRampCg: (json['computed_ramp_cg'] as num?)?.toDouble() ?? 0,
      computedRampLateralCg:
          (json['computed_ramp_lateral_cg'] as num?)?.toDouble(),
      computedTow: (json['computed_tow'] as num?)?.toDouble() ?? 0,
      computedTowCg: (json['computed_tow_cg'] as num?)?.toDouble() ?? 0,
      computedTowLateralCg:
          (json['computed_tow_lateral_cg'] as num?)?.toDouble(),
      computedLdw: (json['computed_ldw'] as num?)?.toDouble() ?? 0,
      computedLdwCg: (json['computed_ldw_cg'] as num?)?.toDouble() ?? 0,
      computedLdwLateralCg:
          (json['computed_ldw_lateral_cg'] as num?)?.toDouble(),
      isWithinEnvelope:
          (json['is_within_envelope'] as bool?) ?? true,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'station_loads': stationLoads.map((l) => l.toJson()).toList(),
      if (startingFuelGallons != null)
        'starting_fuel_gallons': startingFuelGallons,
      if (endingFuelGallons != null) 'ending_fuel_gallons': endingFuelGallons,
      if (flightId != null) 'flight_id': flightId,
    };
  }

  WBScenario copyWith({
    int? id,
    int? wbProfileId,
    int? flightId,
    String? name,
    List<StationLoad>? stationLoads,
    double? startingFuelGallons,
    double? endingFuelGallons,
  }) {
    return WBScenario(
      id: id ?? this.id,
      wbProfileId: wbProfileId ?? this.wbProfileId,
      flightId: flightId ?? this.flightId,
      name: name ?? this.name,
      stationLoads: stationLoads ?? this.stationLoads,
      startingFuelGallons: startingFuelGallons ?? this.startingFuelGallons,
      endingFuelGallons: endingFuelGallons ?? this.endingFuelGallons,
      computedZfw: computedZfw,
      computedZfwCg: computedZfwCg,
      computedZfwLateralCg: computedZfwLateralCg,
      computedRampWeight: computedRampWeight,
      computedRampCg: computedRampCg,
      computedRampLateralCg: computedRampLateralCg,
      computedTow: computedTow,
      computedTowCg: computedTowCg,
      computedTowLateralCg: computedTowLateralCg,
      computedLdw: computedLdw,
      computedLdwCg: computedLdwCg,
      computedLdwLateralCg: computedLdwLateralCg,
      isWithinEnvelope: isWithinEnvelope,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class StationLoad {
  final int stationId;
  final double weight;
  final String? occupantName;
  final bool? isPerson;

  const StationLoad({
    required this.stationId,
    this.weight = 0,
    this.occupantName,
    this.isPerson,
  });

  factory StationLoad.fromJson(Map<String, dynamic> json) {
    return StationLoad(
      stationId: json['station_id'] as int,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      occupantName: json['occupant_name'] as String?,
      isPerson: json['is_person'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'station_id': stationId,
      'weight': weight,
      if (occupantName != null) 'occupant_name': occupantName,
      if (isPerson != null) 'is_person': isPerson,
    };
  }

  StationLoad copyWith({
    int? stationId,
    double? weight,
    String? occupantName,
    bool? isPerson,
  }) {
    return StationLoad(
      stationId: stationId ?? this.stationId,
      weight: weight ?? this.weight,
      occupantName: occupantName ?? this.occupantName,
      isPerson: isPerson ?? this.isPerson,
    );
  }
}

class WBCalculationResult {
  final double zfw;
  final double zfwCg;
  final double? zfwLateralCg;
  final double rampWeight;
  final double rampCg;
  final double? rampLateralCg;
  final double tow;
  final double towCg;
  final double? towLateralCg;
  final double ldw;
  final double ldwCg;
  final double? ldwLateralCg;
  final bool isWithinEnvelope;
  final WBCondition zfwCondition;
  final WBCondition rampCondition;
  final WBCondition towCondition;
  final WBCondition ldwCondition;

  const WBCalculationResult({
    this.zfw = 0,
    this.zfwCg = 0,
    this.zfwLateralCg,
    this.rampWeight = 0,
    this.rampCg = 0,
    this.rampLateralCg,
    this.tow = 0,
    this.towCg = 0,
    this.towLateralCg,
    this.ldw = 0,
    this.ldwCg = 0,
    this.ldwLateralCg,
    this.isWithinEnvelope = true,
    this.zfwCondition = const WBCondition(),
    this.rampCondition = const WBCondition(),
    this.towCondition = const WBCondition(),
    this.ldwCondition = const WBCondition(),
  });

  factory WBCalculationResult.fromJson(Map<String, dynamic> json) {
    final conditions =
        json['conditions'] as Map<String, dynamic>? ?? {};
    return WBCalculationResult(
      zfw: (json['computed_zfw'] as num?)?.toDouble() ?? 0,
      zfwCg: (json['computed_zfw_cg'] as num?)?.toDouble() ?? 0,
      zfwLateralCg: (json['computed_zfw_lateral_cg'] as num?)?.toDouble(),
      rampWeight: (json['computed_ramp_weight'] as num?)?.toDouble() ?? 0,
      rampCg: (json['computed_ramp_cg'] as num?)?.toDouble() ?? 0,
      rampLateralCg:
          (json['computed_ramp_lateral_cg'] as num?)?.toDouble(),
      tow: (json['computed_tow'] as num?)?.toDouble() ?? 0,
      towCg: (json['computed_tow_cg'] as num?)?.toDouble() ?? 0,
      towLateralCg: (json['computed_tow_lateral_cg'] as num?)?.toDouble(),
      ldw: (json['computed_ldw'] as num?)?.toDouble() ?? 0,
      ldwCg: (json['computed_ldw_cg'] as num?)?.toDouble() ?? 0,
      ldwLateralCg: (json['computed_ldw_lateral_cg'] as num?)?.toDouble(),
      isWithinEnvelope: (json['is_within_envelope'] as bool?) ?? true,
      zfwCondition: conditions['zfw'] != null
          ? WBCondition.fromJson(conditions['zfw'])
          : const WBCondition(),
      rampCondition: conditions['ramp'] != null
          ? WBCondition.fromJson(conditions['ramp'])
          : const WBCondition(),
      towCondition: conditions['tow'] != null
          ? WBCondition.fromJson(conditions['tow'])
          : const WBCondition(),
      ldwCondition: conditions['ldw'] != null
          ? WBCondition.fromJson(conditions['ldw'])
          : const WBCondition(),
    );
  }
}

class WBCondition {
  final double weight;
  final double cg;
  final double? lateralCg;
  final bool withinLimits;

  const WBCondition({
    this.weight = 0,
    this.cg = 0,
    this.lateralCg,
    this.withinLimits = true,
  });

  factory WBCondition.fromJson(Map<String, dynamic> json) {
    return WBCondition(
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      cg: (json['cg'] as num?)?.toDouble() ?? 0,
      lateralCg: (json['lateral_cg'] as num?)?.toDouble(),
      withinLimits: (json['within_limits'] as bool?) ?? true,
    );
  }
}
