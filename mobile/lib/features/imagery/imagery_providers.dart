import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_client.dart';

/// Fetches the imagery product catalog from the backend.
final imageryCatalogProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getImageryCatalog();
});

/// Parameters for a GFA image request.
class GfaImageParams {
  final String gfaType;
  final String region;
  final int forecastHour;

  const GfaImageParams({
    required this.gfaType,
    required this.region,
    this.forecastHour = 3,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GfaImageParams &&
          gfaType == other.gfaType &&
          region == other.region &&
          forecastHour == other.forecastHour;

  @override
  int get hashCode =>
      gfaType.hashCode ^ region.hashCode ^ forecastHour.hashCode;
}

/// Fetches a GFA image as raw bytes.
final gfaImageProvider =
    FutureProvider.family<Uint8List?, GfaImageParams>((ref, params) async {
  final api = ref.watch(apiClientProvider);
  return api.getGfaImage(
    params.gfaType,
    params.region,
    forecastHour: params.forecastHour,
  );
});

/// Parameters for a Prog Chart image request.
class ProgChartParams {
  final String progType;
  final int forecastHour;

  const ProgChartParams({
    required this.progType,
    this.forecastHour = 6,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgChartParams &&
          progType == other.progType &&
          forecastHour == other.forecastHour;

  @override
  int get hashCode => progType.hashCode ^ forecastHour.hashCode;
}

/// Fetches a Prog Chart image as raw bytes.
final progChartProvider =
    FutureProvider.family<Uint8List?, ProgChartParams>((ref, params) async {
  final api = ref.watch(apiClientProvider);
  return api.getProgChart(
    params.progType,
    forecastHour: params.forecastHour,
  );
});

/// Parameters for an Icing Chart image request.
class IcingChartParams {
  final String icingParam;
  final String level;
  final int forecastHour;

  const IcingChartParams({
    required this.icingParam,
    this.level = 'max',
    this.forecastHour = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcingChartParams &&
          icingParam == other.icingParam &&
          level == other.level &&
          forecastHour == other.forecastHour;

  @override
  int get hashCode =>
      icingParam.hashCode ^ level.hashCode ^ forecastHour.hashCode;
}

/// Fetches an Icing Chart image as raw bytes.
final icingChartProvider =
    FutureProvider.family<Uint8List?, IcingChartParams>((ref, params) async {
  final api = ref.watch(apiClientProvider);
  return api.getIcingChart(
    params.icingParam,
    level: params.level,
    forecastHour: params.forecastHour,
  );
});

/// Parameters for an advisory request.
class AdvisoryParams {
  final String type;
  final int? forecastHour;

  const AdvisoryParams({required this.type, this.forecastHour});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvisoryParams &&
          type == other.type &&
          forecastHour == other.forecastHour;

  @override
  int get hashCode => type.hashCode ^ forecastHour.hashCode;
}

/// Fetches advisory GeoJSON by type (gairmets, sigmets, cwas).
/// For gairmets, supports an optional forecastHour (0, 3, 6, 9, 12).
final advisoriesProvider = FutureProvider.family<Map<String, dynamic>?,
    AdvisoryParams>((ref, params) async {
  final api = ref.watch(apiClientProvider);
  return api.getAdvisories(params.type, forecastHour: params.forecastHour);
});

/// Fetches TFR GeoJSON from the backend.
final tfrsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getTfrs();
});
