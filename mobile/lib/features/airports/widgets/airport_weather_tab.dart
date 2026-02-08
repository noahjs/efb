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
                _PlaceholderView(label: 'Daily forecast coming soon'),
                _PlaceholderView(label: 'Winds aloft coming soon'),
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
      data: (taf) {
        if (taf == null) {
          return const Center(
            child: Text(
              'No TAF available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final rawTaf = taf['rawTAF'] as String? ?? '';
        final fcsts = taf['fcsts'] as List<dynamic>? ?? [];

        return ListView(
          children: [
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
                  'Valid ${_formatTime(taf['validTimeFrom'])} – ${_formatTime(taf['validTimeTo'])}',
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

    String timeRange = '';
    if (timeFrom != null) {
      timeRange = _formatTime(timeFrom);
      if (timeTo != null) {
        timeRange += ' – ${_formatTime(timeTo)}';
      }
    }

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
          Text(
            timeRange,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic time) {
    if (time is String) {
      final dt = DateTime.tryParse(time);
      if (dt != null) {
        final day = dt.day.toString().padLeft(2, '0');
        final hour = dt.hour.toString().padLeft(2, '0');
        final min = dt.minute.toString().padLeft(2, '0');
        return '${day}d $hour:${min}Z';
      }
      return time;
    }
    return time?.toString() ?? '';
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
