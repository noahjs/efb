import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/performance_data.dart';
import '../models/told_result.dart';
import 'told_calculator.dart';
import 'api_client.dart';

enum ToldMode { takeoff, landing }

class ToldState {
  final String? runwayEndIdentifier;
  final double? runwayHeading;
  final double? runwayLengthFt;
  final double? runwayElevation;
  final double? runwaySlope;
  final String? flapCode;
  final String surfaceType;
  final double safetyFactor;

  // Weather (auto from METAR, overridable)
  final double? windDir;
  final double? windSpeed;
  final double? tempC;
  final double? altimeter;
  final bool usingCustomWeather;
  final String? metarRaw;

  // Airport/runway data
  final Map<String, dynamic>? airportData;
  final Map<String, dynamic>? metarData;

  // Computed
  final ToldResult? result;

  // Loading states
  final bool isLoading;

  const ToldState({
    this.runwayEndIdentifier,
    this.runwayHeading,
    this.runwayLengthFt,
    this.runwayElevation,
    this.runwaySlope,
    this.flapCode,
    this.surfaceType = 'paved_dry',
    this.safetyFactor = 1.0,
    this.windDir,
    this.windSpeed,
    this.tempC,
    this.altimeter,
    this.usingCustomWeather = false,
    this.metarRaw,
    this.airportData,
    this.metarData,
    this.result,
    this.isLoading = false,
  });

  ToldState copyWith({
    String? runwayEndIdentifier,
    double? runwayHeading,
    double? runwayLengthFt,
    double? runwayElevation,
    double? runwaySlope,
    String? flapCode,
    String? surfaceType,
    double? safetyFactor,
    double? windDir,
    double? windSpeed,
    double? tempC,
    double? altimeter,
    bool? usingCustomWeather,
    String? metarRaw,
    Map<String, dynamic>? airportData,
    Map<String, dynamic>? metarData,
    ToldResult? result,
    bool? isLoading,
  }) {
    return ToldState(
      runwayEndIdentifier: runwayEndIdentifier ?? this.runwayEndIdentifier,
      runwayHeading: runwayHeading ?? this.runwayHeading,
      runwayLengthFt: runwayLengthFt ?? this.runwayLengthFt,
      runwayElevation: runwayElevation ?? this.runwayElevation,
      runwaySlope: runwaySlope ?? this.runwaySlope,
      flapCode: flapCode ?? this.flapCode,
      surfaceType: surfaceType ?? this.surfaceType,
      safetyFactor: safetyFactor ?? this.safetyFactor,
      windDir: windDir ?? this.windDir,
      windSpeed: windSpeed ?? this.windSpeed,
      tempC: tempC ?? this.tempC,
      altimeter: altimeter ?? this.altimeter,
      usingCustomWeather: usingCustomWeather ?? this.usingCustomWeather,
      metarRaw: metarRaw ?? this.metarRaw,
      airportData: airportData ?? this.airportData,
      metarData: metarData ?? this.metarData,
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Parameters for the TOLD state provider
class ToldParams {
  final int flightId;
  final ToldMode mode;

  const ToldParams({required this.flightId, required this.mode});

  @override
  bool operator ==(Object other) =>
      other is ToldParams &&
      other.flightId == flightId &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(flightId, mode);
}

class ToldStateNotifier extends ChangeNotifier {
  final ApiClient _api;
  final ToldParams _params;
  ToldState _state = const ToldState();

  ToldStateNotifier(this._api, this._params);

  ToldState get state => _state;

  void _setState(ToldState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Load airport data and METAR for the relevant airport
  Future<void> loadAirportData(String airportIdentifier) async {
    _setState(_state.copyWith(isLoading: true));
    try {
      final airport = await _api.getAirport(airportIdentifier);
      if (airport == null) {
        _setState(_state.copyWith(isLoading: false));
        return;
      }

      _setState(_state.copyWith(airportData: airport));

      // Load METAR
      final icao = airport['icao_identifier'] as String? ??
          airport['identifier'] as String? ??
          airportIdentifier;
      try {
        final metar = await _api.getMetar(icao);
        if (metar != null) {
          _setState(_state.copyWith(metarData: metar));
          if (!_state.usingCustomWeather) {
            _applyMetarWeather(metar);
          }
        }
      } catch (_) {}

      _autoSelectBestRunway();
      _setState(_state.copyWith(isLoading: false));
    } catch (e) {
      _setState(_state.copyWith(isLoading: false));
    }
  }

  void _applyMetarWeather(Map<String, dynamic> metar) {
    _setState(_state.copyWith(
      windDir: (metar['wdir'] as num?)?.toDouble(),
      windSpeed: (metar['wspd'] as num?)?.toDouble(),
      tempC: (metar['temp'] as num?)?.toDouble(),
      altimeter: (metar['altim'] as num?)?.toDouble(),
      metarRaw: metar['rawOb'] as String?,
    ));
  }

  void refreshMetar() async {
    final airportId = _state.airportData?['icao_identifier'] as String? ??
        _state.airportData?['identifier'] as String?;
    if (airportId == null) return;
    try {
      final metar = await _api.getMetar(airportId);
      if (metar != null) {
        _setState(_state.copyWith(metarData: metar));
        if (!_state.usingCustomWeather) {
          _applyMetarWeather(metar);
        }
      }
    } catch (_) {}
  }

  void _autoSelectBestRunway() {
    final airport = _state.airportData;
    if (airport == null) return;

    final runways =
        (airport['runways'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    double bestHeadwind = double.negativeInfinity;
    String? bestEndId;
    double? bestHeading;
    double? bestLength;
    double? bestElevation;
    double? bestSlope;

    for (final rwy in runways) {
      final ends =
          (rwy['ends'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      for (final end in ends) {
        final heading = (end['heading'] as num?)?.toDouble();
        if (heading == null) continue;

        final windDir = _state.windDir ?? 0;
        final windSpd = _state.windSpeed ?? 0;
        final hw = ToldCalculator.headwindComponent(windDir, windSpd, heading);
        if (hw > bestHeadwind) {
          bestHeadwind = hw;
          bestEndId = end['identifier'] as String?;
          bestHeading = heading;
          if (_params.mode == ToldMode.takeoff) {
            bestLength = (end['tora'] as num?)?.toDouble() ??
                (rwy['length'] as num?)?.toDouble();
          } else {
            bestLength = (end['lda'] as num?)?.toDouble() ??
                (rwy['length'] as num?)?.toDouble();
          }
          bestElevation = (end['elevation'] as num?)?.toDouble() ??
              (airport['elevation'] as num?)?.toDouble();
          bestSlope = (rwy['slope'] as num?)?.toDouble();
        }
      }
    }

    if (bestEndId != null) {
      _setState(_state.copyWith(
        runwayEndIdentifier: bestEndId,
        runwayHeading: bestHeading,
        runwayLengthFt: bestLength,
        runwayElevation: bestElevation,
        runwaySlope: bestSlope,
      ));
    }
  }

  void selectRunwayEnd(Map<String, dynamic> end, Map<String, dynamic> runway) {
    final mode = _params.mode;
    double? length;
    if (mode == ToldMode.takeoff) {
      length = (end['tora'] as num?)?.toDouble() ??
          (runway['length'] as num?)?.toDouble();
    } else {
      length = (end['lda'] as num?)?.toDouble() ??
          (runway['length'] as num?)?.toDouble();
    }
    _setState(_state.copyWith(
      runwayEndIdentifier: end['identifier'] as String?,
      runwayHeading: (end['heading'] as num?)?.toDouble(),
      runwayLengthFt: length,
      runwayElevation: (end['elevation'] as num?)?.toDouble() ??
          (_state.airportData?['elevation'] as num?)?.toDouble(),
      runwaySlope: (runway['slope'] as num?)?.toDouble(),
    ));
  }

  void setFlapCode(String code) {
    _setState(_state.copyWith(flapCode: code));
  }

  void setSurfaceType(String type) {
    _setState(_state.copyWith(surfaceType: type));
  }

  void setSafetyFactor(double factor) {
    _setState(_state.copyWith(safetyFactor: factor));
  }

  void setWindDir(double dir) {
    _setState(_state.copyWith(windDir: dir, usingCustomWeather: true));
  }

  void setWindSpeed(double speed) {
    _setState(_state.copyWith(windSpeed: speed, usingCustomWeather: true));
  }

  void setTempC(double temp) {
    _setState(_state.copyWith(tempC: temp, usingCustomWeather: true));
  }

  void setAltimeter(double alt) {
    _setState(_state.copyWith(altimeter: alt, usingCustomWeather: true));
  }

  void resetWeatherToMetar() {
    if (_state.metarData != null) {
      _applyMetarWeather(_state.metarData!);
      _setState(_state.copyWith(usingCustomWeather: false));
    }
  }

  void recalculate({
    required PerformanceData performanceData,
    required double weightLbs,
    double? maxWeight,
    String? weightLimitType,
  }) {
    final flapCode = _state.flapCode;
    FlapSetting? flapSetting;
    if (flapCode != null) {
      flapSetting = performanceData.flapSettings
          .where((f) => f.code == flapCode)
          .firstOrNull;
    }
    flapSetting ??= performanceData.flapSettings
        .where((f) => f.isDefault)
        .firstOrNull;
    flapSetting ??= performanceData.flapSettings.firstOrNull;

    if (flapSetting == null) return;

    if (_state.flapCode == null) {
      _setState(_state.copyWith(flapCode: flapSetting.code));
    }

    final elevation = _state.runwayElevation ??
        (_state.airportData?['elevation'] as num?)?.toDouble() ??
        0;
    final altimeter = _state.altimeter ?? 29.92;
    final tempC = _state.tempC ?? 15.0;
    final heading = _state.runwayHeading ?? 0;

    final result = ToldCalculator.calculate(
      flapSetting: flapSetting,
      fieldElevation: elevation,
      altimeterInHg: altimeter,
      temperatureC: tempC,
      weightLbs: weightLbs,
      runwayHeading: heading,
      windDir: _state.windDir ?? 0,
      windSpeed: _state.windSpeed ?? 0,
      slopePercent: _state.runwaySlope ?? 0,
      surfaceType: _state.surfaceType,
      safetyFactor: _state.safetyFactor,
      maxWeight: maxWeight,
      weightLimitType: weightLimitType,
      runwayAvailableFt: _state.runwayLengthFt,
      metarRaw: _state.metarRaw,
    );

    _setState(_state.copyWith(result: result));
  }

  void reset() {
    final airport = _state.airportData;
    final metar = _state.metarData;
    _state = const ToldState();
    if (airport != null) {
      _setState(_state.copyWith(airportData: airport, metarData: metar));
      if (metar != null) _applyMetarWeather(metar);
      _autoSelectBestRunway();
    } else {
      notifyListeners();
    }
  }
}

/// Cache of ToldStateNotifier instances, keyed by ToldParams
final _notifierCache = <ToldParams, ToldStateNotifier>{};

/// Provider that returns a ToldStateNotifier for a given ToldParams
final toldNotifierProvider =
    Provider.family<ToldStateNotifier, ToldParams>((ref, params) {
  final existing = _notifierCache[params];
  if (existing != null) return existing;

  final api = ref.read(apiClientProvider);
  final notifier = ToldStateNotifier(api, params);
  _notifierCache[params] = notifier;

  ref.onDispose(() {
    _notifierCache.remove(params);
    notifier.dispose();
  });

  return notifier;
});
