class Briefing {
  final BriefingFlightSummary flight;
  final AdverseConditions adverseConditions;
  final Synopsis synopsis;
  final CurrentWeather currentWeather;
  final Forecasts forecasts;
  final BriefingNotams notams;

  const Briefing({
    required this.flight,
    required this.adverseConditions,
    required this.synopsis,
    required this.currentWeather,
    required this.forecasts,
    required this.notams,
  });

  factory Briefing.fromJson(Map<String, dynamic> json) {
    return Briefing(
      flight: BriefingFlightSummary.fromJson(
          json['flight'] as Map<String, dynamic>),
      adverseConditions: AdverseConditions.fromJson(
          json['adverseConditions'] as Map<String, dynamic>),
      synopsis: Synopsis.fromJson(json['synopsis'] as Map<String, dynamic>),
      currentWeather: CurrentWeather.fromJson(
          json['currentWeather'] as Map<String, dynamic>),
      forecasts:
          Forecasts.fromJson(json['forecasts'] as Map<String, dynamic>),
      notams:
          BriefingNotams.fromJson(json['notams'] as Map<String, dynamic>),
    );
  }
}

class BriefingFlightSummary {
  final int id;
  final String departureIdentifier;
  final String destinationIdentifier;
  final String? alternateIdentifier;
  final String? routeString;
  final int? cruiseAltitude;
  final String? aircraftIdentifier;
  final String? aircraftType;
  final String? etd;
  final int? eteMinutes;
  final String? eta;
  final double? distanceNm;
  final List<BriefingWaypoint> waypoints;

  const BriefingFlightSummary({
    required this.id,
    required this.departureIdentifier,
    required this.destinationIdentifier,
    this.alternateIdentifier,
    this.routeString,
    this.cruiseAltitude,
    this.aircraftIdentifier,
    this.aircraftType,
    this.etd,
    this.eteMinutes,
    this.eta,
    this.distanceNm,
    this.waypoints = const [],
  });

  factory BriefingFlightSummary.fromJson(Map<String, dynamic> json) {
    return BriefingFlightSummary(
      id: json['id'] as int,
      departureIdentifier: json['departureIdentifier'] as String,
      destinationIdentifier: json['destinationIdentifier'] as String,
      alternateIdentifier: json['alternateIdentifier'] as String?,
      routeString: json['routeString'] as String?,
      cruiseAltitude: json['cruiseAltitude'] as int?,
      aircraftIdentifier: json['aircraftIdentifier'] as String?,
      aircraftType: json['aircraftType'] as String?,
      etd: json['etd'] as String?,
      eteMinutes: json['eteMinutes'] as int?,
      eta: json['eta'] as String?,
      distanceNm: (json['distanceNm'] as num?)?.toDouble(),
      waypoints: (json['waypoints'] as List<dynamic>?)
              ?.map((w) =>
                  BriefingWaypoint.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BriefingWaypoint {
  final String identifier;
  final double latitude;
  final double longitude;
  final String type;
  final int distanceFromDep;
  final int etaMinutes;

  const BriefingWaypoint({
    required this.identifier,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.distanceFromDep = 0,
    this.etaMinutes = 0,
  });

  factory BriefingWaypoint.fromJson(Map<String, dynamic> json) {
    return BriefingWaypoint(
      identifier: json['identifier'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: json['type'] as String,
      distanceFromDep: (json['distanceFromDep'] as int?) ?? 0,
      etaMinutes: (json['etaMinutes'] as int?) ?? 0,
    );
  }
}

class BriefingMetar {
  final String station;
  final String icaoId;
  final String? flightCategory;
  final String? rawOb;
  final String? obsTime;
  final String section;

  const BriefingMetar({
    required this.station,
    required this.icaoId,
    this.flightCategory,
    this.rawOb,
    this.obsTime,
    required this.section,
  });

  factory BriefingMetar.fromJson(Map<String, dynamic> json) {
    return BriefingMetar(
      station: json['station'] as String,
      icaoId: json['icaoId'] as String,
      flightCategory: json['flightCategory'] as String?,
      rawOb: json['rawOb'] as String?,
      obsTime: json['obsTime'] as String?,
      section: json['section'] as String,
    );
  }
}

class BriefingTaf {
  final String station;
  final String icaoId;
  final String? rawTaf;
  final String section;

  const BriefingTaf({
    required this.station,
    required this.icaoId,
    this.rawTaf,
    required this.section,
  });

  factory BriefingTaf.fromJson(Map<String, dynamic> json) {
    return BriefingTaf(
      station: json['station'] as String,
      icaoId: json['icaoId'] as String,
      rawTaf: json['rawTaf'] as String?,
      section: json['section'] as String,
    );
  }
}

class BriefingNotam {
  final String id;
  final String type;
  final String icaoId;
  final String text;
  final String fullText;
  final String? effectiveStart;
  final String? effectiveEnd;
  final String category;

  const BriefingNotam({
    required this.id,
    required this.type,
    required this.icaoId,
    required this.text,
    required this.fullText,
    this.effectiveStart,
    this.effectiveEnd,
    required this.category,
  });

  factory BriefingNotam.fromJson(Map<String, dynamic> json) {
    return BriefingNotam(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      icaoId: json['icaoId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      fullText: json['fullText'] as String? ?? '',
      effectiveStart: json['effectiveStart'] as String?,
      effectiveEnd: json['effectiveEnd'] as String?,
      category: json['category'] as String? ?? '',
    );
  }
}

class CategorizedNotams {
  final List<BriefingNotam> navigation;
  final List<BriefingNotam> communication;
  final List<BriefingNotam> svc;
  final List<BriefingNotam> obstruction;

  const CategorizedNotams({
    this.navigation = const [],
    this.communication = const [],
    this.svc = const [],
    this.obstruction = const [],
  });

  int get totalCount =>
      navigation.length +
      communication.length +
      svc.length +
      obstruction.length;

  factory CategorizedNotams.fromJson(Map<String, dynamic> json) {
    return CategorizedNotams(
      navigation: _parseNotamList(json['navigation']),
      communication: _parseNotamList(json['communication']),
      svc: _parseNotamList(json['svc']),
      obstruction: _parseNotamList(json['obstruction']),
    );
  }
}

class EnrouteNotams {
  final List<BriefingNotam> navigation;
  final List<BriefingNotam> communication;
  final List<BriefingNotam> svc;
  final List<BriefingNotam> airspace;
  final List<BriefingNotam> specialUseAirspace;
  final List<BriefingNotam> rwyTwyApronAdFdc;
  final List<BriefingNotam> otherUnverified;

  const EnrouteNotams({
    this.navigation = const [],
    this.communication = const [],
    this.svc = const [],
    this.airspace = const [],
    this.specialUseAirspace = const [],
    this.rwyTwyApronAdFdc = const [],
    this.otherUnverified = const [],
  });

  int get totalCount =>
      navigation.length +
      communication.length +
      svc.length +
      airspace.length +
      specialUseAirspace.length +
      rwyTwyApronAdFdc.length +
      otherUnverified.length;

  factory EnrouteNotams.fromJson(Map<String, dynamic> json) {
    return EnrouteNotams(
      navigation: _parseNotamList(json['navigation']),
      communication: _parseNotamList(json['communication']),
      svc: _parseNotamList(json['svc']),
      airspace: _parseNotamList(json['airspace']),
      specialUseAirspace: _parseNotamList(json['specialUseAirspace']),
      rwyTwyApronAdFdc: _parseNotamList(json['rwyTwyApronAdFdc']),
      otherUnverified: _parseNotamList(json['otherUnverified']),
    );
  }
}

class BriefingAdvisory {
  final String hazardType;
  final String rawText;
  final String? validStart;
  final String? validEnd;
  final String? severity;
  final String? top;
  final String? base;
  final String? dueTo;
  final Map<String, dynamic>? geometry;

  const BriefingAdvisory({
    required this.hazardType,
    required this.rawText,
    this.validStart,
    this.validEnd,
    this.severity,
    this.top,
    this.base,
    this.dueTo,
    this.geometry,
  });

  factory BriefingAdvisory.fromJson(Map<String, dynamic> json) {
    return BriefingAdvisory(
      hazardType: json['hazardType'] as String? ?? 'Unknown',
      rawText: json['rawText'] as String? ?? '',
      validStart: json['validStart'] as String?,
      validEnd: json['validEnd'] as String?,
      severity: json['severity'] as String?,
      top: json['top'] as String?,
      base: json['base'] as String?,
      dueTo: json['dueTo'] as String?,
      geometry: json['geometry'] as Map<String, dynamic>?,
    );
  }
}

class BriefingTfr {
  final String notamNumber;
  final String description;
  final String? effectiveStart;
  final String? effectiveEnd;
  final String? notamText;
  final Map<String, dynamic>? geometry;

  const BriefingTfr({
    required this.notamNumber,
    required this.description,
    this.effectiveStart,
    this.effectiveEnd,
    this.notamText,
    this.geometry,
  });

  factory BriefingTfr.fromJson(Map<String, dynamic> json) {
    return BriefingTfr(
      notamNumber: json['notamNumber'] as String? ?? '',
      description: json['description'] as String? ?? '',
      effectiveStart: json['effectiveStart'] as String?,
      effectiveEnd: json['effectiveEnd'] as String?,
      notamText: json['notamText'] as String?,
      geometry: json['geometry'] as Map<String, dynamic>?,
    );
  }
}

class BriefingPirep {
  final String raw;
  final String? location;
  final String? time;
  final String? altitude;
  final String? aircraftType;
  final String? turbulence;
  final String? icing;
  final String urgency;
  final double? latitude;
  final double? longitude;

  const BriefingPirep({
    required this.raw,
    this.location,
    this.time,
    this.altitude,
    this.aircraftType,
    this.turbulence,
    this.icing,
    this.urgency = 'UA',
    this.latitude,
    this.longitude,
  });

  factory BriefingPirep.fromJson(Map<String, dynamic> json) {
    return BriefingPirep(
      raw: json['raw'] as String? ?? '',
      location: json['location'] as String?,
      time: json['time'] as String?,
      altitude: json['altitude'] as String?,
      aircraftType: json['aircraftType'] as String?,
      turbulence: json['turbulence'] as String?,
      icing: json['icing'] as String?,
      urgency: json['urgency'] as String? ?? 'UA',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class WindsAloftCell {
  final double? direction;
  final double? speed;
  final double? temperature;

  const WindsAloftCell({this.direction, this.speed, this.temperature});

  factory WindsAloftCell.fromJson(Map<String, dynamic> json) {
    return WindsAloftCell(
      direction: (json['direction'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
    );
  }
}

class WindsAloftTable {
  final List<String> waypoints;
  final List<int> altitudes;
  final int filedAltitude;
  final List<List<WindsAloftCell>> data;

  const WindsAloftTable({
    this.waypoints = const [],
    this.altitudes = const [],
    this.filedAltitude = 0,
    this.data = const [],
  });

  factory WindsAloftTable.fromJson(Map<String, dynamic> json) {
    return WindsAloftTable(
      waypoints: (json['waypoints'] as List<dynamic>?)
              ?.map((w) => w as String)
              .toList() ??
          [],
      altitudes: (json['altitudes'] as List<dynamic>?)
              ?.map((a) => a as int)
              .toList() ??
          [],
      filedAltitude: json['filedAltitude'] as int? ?? 0,
      data: (json['data'] as List<dynamic>?)
              ?.map((row) => (row as List<dynamic>)
                  .map((cell) =>
                      WindsAloftCell.fromJson(cell as Map<String, dynamic>))
                  .toList())
              .toList() ??
          [],
    );
  }
}

class GfaProduct {
  final String region;
  final String regionName;
  final String type;
  final List<int> forecastHours;

  const GfaProduct({
    required this.region,
    required this.regionName,
    required this.type,
    this.forecastHours = const [],
  });

  factory GfaProduct.fromJson(Map<String, dynamic> json) {
    return GfaProduct(
      region: json['region'] as String,
      regionName: json['regionName'] as String,
      type: json['type'] as String,
      forecastHours: (json['forecastHours'] as List<dynamic>?)
              ?.map((h) => h as int)
              .toList() ??
          [],
    );
  }
}

class AdverseConditions {
  final List<BriefingTfr> tfrs;
  final List<BriefingNotam> closedUnsafeNotams;
  final List<BriefingAdvisory> convectiveSigmets;
  final List<BriefingAdvisory> sigmets;
  final AirmetCategories airmets;
  final List<BriefingPirep> urgentPireps;

  const AdverseConditions({
    this.tfrs = const [],
    this.closedUnsafeNotams = const [],
    this.convectiveSigmets = const [],
    this.sigmets = const [],
    this.airmets = const AirmetCategories(),
    this.urgentPireps = const [],
  });

  factory AdverseConditions.fromJson(Map<String, dynamic> json) {
    return AdverseConditions(
      tfrs: (json['tfrs'] as List<dynamic>?)
              ?.map(
                  (t) => BriefingTfr.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      closedUnsafeNotams: _parseNotamList(json['closedUnsafeNotams']),
      convectiveSigmets: _parseAdvisoryList(json['convectiveSigmets']),
      sigmets: _parseAdvisoryList(json['sigmets']),
      airmets: json['airmets'] != null
          ? AirmetCategories.fromJson(json['airmets'] as Map<String, dynamic>)
          : const AirmetCategories(),
      urgentPireps: (json['urgentPireps'] as List<dynamic>?)
              ?.map((p) =>
                  BriefingPirep.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AirmetCategories {
  final List<BriefingAdvisory> ifr;
  final List<BriefingAdvisory> mountainObscuration;
  final List<BriefingAdvisory> icing;
  final List<BriefingAdvisory> turbulenceLow;
  final List<BriefingAdvisory> turbulenceHigh;
  final List<BriefingAdvisory> lowLevelWindShear;
  final List<BriefingAdvisory> other;

  const AirmetCategories({
    this.ifr = const [],
    this.mountainObscuration = const [],
    this.icing = const [],
    this.turbulenceLow = const [],
    this.turbulenceHigh = const [],
    this.lowLevelWindShear = const [],
    this.other = const [],
  });

  int get totalCount =>
      ifr.length +
      mountainObscuration.length +
      icing.length +
      turbulenceLow.length +
      turbulenceHigh.length +
      lowLevelWindShear.length +
      other.length;

  factory AirmetCategories.fromJson(Map<String, dynamic> json) {
    return AirmetCategories(
      ifr: _parseAdvisoryList(json['ifr']),
      mountainObscuration: _parseAdvisoryList(json['mountainObscuration']),
      icing: _parseAdvisoryList(json['icing']),
      turbulenceLow: _parseAdvisoryList(json['turbulenceLow']),
      turbulenceHigh: _parseAdvisoryList(json['turbulenceHigh']),
      lowLevelWindShear: _parseAdvisoryList(json['lowLevelWindShear']),
      other: _parseAdvisoryList(json['other']),
    );
  }
}

class Synopsis {
  final String surfaceAnalysisUrl;

  const Synopsis({required this.surfaceAnalysisUrl});

  factory Synopsis.fromJson(Map<String, dynamic> json) {
    return Synopsis(
      surfaceAnalysisUrl: json['surfaceAnalysisUrl'] as String? ?? '',
    );
  }
}

class CurrentWeather {
  final List<BriefingMetar> metars;
  final List<BriefingPirep> pireps;

  const CurrentWeather({
    this.metars = const [],
    this.pireps = const [],
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      metars: (json['metars'] as List<dynamic>?)
              ?.map((m) =>
                  BriefingMetar.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      pireps: (json['pireps'] as List<dynamic>?)
              ?.map((p) =>
                  BriefingPirep.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Forecasts {
  final List<GfaProduct> gfaCloudProducts;
  final List<GfaProduct> gfaSurfaceProducts;
  final List<BriefingTaf> tafs;
  final WindsAloftTable? windsAloftTable;

  const Forecasts({
    this.gfaCloudProducts = const [],
    this.gfaSurfaceProducts = const [],
    this.tafs = const [],
    this.windsAloftTable,
  });

  factory Forecasts.fromJson(Map<String, dynamic> json) {
    return Forecasts(
      gfaCloudProducts: (json['gfaCloudProducts'] as List<dynamic>?)
              ?.map((g) =>
                  GfaProduct.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      gfaSurfaceProducts: (json['gfaSurfaceProducts'] as List<dynamic>?)
              ?.map((g) =>
                  GfaProduct.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      tafs: (json['tafs'] as List<dynamic>?)
              ?.map(
                  (t) => BriefingTaf.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      windsAloftTable: json['windsAloftTable'] != null
          ? WindsAloftTable.fromJson(
              json['windsAloftTable'] as Map<String, dynamic>)
          : null,
    );
  }
}

class BriefingNotams {
  final CategorizedNotams? departure;
  final CategorizedNotams? destination;
  final CategorizedNotams? alternate1;
  final CategorizedNotams? alternate2;
  final EnrouteNotams enroute;
  final List<CategorizedNotams> artcc;

  const BriefingNotams({
    this.departure,
    this.destination,
    this.alternate1,
    this.alternate2,
    this.enroute = const EnrouteNotams(),
    this.artcc = const [],
  });

  factory BriefingNotams.fromJson(Map<String, dynamic> json) {
    return BriefingNotams(
      departure: json['departure'] != null
          ? CategorizedNotams.fromJson(
              json['departure'] as Map<String, dynamic>)
          : null,
      destination: json['destination'] != null
          ? CategorizedNotams.fromJson(
              json['destination'] as Map<String, dynamic>)
          : null,
      alternate1: json['alternate1'] != null
          ? CategorizedNotams.fromJson(
              json['alternate1'] as Map<String, dynamic>)
          : null,
      alternate2: json['alternate2'] != null
          ? CategorizedNotams.fromJson(
              json['alternate2'] as Map<String, dynamic>)
          : null,
      enroute: json['enroute'] != null
          ? EnrouteNotams.fromJson(json['enroute'] as Map<String, dynamic>)
          : const EnrouteNotams(),
      artcc: (json['artcc'] as List<dynamic>?)
              ?.map((a) => CategorizedNotams.fromJson(
                  a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// Helper functions
List<BriefingNotam> _parseNotamList(dynamic json) {
  if (json == null || json is! List) return [];
  return json
      .map((n) => BriefingNotam.fromJson(n as Map<String, dynamic>))
      .toList();
}

List<BriefingAdvisory> _parseAdvisoryList(dynamic json) {
  if (json == null || json is! List) return [];
  return json
      .map((a) => BriefingAdvisory.fromJson(a as Map<String, dynamic>))
      .toList();
}
