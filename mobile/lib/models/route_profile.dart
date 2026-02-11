class RouteProfilePoint {
  final double lat;
  final double lng;
  final double distanceNm;
  final double elevationFt;
  final double headwindComponent;
  final double crosswindComponent;
  final double windDirection;
  final double windSpeed;
  final double groundspeed;

  const RouteProfilePoint({
    required this.lat,
    required this.lng,
    required this.distanceNm,
    required this.elevationFt,
    required this.headwindComponent,
    required this.crosswindComponent,
    required this.windDirection,
    required this.windSpeed,
    required this.groundspeed,
  });

  factory RouteProfilePoint.fromJson(Map<String, dynamic> json) {
    return RouteProfilePoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      distanceNm: (json['distanceNm'] as num).toDouble(),
      elevationFt: (json['elevationFt'] as num).toDouble(),
      headwindComponent: (json['headwindComponent'] as num).toDouble(),
      crosswindComponent: (json['crosswindComponent'] as num).toDouble(),
      windDirection: (json['windDirection'] as num).toDouble(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
      groundspeed: (json['groundspeed'] as num).toDouble(),
    );
  }
}

class WaypointMarker {
  final String identifier;
  final double distanceNm;

  const WaypointMarker({
    required this.identifier,
    required this.distanceNm,
  });

  factory WaypointMarker.fromJson(Map<String, dynamic> json) {
    return WaypointMarker(
      identifier: json['identifier'] as String,
      distanceNm: (json['distanceNm'] as num).toDouble(),
    );
  }
}

class WindLayerSegment {
  final double distanceNm;
  final double headwindComponent;
  final double windDirection;
  final double windSpeed;

  const WindLayerSegment({
    required this.distanceNm,
    required this.headwindComponent,
    required this.windDirection,
    required this.windSpeed,
  });

  factory WindLayerSegment.fromJson(Map<String, dynamic> json) {
    return WindLayerSegment(
      distanceNm: (json['distanceNm'] as num).toDouble(),
      headwindComponent: (json['headwindComponent'] as num).toDouble(),
      windDirection: (json['windDirection'] as num).toDouble(),
      windSpeed: (json['windSpeed'] as num).toDouble(),
    );
  }
}

class WindLayer {
  final double altitudeFt;
  final List<WindLayerSegment> segments;

  const WindLayer({
    required this.altitudeFt,
    required this.segments,
  });

  factory WindLayer.fromJson(Map<String, dynamic> json) {
    return WindLayer(
      altitudeFt: (json['altitudeFt'] as num).toDouble(),
      segments: (json['segments'] as List)
          .map(
              (s) => WindLayerSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RouteProfileData {
  final List<RouteProfilePoint> points;
  final double cruiseAltitudeFt;
  final double totalDistanceNm;
  final double maxTerrainFt;
  final double departureElevationFt;
  final double destinationElevationFt;
  final List<WaypointMarker> waypointMarkers;
  final List<WindLayer> windLayers;

  const RouteProfileData({
    required this.points,
    required this.cruiseAltitudeFt,
    required this.totalDistanceNm,
    required this.maxTerrainFt,
    required this.departureElevationFt,
    required this.destinationElevationFt,
    required this.waypointMarkers,
    required this.windLayers,
  });

  factory RouteProfileData.fromJson(Map<String, dynamic> json) {
    return RouteProfileData(
      points: (json['points'] as List)
          .map((p) => RouteProfilePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      cruiseAltitudeFt: (json['cruiseAltitudeFt'] as num).toDouble(),
      totalDistanceNm: (json['totalDistanceNm'] as num).toDouble(),
      maxTerrainFt: (json['maxTerrainFt'] as num).toDouble(),
      departureElevationFt: (json['departureElevationFt'] as num).toDouble(),
      destinationElevationFt:
          (json['destinationElevationFt'] as num).toDouble(),
      waypointMarkers: (json['waypointMarkers'] as List)
          .map((m) => WaypointMarker.fromJson(m as Map<String, dynamic>))
          .toList(),
      windLayers: (json['windLayers'] as List?)
          ?.map((l) => WindLayer.fromJson(l as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}
