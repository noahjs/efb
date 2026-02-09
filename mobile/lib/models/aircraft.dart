import 'dart:convert';

Map<String, dynamic>? _parseJsonField(dynamic val) {
  if (val is Map<String, dynamic>) return val;
  if (val is String && val.isNotEmpty) {
    try {
      return Map<String, dynamic>.from(jsonDecode(val));
    } catch (_) {
      return null;
    }
  }
  return null;
}

class PerformanceProfile {
  final int? id;
  final int? aircraftId;
  final String name;
  final bool isDefault;
  final double? cruiseTas;
  final double? cruiseFuelBurn;
  final double? climbRate;
  final double? climbSpeed;
  final double? climbFuelFlow;
  final double? descentRate;
  final double? descentSpeed;
  final double? descentFuelFlow;
  final Map<String, dynamic>? takeoffData;
  final Map<String, dynamic>? landingData;
  final String? createdAt;
  final String? updatedAt;

  const PerformanceProfile({
    this.id,
    this.aircraftId,
    this.name = '',
    this.isDefault = false,
    this.cruiseTas,
    this.cruiseFuelBurn,
    this.climbRate,
    this.climbSpeed,
    this.climbFuelFlow,
    this.descentRate,
    this.descentSpeed,
    this.descentFuelFlow,
    this.takeoffData,
    this.landingData,
    this.createdAt,
    this.updatedAt,
  });

  factory PerformanceProfile.fromJson(Map<String, dynamic> json) {
    return PerformanceProfile(
      id: json['id'] as int?,
      aircraftId: json['aircraft_id'] as int?,
      name: (json['name'] as String?) ?? '',
      isDefault: (json['is_default'] as bool?) ?? false,
      cruiseTas: (json['cruise_tas'] as num?)?.toDouble(),
      cruiseFuelBurn: (json['cruise_fuel_burn'] as num?)?.toDouble(),
      climbRate: (json['climb_rate'] as num?)?.toDouble(),
      climbSpeed: (json['climb_speed'] as num?)?.toDouble(),
      climbFuelFlow: (json['climb_fuel_flow'] as num?)?.toDouble(),
      descentRate: (json['descent_rate'] as num?)?.toDouble(),
      descentSpeed: (json['descent_speed'] as num?)?.toDouble(),
      descentFuelFlow: (json['descent_fuel_flow'] as num?)?.toDouble(),
      takeoffData: _parseJsonField(json['takeoff_data']),
      landingData: _parseJsonField(json['landing_data']),
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'is_default': isDefault,
      'cruise_tas': cruiseTas,
      'cruise_fuel_burn': cruiseFuelBurn,
      'climb_rate': climbRate,
      'climb_speed': climbSpeed,
      'climb_fuel_flow': climbFuelFlow,
      'descent_rate': descentRate,
      'descent_speed': descentSpeed,
      'descent_fuel_flow': descentFuelFlow,
      if (takeoffData != null) 'takeoff_data': jsonEncode(takeoffData),
      if (landingData != null) 'landing_data': jsonEncode(landingData),
    };
  }

  PerformanceProfile copyWith({
    int? id,
    int? aircraftId,
    String? name,
    bool? isDefault,
    double? cruiseTas,
    double? cruiseFuelBurn,
    double? climbRate,
    double? climbSpeed,
    double? climbFuelFlow,
    double? descentRate,
    double? descentSpeed,
    double? descentFuelFlow,
    Map<String, dynamic>? takeoffData,
    Map<String, dynamic>? landingData,
  }) {
    return PerformanceProfile(
      id: id ?? this.id,
      aircraftId: aircraftId ?? this.aircraftId,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      cruiseTas: cruiseTas ?? this.cruiseTas,
      cruiseFuelBurn: cruiseFuelBurn ?? this.cruiseFuelBurn,
      climbRate: climbRate ?? this.climbRate,
      climbSpeed: climbSpeed ?? this.climbSpeed,
      climbFuelFlow: climbFuelFlow ?? this.climbFuelFlow,
      descentRate: descentRate ?? this.descentRate,
      descentSpeed: descentSpeed ?? this.descentSpeed,
      descentFuelFlow: descentFuelFlow ?? this.descentFuelFlow,
      takeoffData: takeoffData ?? this.takeoffData,
      landingData: landingData ?? this.landingData,
    );
  }
}

class FuelTank {
  final int? id;
  final int? aircraftId;
  final String name;
  final double capacityGallons;
  final double? tabFuelGallons;
  final int sortOrder;

  const FuelTank({
    this.id,
    this.aircraftId,
    this.name = '',
    this.capacityGallons = 0,
    this.tabFuelGallons,
    this.sortOrder = 0,
  });

  factory FuelTank.fromJson(Map<String, dynamic> json) {
    return FuelTank(
      id: json['id'] as int?,
      aircraftId: json['aircraft_id'] as int?,
      name: (json['name'] as String?) ?? '',
      capacityGallons: (json['capacity_gallons'] as num?)?.toDouble() ?? 0,
      tabFuelGallons: (json['tab_fuel_gallons'] as num?)?.toDouble(),
      sortOrder: (json['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'capacity_gallons': capacityGallons,
      'tab_fuel_gallons': tabFuelGallons,
      'sort_order': sortOrder,
    };
  }

  FuelTank copyWith({
    int? id,
    int? aircraftId,
    String? name,
    double? capacityGallons,
    double? tabFuelGallons,
    int? sortOrder,
  }) {
    return FuelTank(
      id: id ?? this.id,
      aircraftId: aircraftId ?? this.aircraftId,
      name: name ?? this.name,
      capacityGallons: capacityGallons ?? this.capacityGallons,
      tabFuelGallons: tabFuelGallons ?? this.tabFuelGallons,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class AircraftEquipment {
  final int? id;
  final int? aircraftId;
  final String? gpsType;
  final String? transponderType;
  final String? adsbCompliance;
  final String? equipmentCodes;
  final String? installedAvionics;

  const AircraftEquipment({
    this.id,
    this.aircraftId,
    this.gpsType,
    this.transponderType,
    this.adsbCompliance,
    this.equipmentCodes,
    this.installedAvionics,
  });

  factory AircraftEquipment.fromJson(Map<String, dynamic> json) {
    return AircraftEquipment(
      id: json['id'] as int?,
      aircraftId: json['aircraft_id'] as int?,
      gpsType: json['gps_type'] as String?,
      transponderType: json['transponder_type'] as String?,
      adsbCompliance: json['adsb_compliance'] as String?,
      equipmentCodes: json['equipment_codes'] as String?,
      installedAvionics: json['installed_avionics'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gps_type': gpsType,
      'transponder_type': transponderType,
      'adsb_compliance': adsbCompliance,
      'equipment_codes': equipmentCodes,
      'installed_avionics': installedAvionics,
    };
  }

  AircraftEquipment copyWith({
    int? id,
    int? aircraftId,
    String? gpsType,
    String? transponderType,
    String? adsbCompliance,
    String? equipmentCodes,
    String? installedAvionics,
  }) {
    return AircraftEquipment(
      id: id ?? this.id,
      aircraftId: aircraftId ?? this.aircraftId,
      gpsType: gpsType ?? this.gpsType,
      transponderType: transponderType ?? this.transponderType,
      adsbCompliance: adsbCompliance ?? this.adsbCompliance,
      equipmentCodes: equipmentCodes ?? this.equipmentCodes,
      installedAvionics: installedAvionics ?? this.installedAvionics,
    );
  }
}

class Aircraft {
  final int? id;
  final String tailNumber;
  final String? callSign;
  final String? serialNumber;
  final String aircraftType;
  final String? icaoTypeCode;
  final String category;
  final String? color;
  final String? homeAirport;
  final String airspeedUnits;
  final String lengthUnits;
  final String? ownershipStatus;
  final String fuelType;
  final double? totalUsableFuel;
  final double? bestGlideSpeed;
  final double? glideRatio;
  final double? emptyWeight;
  final double? maxTakeoffWeight;
  final double? maxLandingWeight;
  final double? fuelWeightPerGallon;
  final bool isDefault;
  final String? createdAt;
  final String? updatedAt;
  final List<PerformanceProfile> performanceProfiles;
  final List<FuelTank> fuelTanks;
  final AircraftEquipment? equipment;

  const Aircraft({
    this.id,
    this.tailNumber = '',
    this.callSign,
    this.serialNumber,
    this.aircraftType = '',
    this.icaoTypeCode,
    this.category = 'landplane',
    this.color,
    this.homeAirport,
    this.airspeedUnits = 'knots',
    this.lengthUnits = 'inches',
    this.ownershipStatus,
    this.fuelType = 'jet_a',
    this.totalUsableFuel,
    this.bestGlideSpeed,
    this.glideRatio,
    this.emptyWeight,
    this.maxTakeoffWeight,
    this.maxLandingWeight,
    this.fuelWeightPerGallon,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
    this.performanceProfiles = const [],
    this.fuelTanks = const [],
    this.equipment,
  });

  PerformanceProfile? get defaultProfile {
    try {
      return performanceProfiles.firstWhere((p) => p.isDefault);
    } catch (_) {
      return performanceProfiles.isNotEmpty ? performanceProfiles.first : null;
    }
  }

  factory Aircraft.fromJson(Map<String, dynamic> json) {
    final profilesList = json['performance_profiles'] as List<dynamic>?;
    final tanksList = json['fuel_tanks'] as List<dynamic>?;
    final equipJson = json['equipment'] as Map<String, dynamic>?;

    return Aircraft(
      id: json['id'] as int?,
      tailNumber: (json['tail_number'] as String?) ?? '',
      callSign: json['call_sign'] as String?,
      serialNumber: json['serial_number'] as String?,
      aircraftType: (json['aircraft_type'] as String?) ?? '',
      icaoTypeCode: json['icao_type_code'] as String?,
      category: (json['category'] as String?) ?? 'landplane',
      color: json['color'] as String?,
      homeAirport: json['home_airport'] as String?,
      airspeedUnits: (json['airspeed_units'] as String?) ?? 'knots',
      lengthUnits: (json['length_units'] as String?) ?? 'inches',
      ownershipStatus: json['ownership_status'] as String?,
      fuelType: (json['fuel_type'] as String?) ?? 'jet_a',
      totalUsableFuel: (json['total_usable_fuel'] as num?)?.toDouble(),
      bestGlideSpeed: (json['best_glide_speed'] as num?)?.toDouble(),
      glideRatio: (json['glide_ratio'] as num?)?.toDouble(),
      emptyWeight: (json['empty_weight'] as num?)?.toDouble(),
      maxTakeoffWeight: (json['max_takeoff_weight'] as num?)?.toDouble(),
      maxLandingWeight: (json['max_landing_weight'] as num?)?.toDouble(),
      fuelWeightPerGallon:
          (json['fuel_weight_per_gallon'] as num?)?.toDouble(),
      isDefault: (json['is_default'] as bool?) ?? false,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      performanceProfiles: profilesList
              ?.map((p) =>
                  PerformanceProfile.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      fuelTanks: tanksList
              ?.map((t) => FuelTank.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      equipment:
          equipJson != null ? AircraftEquipment.fromJson(equipJson) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tail_number': tailNumber,
      'call_sign': callSign,
      'serial_number': serialNumber,
      'aircraft_type': aircraftType,
      'icao_type_code': icaoTypeCode,
      'category': category,
      'color': color,
      'home_airport': homeAirport,
      'airspeed_units': airspeedUnits,
      'length_units': lengthUnits,
      'ownership_status': ownershipStatus,
      'fuel_type': fuelType,
      'total_usable_fuel': totalUsableFuel,
      'best_glide_speed': bestGlideSpeed,
      'glide_ratio': glideRatio,
      'empty_weight': emptyWeight,
      'max_takeoff_weight': maxTakeoffWeight,
      'max_landing_weight': maxLandingWeight,
      'fuel_weight_per_gallon': fuelWeightPerGallon,
      'is_default': isDefault,
    };
  }

  Aircraft copyWith({
    int? id,
    String? tailNumber,
    String? callSign,
    String? serialNumber,
    String? aircraftType,
    String? icaoTypeCode,
    String? category,
    String? color,
    String? homeAirport,
    String? airspeedUnits,
    String? lengthUnits,
    String? ownershipStatus,
    String? fuelType,
    double? totalUsableFuel,
    double? bestGlideSpeed,
    double? glideRatio,
    double? emptyWeight,
    double? maxTakeoffWeight,
    double? maxLandingWeight,
    double? fuelWeightPerGallon,
    bool? isDefault,
    List<PerformanceProfile>? performanceProfiles,
    List<FuelTank>? fuelTanks,
    AircraftEquipment? equipment,
  }) {
    return Aircraft(
      id: id ?? this.id,
      tailNumber: tailNumber ?? this.tailNumber,
      callSign: callSign ?? this.callSign,
      serialNumber: serialNumber ?? this.serialNumber,
      aircraftType: aircraftType ?? this.aircraftType,
      icaoTypeCode: icaoTypeCode ?? this.icaoTypeCode,
      category: category ?? this.category,
      color: color ?? this.color,
      homeAirport: homeAirport ?? this.homeAirport,
      airspeedUnits: airspeedUnits ?? this.airspeedUnits,
      lengthUnits: lengthUnits ?? this.lengthUnits,
      ownershipStatus: ownershipStatus ?? this.ownershipStatus,
      fuelType: fuelType ?? this.fuelType,
      totalUsableFuel: totalUsableFuel ?? this.totalUsableFuel,
      bestGlideSpeed: bestGlideSpeed ?? this.bestGlideSpeed,
      glideRatio: glideRatio ?? this.glideRatio,
      emptyWeight: emptyWeight ?? this.emptyWeight,
      maxTakeoffWeight: maxTakeoffWeight ?? this.maxTakeoffWeight,
      maxLandingWeight: maxLandingWeight ?? this.maxLandingWeight,
      fuelWeightPerGallon: fuelWeightPerGallon ?? this.fuelWeightPerGallon,
      isDefault: isDefault ?? this.isDefault,
      performanceProfiles: performanceProfiles ?? this.performanceProfiles,
      fuelTanks: fuelTanks ?? this.fuelTanks,
      equipment: equipment ?? this.equipment,
    );
  }
}
