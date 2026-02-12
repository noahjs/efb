/// Parse a numeric value that may arrive as a string (e.g. "10+" for visibility).
double? _parseNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    // Strip non-numeric trailing chars like "+" (e.g. "10+")
    final cleaned = v.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
  return null;
}

/// Parse an integer that may arrive as a string (e.g. "VRB" for wind direction).
/// Returns null for non-numeric strings like "VRB".
int? _parseIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class Briefing {
  final BriefingFlightSummary flight;
  final List<RouteAirport> routeAirports;
  final AdverseConditions adverseConditions;
  final Synopsis synopsis;
  final CurrentWeather currentWeather;
  final Forecasts forecasts;
  final BriefingNotams notams;
  final RiskSummary? riskSummary;
  final List<TimelinePoint> routeTimeline;
  final String? generatedAt;

  const Briefing({
    required this.flight,
    required this.routeAirports,
    required this.adverseConditions,
    required this.synopsis,
    required this.currentWeather,
    required this.forecasts,
    required this.notams,
    this.riskSummary,
    this.routeTimeline = const [],
    this.generatedAt,
  });

  factory Briefing.fromJson(Map<String, dynamic> json) {
    return Briefing(
      flight: BriefingFlightSummary.fromJson(
          json['flight'] as Map<String, dynamic>),
      routeAirports: (json['routeAirports'] as List<dynamic>?)
              ?.map(
                  (e) => RouteAirport.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      adverseConditions: AdverseConditions.fromJson(
          json['adverseConditions'] as Map<String, dynamic>),
      synopsis: Synopsis.fromJson(json['synopsis'] as Map<String, dynamic>),
      currentWeather: CurrentWeather.fromJson(
          json['currentWeather'] as Map<String, dynamic>),
      forecasts:
          Forecasts.fromJson(json['forecasts'] as Map<String, dynamic>),
      notams:
          BriefingNotams.fromJson(json['notams'] as Map<String, dynamic>),
      riskSummary: json['riskSummary'] != null
          ? RiskSummary.fromJson(
              json['riskSummary'] as Map<String, dynamic>)
          : null,
      routeTimeline: (json['routeTimeline'] as List<dynamic>?)
              ?.map((t) =>
                  TimelinePoint.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      generatedAt: json['generatedAt']?.toString(),
    );
  }
}

class RouteAirport {
  final String identifier;
  final String? icaoIdentifier;
  final String name;
  final String? city;
  final String? state;
  final double latitude;
  final double longitude;
  final double? elevation;
  final String? facilityType;
  final int distanceAlongRoute;
  final double distanceFromRoute;

  const RouteAirport({
    required this.identifier,
    this.icaoIdentifier,
    required this.name,
    this.city,
    this.state,
    required this.latitude,
    required this.longitude,
    this.elevation,
    this.facilityType,
    required this.distanceAlongRoute,
    required this.distanceFromRoute,
  });

  factory RouteAirport.fromJson(Map<String, dynamic> json) {
    return RouteAirport(
      identifier: json['identifier'] as String,
      icaoIdentifier: json['icaoIdentifier'] as String?,
      name: json['name'] as String? ?? '',
      city: json['city'] as String?,
      state: json['state'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      elevation: (json['elevation'] as num?)?.toDouble(),
      facilityType: json['facilityType'] as String?,
      distanceAlongRoute: json['distanceAlongRoute'] as int? ?? 0,
      distanceFromRoute:
          (json['distanceFromRoute'] as num?)?.toDouble() ?? 0,
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
      etd: json['etd']?.toString(),
      eteMinutes: json['eteMinutes'] as int?,
      eta: json['eta']?.toString(),
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

class CloudLayer {
  final String cover;
  final int? base;

  const CloudLayer({required this.cover, this.base});

  factory CloudLayer.fromJson(Map<String, dynamic> json) {
    return CloudLayer(
      cover: json['cover'] as String? ?? '',
      base: json['base'] as int?,
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
  final double? temp;
  final double? dewp;
  final int? wdir;
  final int? wspd;
  final int? wgst;
  final double? visib;
  final double? altim;
  final List<CloudLayer> clouds;
  final int? ceiling;

  const BriefingMetar({
    required this.station,
    required this.icaoId,
    this.flightCategory,
    this.rawOb,
    this.obsTime,
    required this.section,
    this.temp,
    this.dewp,
    this.wdir,
    this.wspd,
    this.wgst,
    this.visib,
    this.altim,
    this.clouds = const [],
    this.ceiling,
  });

  factory BriefingMetar.fromJson(Map<String, dynamic> json) {
    return BriefingMetar(
      station: json['station'] as String,
      icaoId: json['icaoId'] as String,
      flightCategory: json['flightCategory'] as String?,
      rawOb: json['rawOb'] as String?,
      obsTime: json['obsTime']?.toString(),
      section: json['section'] as String,
      temp: (json['temp'] as num?)?.toDouble(),
      dewp: (json['dewp'] as num?)?.toDouble(),
      wdir: _parseIntOrNull(json['wdir']),
      wspd: _parseIntOrNull(json['wspd']),
      wgst: _parseIntOrNull(json['wgst']),
      visib: _parseNum(json['visib']),
      altim: (json['altim'] as num?)?.toDouble(),
      clouds: (json['clouds'] as List<dynamic>?)
              ?.map((c) => CloudLayer.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      ceiling: (json['ceiling'] as num?)?.toInt(),
    );
  }
}

class TafForecastPeriod {
  final String timeFrom;
  final String timeTo;
  final String changeType;
  final int? wdir;
  final int? wspd;
  final int? wgst;
  final double? visib;
  final List<CloudLayer> clouds;
  final String? fltCat;

  const TafForecastPeriod({
    required this.timeFrom,
    required this.timeTo,
    required this.changeType,
    this.wdir,
    this.wspd,
    this.wgst,
    this.visib,
    this.clouds = const [],
    this.fltCat,
  });

  factory TafForecastPeriod.fromJson(Map<String, dynamic> json) {
    return TafForecastPeriod(
      timeFrom: json['timeFrom']?.toString() ?? '',
      timeTo: json['timeTo']?.toString() ?? '',
      changeType: json['changeType'] as String? ?? 'initial',
      wdir: _parseIntOrNull(json['wdir']),
      wspd: _parseIntOrNull(json['wspd']),
      wgst: _parseIntOrNull(json['wgst']),
      visib: _parseNum(json['visib']),
      clouds: (json['clouds'] as List<dynamic>?)
              ?.map((c) => CloudLayer.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      fltCat: json['fltCat'] as String?,
    );
  }
}

class BriefingTaf {
  final String station;
  final String icaoId;
  final String? rawTaf;
  final String section;
  final List<TafForecastPeriod> fcsts;

  const BriefingTaf({
    required this.station,
    required this.icaoId,
    this.rawTaf,
    required this.section,
    this.fcsts = const [],
  });

  factory BriefingTaf.fromJson(Map<String, dynamic> json) {
    return BriefingTaf(
      station: json['station'] as String,
      icaoId: json['icaoId'] as String,
      rawTaf: json['rawTaf'] as String?,
      section: json['section'] as String,
      fcsts: (json['fcsts'] as List<dynamic>?)
              ?.map((f) =>
                  TafForecastPeriod.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
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
      effectiveStart: json['effectiveStart']?.toString(),
      effectiveEnd: json['effectiveEnd']?.toString(),
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

class AffectedSegment {
  final String fromWaypoint;
  final String toWaypoint;
  final double fromDistNm;
  final double toDistNm;
  final double fromEtaMin;
  final double toEtaMin;

  const AffectedSegment({
    required this.fromWaypoint,
    required this.toWaypoint,
    required this.fromDistNm,
    required this.toDistNm,
    required this.fromEtaMin,
    required this.toEtaMin,
  });

  factory AffectedSegment.fromJson(Map<String, dynamic> json) {
    return AffectedSegment(
      fromWaypoint: json['fromWaypoint'] as String? ?? '',
      toWaypoint: json['toWaypoint'] as String? ?? '',
      fromDistNm: (json['fromDistNm'] as num?)?.toDouble() ?? 0,
      toDistNm: (json['toDistNm'] as num?)?.toDouble() ?? 0,
      fromEtaMin: (json['fromEtaMin'] as num?)?.toDouble() ?? 0,
      toEtaMin: (json['toEtaMin'] as num?)?.toDouble() ?? 0,
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
  final int? topFt;
  final int? baseFt;
  final String? altitudeRelation;
  final AffectedSegment? affectedSegment;
  final String? plainEnglish;

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
    this.topFt,
    this.baseFt,
    this.altitudeRelation,
    this.affectedSegment,
    this.plainEnglish,
  });

  factory BriefingAdvisory.fromJson(Map<String, dynamic> json) {
    return BriefingAdvisory(
      hazardType: json['hazardType'] as String? ?? 'Unknown',
      rawText: json['rawText'] as String? ?? '',
      validStart: json['validStart']?.toString(),
      validEnd: json['validEnd']?.toString(),
      severity: json['severity'] as String?,
      top: json['top']?.toString(),
      base: json['base']?.toString(),
      dueTo: json['dueTo'] as String?,
      geometry: json['geometry'] as Map<String, dynamic>?,
      topFt: (json['topFt'] as num?)?.toInt(),
      baseFt: (json['baseFt'] as num?)?.toInt(),
      altitudeRelation: json['altitudeRelation'] as String?,
      affectedSegment: json['affectedSegment'] != null
          ? AffectedSegment.fromJson(
              json['affectedSegment'] as Map<String, dynamic>)
          : null,
      plainEnglish: json['plainEnglish'] as String?,
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
      effectiveStart: json['effectiveStart']?.toString(),
      effectiveEnd: json['effectiveEnd']?.toString(),
      notamText: json['notamText']?.toString(),
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
      time: json['time']?.toString(),
      altitude: json['altitude']?.toString(),
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
              ?.map((a) => (a as num).toInt())
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

// Risk Assessment types
class RiskSummary {
  final String overallLevel;
  final List<RiskCategory> categories;
  final List<String> criticalItems;

  const RiskSummary({
    required this.overallLevel,
    this.categories = const [],
    this.criticalItems = const [],
  });

  factory RiskSummary.fromJson(Map<String, dynamic> json) {
    return RiskSummary(
      overallLevel: json['overallLevel'] as String? ?? 'green',
      categories: (json['categories'] as List<dynamic>?)
              ?.map((c) =>
                  RiskCategory.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      criticalItems: (json['criticalItems'] as List<dynamic>?)
              ?.map((i) => i as String)
              .toList() ??
          [],
    );
  }
}

class RiskCategory {
  final String category;
  final String level;
  final List<String> alerts;

  const RiskCategory({
    required this.category,
    required this.level,
    this.alerts = const [],
  });

  factory RiskCategory.fromJson(Map<String, dynamic> json) {
    return RiskCategory(
      category: json['category'] as String? ?? '',
      level: json['level'] as String? ?? 'green',
      alerts: (json['alerts'] as List<dynamic>?)
              ?.map((a) => a as String)
              .toList() ??
          [],
    );
  }
}

// Route Timeline types
class TimelineHazard {
  final String type;
  final String description;
  final String? altitudeRelation;

  const TimelineHazard({
    required this.type,
    required this.description,
    this.altitudeRelation,
  });

  factory TimelineHazard.fromJson(Map<String, dynamic> json) {
    return TimelineHazard(
      type: json['type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      altitudeRelation: json['altitudeRelation'] as String?,
    );
  }
}

class TimelinePoint {
  final String waypoint;
  final double latitude;
  final double longitude;
  final int distanceFromDep;
  final int etaMinutes;
  final String? etaZulu;
  final String? nearestStation;
  final String? flightCategory;
  final int? ceiling;
  final double? visibility;
  final int? windDir;
  final int? windSpd;
  final TafForecastPeriod? forecastAtEta;
  final int? headwindComponent;
  final int? crosswindComponent;
  final List<TimelineHazard> activeHazards;

  const TimelinePoint({
    required this.waypoint,
    required this.latitude,
    required this.longitude,
    this.distanceFromDep = 0,
    this.etaMinutes = 0,
    this.etaZulu,
    this.nearestStation,
    this.flightCategory,
    this.ceiling,
    this.visibility,
    this.windDir,
    this.windSpd,
    this.forecastAtEta,
    this.headwindComponent,
    this.crosswindComponent,
    this.activeHazards = const [],
  });

  factory TimelinePoint.fromJson(Map<String, dynamic> json) {
    return TimelinePoint(
      waypoint: json['waypoint'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      distanceFromDep: (json['distanceFromDep'] as num?)?.toInt() ?? 0,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      etaZulu: json['etaZulu']?.toString(),
      nearestStation: json['nearestStation'] as String?,
      flightCategory: json['flightCategory'] as String?,
      ceiling: (json['ceiling'] as num?)?.toInt(),
      visibility: _parseNum(json['visibility']),
      windDir: _parseIntOrNull(json['windDir']),
      windSpd: _parseIntOrNull(json['windSpd']),
      forecastAtEta: json['forecastAtEta'] != null
          ? TafForecastPeriod.fromJson(
              json['forecastAtEta'] as Map<String, dynamic>)
          : null,
      headwindComponent: (json['headwindComponent'] as num?)?.toInt(),
      crosswindComponent: (json['crosswindComponent'] as num?)?.toInt(),
      activeHazards: (json['activeHazards'] as List<dynamic>?)
              ?.map((h) =>
                  TimelineHazard.fromJson(h as Map<String, dynamic>))
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
