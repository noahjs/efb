class ApproachSummary {
  final int id;
  final String airportIdentifier;
  final String? icaoIdentifier;
  final String procedureIdentifier;
  final String routeType;
  final String? transitionIdentifier;
  final String procedureName;
  final String? runwayIdentifier;
  final String? cycle;
  final int legCount;

  const ApproachSummary({
    required this.id,
    required this.airportIdentifier,
    this.icaoIdentifier,
    required this.procedureIdentifier,
    required this.routeType,
    this.transitionIdentifier,
    required this.procedureName,
    this.runwayIdentifier,
    this.cycle,
    this.legCount = 0,
  });

  factory ApproachSummary.fromJson(Map<String, dynamic> json) {
    return ApproachSummary(
      id: json['id'] as int,
      airportIdentifier: (json['airport_identifier'] as String?) ?? '',
      icaoIdentifier: json['icao_identifier'] as String?,
      procedureIdentifier: (json['procedure_identifier'] as String?) ?? '',
      routeType: (json['route_type'] as String?) ?? '',
      transitionIdentifier: json['transition_identifier'] as String?,
      procedureName: (json['procedure_name'] as String?) ?? '',
      runwayIdentifier: json['runway_identifier'] as String?,
      cycle: json['cycle'] as String?,
      legCount: (json['leg_count'] as int?) ?? 0,
    );
  }

  String get routeTypeName {
    switch (routeType) {
      case 'I':
        return 'ILS';
      case 'L':
        return 'LOC';
      case 'R':
        return 'RNAV (GPS)';
      case 'P':
        return 'GPS';
      case 'V':
        return 'VOR';
      case 'D':
        return 'VOR/DME';
      case 'N':
        return 'NDB';
      case 'X':
        return 'LDA';
      case 'B':
        return 'LOC BC';
      case 'S':
        return 'VOR/DME';
      default:
        return routeType;
    }
  }
}

class ApproachChartData {
  final ApproachInfo approach;
  final List<ApproachLeg> legs;
  final IlsData? ils;
  final MsaData? msa;
  final CifpRunwayData? runway;

  const ApproachChartData({
    required this.approach,
    required this.legs,
    this.ils,
    this.msa,
    this.runway,
  });

  factory ApproachChartData.fromJson(Map<String, dynamic> json) {
    final legsRaw = json['legs'] as List<dynamic>? ?? [];
    return ApproachChartData(
      approach: ApproachInfo.fromJson(
          json['approach'] as Map<String, dynamic>),
      legs: legsRaw
          .map((l) => ApproachLeg.fromJson(l as Map<String, dynamic>))
          .toList(),
      ils: json['ils'] != null
          ? IlsData.fromJson(json['ils'] as Map<String, dynamic>)
          : null,
      msa: json['msa'] != null
          ? MsaData.fromJson(json['msa'] as Map<String, dynamic>)
          : null,
      runway: json['runway'] != null
          ? CifpRunwayData.fromJson(json['runway'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Find the FAF leg — first try explicit is_faf flag, then fall back to
  /// last named approach fix before MAP.
  ApproachLeg? findFaf() {
    final explicit = legs.cast<ApproachLeg?>().firstWhere(
          (l) => l!.isFaf,
          orElse: () => null,
        );
    if (explicit != null) return explicit;

    final mapIdx = legs.indexWhere((l) => l.isMap);
    final approachLegs = (mapIdx >= 0 ? legs.sublist(0, mapIdx) : legs)
        .where((l) =>
            l.fixIdentifier != null &&
            !l.fixIdentifier!.startsWith('RW'))
        .toList();
    return approachLegs.isNotEmpty ? approachLegs.last : null;
  }

  /// Parse route_distance_or_time string to NM as double.
  static double? parseDist(String? s) {
    if (s == null || s.isEmpty) return null;
    final cleaned = s.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    final val = double.tryParse(cleaned);
    if (val == null) return null;
    return val / 10;
  }

  /// Distance from FAF to MAP in NM.
  double? get fafToMapDistance {
    final mapLeg = legs.cast<ApproachLeg?>().firstWhere(
          (l) => l!.isMap,
          orElse: () => null,
        );
    if (mapLeg == null) return null;
    return parseDist(mapLeg.routeDistanceOrTime);
  }

  /// List of approach legs (non-missed).
  List<ApproachLeg> get approachLegs =>
      legs.where((l) => !l.isMissedApproach).toList();

  /// List of missed approach legs.
  List<ApproachLeg> get missedApproachLegs =>
      legs.where((l) => l.isMissedApproach).toList();
}

class ApproachInfo {
  final int id;
  final String airportIdentifier;
  final String? icaoIdentifier;
  final String procedureIdentifier;
  final String routeType;
  final String? transitionIdentifier;
  final String procedureName;
  final String? runwayIdentifier;
  final String? cycle;

  const ApproachInfo({
    required this.id,
    required this.airportIdentifier,
    this.icaoIdentifier,
    required this.procedureIdentifier,
    required this.routeType,
    this.transitionIdentifier,
    required this.procedureName,
    this.runwayIdentifier,
    this.cycle,
  });

  factory ApproachInfo.fromJson(Map<String, dynamic> json) {
    return ApproachInfo(
      id: json['id'] as int,
      airportIdentifier: (json['airport_identifier'] as String?) ?? '',
      icaoIdentifier: json['icao_identifier'] as String?,
      procedureIdentifier: (json['procedure_identifier'] as String?) ?? '',
      routeType: (json['route_type'] as String?) ?? '',
      transitionIdentifier: json['transition_identifier'] as String?,
      procedureName: (json['procedure_name'] as String?) ?? '',
      runwayIdentifier: json['runway_identifier'] as String?,
      cycle: json['cycle'] as String?,
    );
  }
}

class ApproachLeg {
  final int sequenceNumber;
  final String? fixIdentifier;
  final String pathTermination;
  final String? turnDirection;
  final double? magneticCourse;
  final String? routeDistanceOrTime;
  final String? altitudeDescription;
  final int? altitude1;
  final int? altitude2;
  final double? verticalAngle;
  final int? speedLimit;
  final String? recommNavaid;
  final double? theta;
  final double? rho;
  final double? arcRadius;
  final String? centerFix;
  final double? fixLatitude;
  final double? fixLongitude;
  final bool isIaf;
  final bool isIf;
  final bool isFaf;
  final bool isMap;
  final bool isMissedApproach;

  const ApproachLeg({
    required this.sequenceNumber,
    this.fixIdentifier,
    required this.pathTermination,
    this.turnDirection,
    this.magneticCourse,
    this.routeDistanceOrTime,
    this.altitudeDescription,
    this.altitude1,
    this.altitude2,
    this.verticalAngle,
    this.speedLimit,
    this.recommNavaid,
    this.theta,
    this.rho,
    this.arcRadius,
    this.centerFix,
    this.fixLatitude,
    this.fixLongitude,
    this.isIaf = false,
    this.isIf = false,
    this.isFaf = false,
    this.isMap = false,
    this.isMissedApproach = false,
  });

  factory ApproachLeg.fromJson(Map<String, dynamic> json) {
    return ApproachLeg(
      sequenceNumber: (json['sequence_number'] as int?) ?? 0,
      fixIdentifier: json['fix_identifier'] as String?,
      pathTermination: (json['path_termination'] as String?) ?? '',
      turnDirection: json['turn_direction'] as String?,
      magneticCourse: (json['magnetic_course'] as num?)?.toDouble(),
      routeDistanceOrTime: json['route_distance_or_time'] as String?,
      altitudeDescription: json['altitude_description'] as String?,
      altitude1: json['altitude1'] as int?,
      altitude2: json['altitude2'] as int?,
      verticalAngle: (json['vertical_angle'] as num?)?.toDouble(),
      speedLimit: json['speed_limit'] as int?,
      recommNavaid: json['recomm_navaid'] as String?,
      theta: (json['theta'] as num?)?.toDouble(),
      rho: (json['rho'] as num?)?.toDouble(),
      arcRadius: (json['arc_radius'] as num?)?.toDouble(),
      centerFix: json['center_fix'] as String?,
      fixLatitude: (json['fix_latitude'] as num?)?.toDouble(),
      fixLongitude: (json['fix_longitude'] as num?)?.toDouble(),
      isIaf: (json['is_iaf'] as bool?) ?? false,
      isIf: (json['is_if'] as bool?) ?? false,
      isFaf: (json['is_faf'] as bool?) ?? false,
      isMap: (json['is_map'] as bool?) ?? false,
      isMissedApproach: (json['is_missed_approach'] as bool?) ?? false,
    );
  }

  /// Role label for display (IAF, IF, FAF, MAP).
  String? get roleLabel {
    if (isFaf) return 'FAF';
    if (isMap) return 'MAP';
    if (isIaf) return 'IAF';
    if (isIf) return 'IF';
    return null;
  }

  /// Altitude display string.
  String get altitudeDisplay {
    if (altitude1 == null) return '';
    final alt1 = '${altitude1!}\'';
    if (altitude2 != null && altitudeDescription == 'B') {
      return '${altitude2!}\' - $alt1';
    }
    final prefix = switch (altitudeDescription) {
      '+' => 'At or above ',
      '-' => 'At or below ',
      _ => '',
    };
    return '$prefix$alt1';
  }

  /// Distance in NM.
  double? get distanceNm => ApproachChartData.parseDist(routeDistanceOrTime);
}

class IlsData {
  final String localizerIdentifier;
  final double? frequency;
  final double? localizerBearing;
  final double? localizerLatitude;
  final double? localizerLongitude;
  final double? gsLatitude;
  final double? gsLongitude;
  final double? gsAngle;
  final int? gsElevation;
  final int? thresholdCrossingHeight;

  const IlsData({
    required this.localizerIdentifier,
    this.frequency,
    this.localizerBearing,
    this.localizerLatitude,
    this.localizerLongitude,
    this.gsLatitude,
    this.gsLongitude,
    this.gsAngle,
    this.gsElevation,
    this.thresholdCrossingHeight,
  });

  factory IlsData.fromJson(Map<String, dynamic> json) {
    return IlsData(
      localizerIdentifier:
          (json['localizer_identifier'] as String?) ?? '',
      frequency: (json['frequency'] as num?)?.toDouble(),
      localizerBearing: (json['localizer_bearing'] as num?)?.toDouble(),
      localizerLatitude: (json['localizer_latitude'] as num?)?.toDouble(),
      localizerLongitude:
          (json['localizer_longitude'] as num?)?.toDouble(),
      gsLatitude: (json['gs_latitude'] as num?)?.toDouble(),
      gsLongitude: (json['gs_longitude'] as num?)?.toDouble(),
      gsAngle: (json['gs_angle'] as num?)?.toDouble(),
      gsElevation: json['gs_elevation'] as int?,
      thresholdCrossingHeight:
          json['threshold_crossing_height'] as int?,
    );
  }

  String get frequencyDisplay {
    if (frequency == null) return '';
    return frequency!.toStringAsFixed(2);
  }
}

class MsaSector {
  final int bearingFrom;
  final int bearingTo;
  final int altitude;
  final int radius;

  const MsaSector({
    required this.bearingFrom,
    required this.bearingTo,
    required this.altitude,
    required this.radius,
  });

  factory MsaSector.fromJson(Map<String, dynamic> json) {
    return MsaSector(
      bearingFrom: (json['bearing_from'] as int?) ?? 0,
      bearingTo: (json['bearing_to'] as int?) ?? 0,
      altitude: (json['altitude'] as int?) ?? 0,
      radius: (json['radius'] as int?) ?? 25,
    );
  }
}

class MsaData {
  final String msaCenter;
  final List<MsaSector> sectors;

  const MsaData({
    required this.msaCenter,
    required this.sectors,
  });

  factory MsaData.fromJson(Map<String, dynamic> json) {
    final sectorsRaw = json['sectors'] as List<dynamic>? ?? [];
    return MsaData(
      msaCenter: (json['msa_center'] as String?) ?? '',
      sectors: sectorsRaw
          .map((s) => MsaSector.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CifpRunwayData {
  final String runwayIdentifier;
  final int? runwayLength;
  final double? runwayBearing;
  final double? thresholdLatitude;
  final double? thresholdLongitude;
  final int? thresholdElevation;
  final int? thresholdCrossingHeight;
  final int? runwayWidth;

  const CifpRunwayData({
    required this.runwayIdentifier,
    this.runwayLength,
    this.runwayBearing,
    this.thresholdLatitude,
    this.thresholdLongitude,
    this.thresholdElevation,
    this.thresholdCrossingHeight,
    this.runwayWidth,
  });

  factory CifpRunwayData.fromJson(Map<String, dynamic> json) {
    return CifpRunwayData(
      runwayIdentifier: (json['runway_identifier'] as String?) ?? '',
      runwayLength: json['runway_length'] as int?,
      runwayBearing: (json['runway_bearing'] as num?)?.toDouble(),
      thresholdLatitude:
          (json['threshold_latitude'] as num?)?.toDouble(),
      thresholdLongitude:
          (json['threshold_longitude'] as num?)?.toDouble(),
      thresholdElevation: json['threshold_elevation'] as int?,
      thresholdCrossingHeight:
          json['threshold_crossing_height'] as int?,
      runwayWidth: json['runway_width'] as int?,
    );
  }

  String get tdzeDisplay {
    if (thresholdElevation == null) return '---';
    return '${thresholdElevation!}\'';
  }
}
