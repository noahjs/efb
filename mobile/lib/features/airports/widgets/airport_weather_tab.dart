import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/airport_providers.dart';

class AirportWeatherTab extends StatelessWidget {
  final String airportId;
  const AirportWeatherTab({super.key, required this.airportId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          // Sub-tabs
          Container(
            color: AppColors.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'METAR'),
                Tab(text: 'TAF'),
                Tab(text: 'MOS'),
                Tab(text: 'Daily'),
                Tab(text: 'Winds'),
              ],
              isScrollable: false,
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontSize: 12),
              indicatorSize: TabBarIndicatorSize.tab,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MetarView(airportId: airportId),
                _TafView(airportId: airportId),
                _PlaceholderView(label: 'MOS data coming soon'),
                _DailyForecastView(airportId: airportId),
                _WindsAloftView(airportId: airportId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetarView extends ConsumerWidget {
  final String airportId;
  const _MetarView({required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metarAsync = ref.watch(metarProvider(airportId));

    return metarAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load METAR',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (metar) {
        if (metar == null) {
          return const Center(
            child: Text(
              'No METAR available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final rawOb = metar['rawOb'] as String? ?? '';
        final fltCat = metar['fltCat'] as String? ?? '';
        final catColor = _flightCategoryColor(fltCat);
        final obsTime = _parseObsTime(metar);
        final ageText = obsTime != null ? _formatAge(obsTime) : '';

        return ListView(
          children: [
            // Flight category banner
            Container(
              margin: const EdgeInsets.all(16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: catColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: catColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fltCat,
                    style: TextStyle(
                      color: catColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  if (ageText.isNotEmpty)
                    Text(
                      ageText,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),

            // Raw METAR
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rawOb,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: catColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Decoded fields
            if (obsTime != null)
              _WeatherField(
                label: 'Time',
                value: _formatUtcTime(obsTime),
              ),
            if (metar['wdir'] != null || metar['wspd'] != null)
              _WeatherField(
                label: 'Wind',
                value: _formatWind(metar),
              ),
            if (metar['visib'] != null)
              _WeatherField(
                label: 'Visibility',
                value: '${metar['visib']} sm',
              ),
            if (metar['clouds'] != null &&
                (metar['clouds'] as List).isNotEmpty)
              _WeatherField(
                label: 'Clouds (AGL)',
                value: _formatClouds(metar['clouds'] as List),
                valueColor: catColor,
              ),
            if (metar['temp'] != null)
              _WeatherField(
                label: 'Temperature',
                value: _formatTemp(metar['temp']),
                valueColor: AppColors.primary,
              ),
            if (metar['dewp'] != null)
              _WeatherField(
                label: 'Dewpoint',
                value: _formatTemp(metar['dewp']),
                valueColor: AppColors.primary,
              ),
            if (metar['altim'] != null)
              _WeatherField(
                label: 'Altimeter',
                value: _formatAltimeter(metar['altim']),
                valueColor: AppColors.primary,
              ),
            if (metar['temp'] != null && metar['dewp'] != null)
              _WeatherField(
                label: 'Humidity',
                value: '${_calcHumidity(metar['temp'], metar['dewp'])}%',
              ),
            if (metar['wxString'] != null &&
                (metar['wxString'] as String).isNotEmpty)
              _WeatherField(
                label: 'Weather',
                value: metar['wxString'] as String,
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  static Color _flightCategoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'VFR':
        return AppColors.vfr;
      case 'MVFR':
        return AppColors.mvfr;
      case 'IFR':
        return AppColors.ifr;
      case 'LIFR':
        return AppColors.lifr;
      default:
        return AppColors.textMuted;
    }
  }

  static DateTime? _parseObsTime(Map<String, dynamic> metar) {
    if (metar['reportTime'] != null) {
      return DateTime.tryParse(metar['reportTime'] as String);
    }
    if (metar['obsTime'] != null) {
      final obs = metar['obsTime'];
      if (obs is num) {
        return DateTime.fromMillisecondsSinceEpoch(obs.toInt() * 1000,
            isUtc: true);
      }
    }
    return null;
  }

  static String _formatAge(DateTime obsTime) {
    final diff = DateTime.now().toUtc().difference(obsTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String _formatUtcTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:${min}Z';
  }

  static String _formatWind(Map<String, dynamic> metar) {
    final dir = metar['wdir'];
    final spd = metar['wspd'];
    final gust = metar['wgst'];
    var result = '';
    if (dir != null) result += '$dir°';
    if (spd != null) result += ' at $spd kts';
    if (gust != null) result += ' G$gust';
    return result.trim();
  }

  static String _formatClouds(List<dynamic> clouds) {
    return clouds.map((c) {
      final cover = c['cover'] ?? '';
      final base = c['base'];
      if (base != null) {
        return "$cover ${_formatNumber(base)}'";
      }
      return cover.toString();
    }).join('\n');
  }

  static String _formatNumber(dynamic n) {
    if (n is num) {
      return n.toInt().toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'),
            (m) => '${m[1]},',
          );
    }
    return n?.toString() ?? '';
  }

  static String _formatTemp(dynamic tempC) {
    if (tempC is num) {
      final f = (tempC * 9 / 5 + 32).round();
      return '${tempC.toStringAsFixed(1)}°C ($f°F)';
    }
    return '$tempC°C';
  }

  static String _formatAltimeter(dynamic hpa) {
    if (hpa is num) {
      final inHg = (hpa / 33.8639).toStringAsFixed(2);
      return '$inHg inHg';
    }
    return '$hpa';
  }

  static int _calcHumidity(dynamic temp, dynamic dewp) {
    if (temp is num && dewp is num) {
      // Magnus formula approximation
      final a = 17.625;
      final b = 243.04;
      final gammaD = (a * dewp) / (b + dewp);
      final gammaT = (a * temp) / (b + temp);
      return (100 * exp(gammaD - gammaT)).round().clamp(0, 100);
    }
    return 0;
  }
}

class _TafView extends ConsumerWidget {
  final String airportId;
  const _TafView({required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tafAsync = ref.watch(tafProvider(airportId));

    return tafAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load TAF',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (envelope) {
        if (envelope == null || envelope['taf'] == null) {
          return const Center(
            child: Text(
              'No TAF available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final taf = envelope['taf'] as Map<String, dynamic>;
        final isNearby = envelope['isNearby'] as bool? ?? false;
        final station = envelope['station'] as String? ?? '';
        final distanceNm = envelope['distanceNm'];
        final rawTaf = taf['rawTAF'] as String? ?? '';
        final fcsts = taf['fcsts'] as List<dynamic>? ?? [];

        return ListView(
          children: [
            // Nearby station banner
            if (isNearby)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.info),
                    const SizedBox(width: 6),
                    Text(
                      'Showing TAF from $station ($distanceNm nm)',
                      style: TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            // Valid period
            if (taf['validTimeFrom'] != null && taf['validTimeTo'] != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Valid ${_formatTimeRange(taf['validTimeFrom'], taf['validTimeTo'])}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),

            // Raw TAF
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                rawTaf,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Forecast groups
            for (final fcst in fcsts) ...[
              _buildForecastHeader(fcst),
              if (fcst['wdir'] != null || fcst['wspd'] != null)
                _WeatherField(
                  label: 'Wind',
                  value: _formatWind(fcst),
                ),
              if (fcst['visib'] != null)
                _WeatherField(
                  label: 'Visibility',
                  value: '${fcst['visib']} sm',
                ),
              if (fcst['clouds'] != null &&
                  (fcst['clouds'] as List).isNotEmpty)
                _WeatherField(
                  label: 'Clouds',
                  value: _formatClouds(fcst['clouds'] as List),
                ),
              if (fcst['wxString'] != null &&
                  (fcst['wxString'] as String).isNotEmpty)
                _WeatherField(
                  label: 'Weather',
                  value: fcst['wxString'] as String,
                ),
            ],

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildForecastHeader(dynamic fcst) {
    final changeType = fcst['changeType'] as String?;
    final label = changeType ?? 'BASE';
    final timeFrom = fcst['timeFrom'];
    final timeTo = fcst['timeTo'];

    final timeRange = _formatTimeRange(timeFrom, timeTo);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.surface,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              timeRange,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static DateTime? _parseTime(dynamic time) {
    if (time is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        time.toInt() * 1000,
        isUtc: true,
      );
    } else if (time is String) {
      return DateTime.tryParse(time)?.toUtc();
    }
    return null;
  }

  static String _dayTime12(DateTime dt) {
    final day = _weekdays[dt.weekday - 1];
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final time = m == '00' ? '$h12 $period' : '$h12:$m $period';
    return '$day $time';
  }

  static String _time12(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return m == '00' ? '$h12 $period' : '$h12:$m $period';
  }

  String _formatTimeRange(dynamic from, dynamic to) {
    final utcFrom = _parseTime(from);
    final utcTo = _parseTime(to);
    if (utcFrom == null && utcTo == null) return '';
    if (utcFrom == null) return _dayTime12(utcTo!.toLocal());
    if (utcTo == null) return _dayTime12(utcFrom.toLocal());

    final lFrom = utcFrom.toLocal();
    final lTo = utcTo.toLocal();

    // Local range: elide day if same
    final localRange = lFrom.weekday == lTo.weekday && lTo.difference(lFrom).inHours < 24
        ? '${_dayTime12(lFrom)} – ${_time12(lTo)}'
        : '${_dayTime12(lFrom)} – ${_dayTime12(lTo)}';

    // UTC range: elide day if same
    final utcRange = utcFrom.weekday == utcTo.weekday && utcTo.difference(utcFrom).inHours < 24
        ? '${_dayTime12(utcFrom)} – ${_time12(utcTo)}'
        : '${_dayTime12(utcFrom)} – ${_dayTime12(utcTo)}';

    return '$localRange ($utcRange UTC)';
  }

  String _formatWind(dynamic fcst) {
    final dir = fcst['wdir'];
    final spd = fcst['wspd'];
    final gust = fcst['wgst'];

    var result = '';
    if (dir != null) result += '$dir°';
    if (spd != null) result += ' at $spd kts';
    if (gust != null) result += ' G$gust';
    return result.trim();
  }

  String _formatClouds(List<dynamic> clouds) {
    return clouds.map((c) {
      final cover = c['cover'] ?? '';
      final base = c['base'];
      if (base != null) {
        return "$cover ${_formatNumber(base)}'";
      }
      return cover.toString();
    }).join('\n');
  }

  String _formatNumber(dynamic n) {
    if (n is num) {
      return n.toInt().toString().replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+$)'),
            (m) => '${m[1]},',
          );
    }
    return n?.toString() ?? '';
  }
}

class _WeatherField extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _WeatherField({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyForecastView extends ConsumerWidget {
  final String airportId;
  const _DailyForecastView({required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(forecastProvider(airportId));

    return forecastAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load forecast',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (forecast) {
        if (forecast == null || forecast['error'] != null) {
          return Center(
            child: Text(
              forecast?['error'] as String? ?? 'No forecast available',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final periods = forecast['periods'] as List<dynamic>? ?? [];
        if (periods.isEmpty) {
          return const Center(
            child: Text(
              'No forecast periods available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: periods.length,
          itemBuilder: (context, index) {
            final period = periods[index] as Map<String, dynamic>;
            return _ForecastPeriodCard(period: period);
          },
        );
      },
    );
  }
}

class _ForecastPeriodCard extends StatelessWidget {
  final Map<String, dynamic> period;
  const _ForecastPeriodCard({required this.period});

  @override
  Widget build(BuildContext context) {
    final isDaytime = period['isDaytime'] as bool? ?? true;
    final name = period['name'] as String? ?? '';
    final temp = period['temperature'];
    final tempUnit = period['temperatureUnit'] as String? ?? 'F';
    final shortForecast = period['shortForecast'] as String? ?? '';
    final detailedForecast = period['detailedForecast'] as String? ?? '';
    final windSpeed = period['windSpeed'] as String? ?? '';
    final windDirection = period['windDirection'] as String? ?? '';
    final precipProb = period['probabilityOfPrecipitation'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDaytime ? AppColors.surfaceLight : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: icon + name + temperature
          Row(
            children: [
              Icon(
                isDaytime ? Icons.wb_sunny : Icons.nightlight_round,
                size: 20,
                color: isDaytime ? AppColors.warning : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$temp°$tempUnit',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Short forecast
          Text(
            shortForecast,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 8),

          // Wind + precip row
          Row(
            children: [
              const Icon(Icons.air, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '$windDirection $windSpeed',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (precipProb != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.water_drop,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  '$precipProb%',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),

          if (detailedForecast.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detailedForecast,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WindsAloftView extends ConsumerStatefulWidget {
  final String airportId;
  const _WindsAloftView({required this.airportId});

  @override
  ConsumerState<_WindsAloftView> createState() => _WindsAloftViewState();
}

class _WindsAloftViewState extends ConsumerState<_WindsAloftView> {
  int _selectedPeriod = 0;

  @override
  Widget build(BuildContext context) {
    final windsAsync = ref.watch(windsAloftProvider(widget.airportId));

    return windsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load winds aloft',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (data) {
        if (data == null ||
            data['forecasts'] == null ||
            (data['forecasts'] as List).isEmpty) {
          return const Center(
            child: Text(
              'No winds aloft available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final isNearby = data['isNearby'] as bool? ?? false;
        final station = data['station'] as String? ?? '';
        final distanceNm = data['distanceNm'];
        final forecasts = data['forecasts'] as List<dynamic>;

        final selected = forecasts[_selectedPeriod] as Map<String, dynamic>;
        final altitudes = selected['altitudes'] as List<dynamic>? ?? [];

        return ListView(
          children: [
            // Nearby station banner
            if (isNearby)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.info),
                    const SizedBox(width: 6),
                    Text(
                      'Showing winds from $station ($distanceNm nm)',
                      style: TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            // Forecast period selector
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(forecasts.length, (i) {
                  final fcst = forecasts[i] as Map<String, dynamic>;
                  final label = fcst['label'] as String? ?? '';
                  final isSelected = i == _selectedPeriod;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedPeriod = i),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.divider,
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surface,
              child: const Row(
                children: [
                  SizedBox(
                      width: 70,
                      child: Text('ALT',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary))),
                  SizedBox(
                      width: 70,
                      child: Text('DIR',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary))),
                  SizedBox(
                      width: 70,
                      child: Text('SPD',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary))),
                  Expanded(
                      child: Text('TEMP',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary))),
                ],
              ),
            ),

            // Altitude rows
            for (int i = 0; i < altitudes.length; i++)
              _buildAltitudeRow(altitudes[i] as Map<String, dynamic>, i),

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildAltitudeRow(Map<String, dynamic> alt, int index) {
    final altitude = alt['altitude'];
    final direction = alt['direction'];
    final speed = alt['speed'];
    final temperature = alt['temperature'];
    final lv = alt['lightAndVariable'] as bool? ?? false;

    final bgColor =
        index.isEven ? AppColors.surface : AppColors.surfaceLight;

    String dirText;
    String spdText;
    if (lv) {
      dirText = 'L&V';
      spdText = '--';
    } else if (direction == null && speed == null) {
      dirText = '--';
      spdText = '--';
    } else {
      dirText = direction != null ? '$direction°' : '--';
      spdText = speed != null ? '$speed kt' : '--';
    }

    final tempText = temperature != null
        ? '${temperature > 0 ? '+' : ''}$temperature°C'
        : '--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bgColor,
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              _formatAltitude(altitude),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              dirText,
              style: TextStyle(
                fontSize: 14,
                color: lv ? AppColors.info : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              spdText,
              style: TextStyle(
                fontSize: 14,
                color: lv ? AppColors.info : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              tempText,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatAltitude(dynamic alt) {
    if (alt is num) {
      final ft = alt.toInt();
      if (ft >= 1000) {
        return '${(ft / 1000).toStringAsFixed(0)},000';
      }
      return '$ft';
    }
    return '$alt';
  }
}

class _PlaceholderView extends StatelessWidget {
  final String label;
  const _PlaceholderView({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
