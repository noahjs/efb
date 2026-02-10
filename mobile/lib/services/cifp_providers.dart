import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../models/approach_chart.dart';

/// Provider for list of approaches at an airport.
final approachListProvider =
    FutureProvider.family<List<ApproachSummary>, String>((ref, airportId) async {
  final client = ref.read(apiClientProvider);
  final raw = await client.getApproaches(airportId);
  return raw
      .map((e) => ApproachSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Provider for chart data (approach + legs + ILS + MSA + runway).
final approachChartDataProvider = FutureProvider.family<ApproachChartData,
    ({String airportId, int approachId})>((ref, params) async {
  final client = ref.read(apiClientProvider);
  final raw =
      await client.getChartData(params.airportId, params.approachId);
  return ApproachChartData.fromJson(raw);
});
