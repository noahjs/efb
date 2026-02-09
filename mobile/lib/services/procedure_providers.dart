import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/procedure.dart';
import 'api_client.dart';

/// Provider for airport procedures grouped by chart_code
final airportProceduresProvider = FutureProvider.family<
    Map<String, List<Procedure>>, String>((ref, airportId) async {
  final client = ref.read(apiClientProvider);
  final data = await client.getProcedures(airportId);

  final Map<String, List<Procedure>> grouped = {};
  for (final entry in data.entries) {
    final chartCode = entry.key;
    final records = entry.value as List<dynamic>;
    grouped[chartCode] =
        records.map((r) => Procedure.fromJson(r as Map<String, dynamic>)).toList();
  }

  return grouped;
});

/// Provider for procedure georef data (for map overlay positioning)
final procedureGeorefProvider = FutureProvider.family<GeorefData?,
    ({String airportId, int procedureId})>((ref, params) async {
  final client = ref.read(apiClientProvider);
  final data =
      await client.getGeoref(params.airportId, params.procedureId);
  if (data == null) return null;
  return GeorefData.fromJson(data);
});
