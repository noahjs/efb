class Flight {
  final int? id;
  final int? aircraftId;
  final int? performanceProfileId;
  final String? departureIdentifier;
  final String? destinationIdentifier;
  final String? alternateIdentifier;
  final String? etd;
  final String? aircraftIdentifier;
  final String? aircraftType;
  final String? performanceProfile;
  final int? trueAirspeed;
  final String flightRules;
  final String? routeString;
  final int? cruiseAltitude;
  final int peopleCount;
  final double avgPersonWeight;
  final double cargoWeight;
  final String? fuelPolicy;
  final double? startFuelGallons;
  final double? reserveFuelGallons;
  final double? fuelBurnRate;
  final double fuelAtShutdownGallons;
  final String filingStatus;
  final String? filingReference;
  final String? filingVersionStamp;
  final String? filedAt;
  final String? filingFormat;
  final double? enduranceHours;
  final String? remarks;
  final double? distanceNm;
  final int? eteMinutes;
  final double? flightFuelGallons;
  final double? windComponent;
  final String? eta;
  final String? calculatedAt;
  final int? arrivalFboId;
  final String? arrivalFboName;
  final String? createdAt;
  final String? updatedAt;

  const Flight({
    this.id,
    this.aircraftId,
    this.performanceProfileId,
    this.departureIdentifier,
    this.destinationIdentifier,
    this.alternateIdentifier,
    this.etd,
    this.aircraftIdentifier,
    this.aircraftType,
    this.performanceProfile,
    this.trueAirspeed,
    this.flightRules = 'IFR',
    this.routeString,
    this.cruiseAltitude,
    this.peopleCount = 1,
    this.avgPersonWeight = 170,
    this.cargoWeight = 0,
    this.fuelPolicy,
    this.startFuelGallons,
    this.reserveFuelGallons,
    this.fuelBurnRate,
    this.fuelAtShutdownGallons = 0,
    this.filingStatus = 'not_filed',
    this.filingReference,
    this.filingVersionStamp,
    this.filedAt,
    this.filingFormat,
    this.enduranceHours,
    this.remarks,
    this.distanceNm,
    this.eteMinutes,
    this.flightFuelGallons,
    this.windComponent,
    this.eta,
    this.calculatedAt,
    this.arrivalFboId,
    this.arrivalFboName,
    this.createdAt,
    this.updatedAt,
  });

  factory Flight.fromJson(Map<String, dynamic> json) {
    return Flight(
      id: json['id'] as int?,
      aircraftId: json['aircraft_id'] as int?,
      performanceProfileId: json['performance_profile_id'] as int?,
      departureIdentifier: json['departure_identifier'] as String?,
      destinationIdentifier: json['destination_identifier'] as String?,
      alternateIdentifier: json['alternate_identifier'] as String?,
      etd: json['etd'] as String?,
      aircraftIdentifier: json['aircraft_identifier'] as String?,
      aircraftType: json['aircraft_type'] as String?,
      performanceProfile: json['performance_profile'] as String?,
      trueAirspeed: json['true_airspeed'] as int?,
      flightRules: (json['flight_rules'] as String?) ?? 'IFR',
      routeString: json['route_string'] as String?,
      cruiseAltitude: json['cruise_altitude'] as int?,
      peopleCount: (json['people_count'] as int?) ?? 1,
      avgPersonWeight: (json['avg_person_weight'] as num?)?.toDouble() ?? 170,
      cargoWeight: (json['cargo_weight'] as num?)?.toDouble() ?? 0,
      fuelPolicy: json['fuel_policy'] as String?,
      startFuelGallons: (json['start_fuel_gallons'] as num?)?.toDouble(),
      reserveFuelGallons: (json['reserve_fuel_gallons'] as num?)?.toDouble(),
      fuelBurnRate: (json['fuel_burn_rate'] as num?)?.toDouble(),
      fuelAtShutdownGallons:
          (json['fuel_at_shutdown_gallons'] as num?)?.toDouble() ?? 0,
      filingStatus: (json['filing_status'] as String?) ?? 'not_filed',
      filingReference: json['filing_reference'] as String?,
      filingVersionStamp: json['filing_version_stamp'] as String?,
      filedAt: json['filed_at'] as String?,
      filingFormat: json['filing_format'] as String?,
      enduranceHours: (json['endurance_hours'] as num?)?.toDouble(),
      remarks: json['remarks'] as String?,
      distanceNm: (json['distance_nm'] as num?)?.toDouble(),
      eteMinutes: json['ete_minutes'] as int?,
      flightFuelGallons: (json['flight_fuel_gallons'] as num?)?.toDouble(),
      windComponent: (json['wind_component'] as num?)?.toDouble(),
      eta: json['eta'] as String?,
      calculatedAt: json['calculated_at'] as String?,
      arrivalFboId: json['arrival_fbo_id'] as int?,
      arrivalFboName: (json['arrival_fbo'] as Map<String, dynamic>?)?['name'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  /// Serializes editable fields for API requests.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'aircraft_id': aircraftId,
      'performance_profile_id': performanceProfileId,
      'departure_identifier': departureIdentifier,
      'destination_identifier': destinationIdentifier,
      'alternate_identifier': alternateIdentifier,
      'etd': etd,
      'aircraft_identifier': aircraftIdentifier,
      'aircraft_type': aircraftType,
      'performance_profile': performanceProfile,
      'true_airspeed': trueAirspeed,
      'flight_rules': flightRules,
      'route_string': routeString,
      'cruise_altitude': cruiseAltitude,
      'people_count': peopleCount,
      'avg_person_weight': avgPersonWeight,
      'cargo_weight': cargoWeight,
      'fuel_policy': fuelPolicy,
      'start_fuel_gallons': startFuelGallons,
      'reserve_fuel_gallons': reserveFuelGallons,
      'fuel_burn_rate': fuelBurnRate,
      'fuel_at_shutdown_gallons': fuelAtShutdownGallons,
      'filing_status': filingStatus,
      'endurance_hours': enduranceHours,
      'remarks': remarks,
      'arrival_fbo_id': arrivalFboId,
    };
  }

  /// Serializes all fields including computed values, for local persistence.
  Map<String, dynamic> toFullJson() {
    return {
      ...toJson(),
      'filing_reference': filingReference,
      'filing_version_stamp': filingVersionStamp,
      'filed_at': filedAt,
      'filing_format': filingFormat,
      'distance_nm': distanceNm,
      'ete_minutes': eteMinutes,
      'flight_fuel_gallons': flightFuelGallons,
      'wind_component': windComponent,
      'eta': eta,
      'calculated_at': calculatedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Flight copyWith({
    int? id,
    int? aircraftId,
    int? performanceProfileId,
    String? departureIdentifier,
    String? destinationIdentifier,
    String? alternateIdentifier,
    String? etd,
    String? aircraftIdentifier,
    String? aircraftType,
    String? performanceProfile,
    int? trueAirspeed,
    String? flightRules,
    String? routeString,
    int? cruiseAltitude,
    int? peopleCount,
    double? avgPersonWeight,
    double? cargoWeight,
    String? fuelPolicy,
    double? startFuelGallons,
    double? reserveFuelGallons,
    double? fuelBurnRate,
    double? fuelAtShutdownGallons,
    String? filingStatus,
    String? filingReference,
    String? filingVersionStamp,
    String? filedAt,
    String? filingFormat,
    double? enduranceHours,
    String? remarks,
    double? distanceNm,
    int? eteMinutes,
    double? flightFuelGallons,
    double? windComponent,
    String? eta,
    String? calculatedAt,
    int? arrivalFboId,
    String? arrivalFboName,
    String? createdAt,
    String? updatedAt,
  }) {
    return Flight(
      id: id ?? this.id,
      aircraftId: aircraftId ?? this.aircraftId,
      performanceProfileId: performanceProfileId ?? this.performanceProfileId,
      departureIdentifier: departureIdentifier ?? this.departureIdentifier,
      destinationIdentifier:
          destinationIdentifier ?? this.destinationIdentifier,
      alternateIdentifier: alternateIdentifier ?? this.alternateIdentifier,
      etd: etd ?? this.etd,
      aircraftIdentifier: aircraftIdentifier ?? this.aircraftIdentifier,
      aircraftType: aircraftType ?? this.aircraftType,
      performanceProfile: performanceProfile ?? this.performanceProfile,
      trueAirspeed: trueAirspeed ?? this.trueAirspeed,
      flightRules: flightRules ?? this.flightRules,
      routeString: routeString ?? this.routeString,
      cruiseAltitude: cruiseAltitude ?? this.cruiseAltitude,
      peopleCount: peopleCount ?? this.peopleCount,
      avgPersonWeight: avgPersonWeight ?? this.avgPersonWeight,
      cargoWeight: cargoWeight ?? this.cargoWeight,
      fuelPolicy: fuelPolicy ?? this.fuelPolicy,
      startFuelGallons: startFuelGallons ?? this.startFuelGallons,
      reserveFuelGallons: reserveFuelGallons ?? this.reserveFuelGallons,
      fuelBurnRate: fuelBurnRate ?? this.fuelBurnRate,
      fuelAtShutdownGallons:
          fuelAtShutdownGallons ?? this.fuelAtShutdownGallons,
      filingStatus: filingStatus ?? this.filingStatus,
      filingReference: filingReference ?? this.filingReference,
      filingVersionStamp: filingVersionStamp ?? this.filingVersionStamp,
      filedAt: filedAt ?? this.filedAt,
      filingFormat: filingFormat ?? this.filingFormat,
      enduranceHours: enduranceHours ?? this.enduranceHours,
      remarks: remarks ?? this.remarks,
      distanceNm: distanceNm ?? this.distanceNm,
      eteMinutes: eteMinutes ?? this.eteMinutes,
      flightFuelGallons: flightFuelGallons ?? this.flightFuelGallons,
      windComponent: windComponent ?? this.windComponent,
      eta: eta ?? this.eta,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      arrivalFboId: arrivalFboId ?? this.arrivalFboId,
      arrivalFboName: arrivalFboName ?? this.arrivalFboName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
