import '../../adsb/models/traffic_target.dart';
import '../../../services/api_client.dart';

/// Converts raw API response maps into [TrafficTarget] instances.
class TrafficApiService {
  final ApiClient _client;

  TrafficApiService(this._client);

  /// Fetches traffic near [lat]/[lon] within [radiusNm] nautical miles.
  /// Returns a map keyed by ICAO hex string.
  Future<Map<String, TrafficTarget>> fetchNearby({
    required double lat,
    required double lon,
    double radiusNm = 30,
  }) async {
    final raw = await _client.getTrafficNearby(
      lat: lat,
      lon: lon,
      radius: radiusNm,
    );
    if (raw == null) return {};

    final now = DateTime.now();
    final result = <String, TrafficTarget>{};

    for (final item in raw) {
      final hex = (item['icaoHex'] as String?) ?? '';
      if (hex.isEmpty) continue;

      final posAgeSec = (item['positionAgeSeconds'] as num?)?.toInt() ?? 0;
      final icaoInt = int.tryParse(hex, radix: 16) ?? 0;

      result[hex] = TrafficTarget(
        icaoAddress: icaoInt,
        callsign: (item['callsign'] as String?) ?? '',
        latitude: (item['latitude'] as num).toDouble(),
        longitude: (item['longitude'] as num).toDouble(),
        altitude: (item['altitude'] as num?)?.toInt() ?? 0,
        groundspeed: (item['groundspeed'] as num?)?.toInt() ?? 0,
        track: (item['track'] as num?)?.toInt() ?? 0,
        verticalRate: (item['verticalRate'] as num?)?.toInt() ?? 0,
        emitterCategory: 0,
        nic: 0,
        nacp: 0,
        isAirborne: item['isAirborne'] == true,
        lastUpdated: now,
        source: TrafficSource.api,
        positionAge: Duration(seconds: posAgeSec),
      );
    }

    return result;
  }
}
