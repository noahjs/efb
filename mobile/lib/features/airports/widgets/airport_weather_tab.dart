import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/airport_providers.dart';
import '../../../services/api_client.dart';

class AirportWeatherTab extends ConsumerWidget {
  final String airportId;
  const AirportWeatherTab({super.key, required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airportAsync = ref.watch(airportDetailProvider(airportId));
    final hasDatis = airportAsync.whenOrNull(
          data: (airport) => airport?['has_datis'] == true,
        ) ??
        false;
    final hasLiveatc = airportAsync.whenOrNull(
          data: (airport) => airport?['has_liveatc'] == true,
        ) ??
        false;

    final hasAtisCapability = hasDatis || hasLiveatc;

    // Tab name from DB flags — no need to wait for the ATIS data to load.
    // _DatisView handles fetching; the parent just renders the tab immediately.
    final atisTabName = hasDatis ? 'D-ATIS' : 'ATIS';

    final tabs = <Tab>[
      if (hasAtisCapability) Tab(text: atisTabName),
      const Tab(text: 'METAR'),
      const Tab(text: 'TAF'),
      const Tab(text: 'Ai-Fcst'),
      const Tab(text: 'Daily'),
      const Tab(text: 'Winds'),
    ];

    final views = <Widget>[
      if (hasAtisCapability)
        _DatisView(
          airportId: airportId,
          hasDatis: hasDatis,
          hasLiveatc: hasLiveatc,
        ),
      _MetarView(airportId: airportId),
      _TafView(airportId: airportId),
      _PlaceholderView(label: 'Ai-Fcst data coming soon'),
      _DailyForecastView(airportId: airportId),
      _WindsAloftView(airportId: airportId),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: TabBar(
              tabs: tabs,
              isScrollable: false,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              indicatorSize: TabBarIndicatorSize.tab,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: views,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatisView extends ConsumerWidget {
  final String airportId;
  final bool hasDatis;
  final bool hasLiveatc;
  const _DatisView({
    required this.airportId,
    required this.hasDatis,
    required this.hasLiveatc,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datisAsync = ref.watch(datisProvider(airportId));

    return datisAsync.when(
      loading: () => _buildLoadingState(),
      error: (error, _) => Center(
        child: Text(
          hasDatis ? 'Failed to load D-ATIS' : 'Failed to load ATIS',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (atisList) {
        if (atisList == null || atisList.isEmpty) {
          return _buildEmptyState();
        }

        final source =
            (atisList[0] as Map<String, dynamic>)['source'] as String?;
        final isLiveAtc = source == 'liveatc';

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: atisList.length + (isLiveAtc ? 1 : 0),
          itemBuilder: (context, index) {
            if (isLiveAtc && index == 0) {
              return _LiveAtcBanner(airportId: airportId);
            }
            final atisIndex = isLiveAtc ? index - 1 : index;
            final atis = atisList[atisIndex] as Map<String, dynamic>;
            return _DatisCard(atis: atis);
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    // LiveATC transcription takes ~90s — show an informative loading state
    if (!hasDatis && hasLiveatc) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              const Text(
                'Transcribing ATIS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Listening to LiveATC audio and transcribing with AI. This usually takes about 90 seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
    // Tailor the message to the airport's known capabilities
    final String title;
    final String subtitle;
    final IconData icon;

    if (hasDatis) {
      title = 'D-ATIS Temporarily Unavailable';
      subtitle =
          'This airport has Digital ATIS but the service is not responding. Try again shortly.';
      icon = Icons.cloud_off;
    } else if (hasLiveatc) {
      title = 'ATIS Unavailable';
      subtitle =
          'Could not transcribe ATIS from LiveATC. The feed may be offline or the audio was unclear.';
      icon = Icons.mic_off;
    } else {
      title = 'No ATIS Available';
      subtitle =
          'This airport does not have Digital ATIS. Listen on the published ATIS frequency.';
      icon = Icons.speaker_notes_off;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveAtcBanner extends ConsumerWidget {
  final String airportId;
  const _LiveAtcBanner({required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Transcribed from LiveATC audio by AI',
              style: TextStyle(
                color: AppColors.info,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _playAudio(ref),
            child: Icon(
              Icons.play_circle_outline,
              size: 24,
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playAudio(WidgetRef ref) async {
    final api = ref.read(apiClientProvider);
    final url = await api.getAtisAudioUrl(airportId);
    if (url != null) {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _DatisCard extends StatelessWidget {
  final Map<String, dynamic> atis;
  const _DatisCard({required this.atis});

  @override
  Widget build(BuildContext context) {
    final type = atis['type'] as String? ?? 'combined';
    final datisText = atis['datis'] as String? ?? '';

    // Extract ATIS letter from the text (e.g., "ATIS INFO A" or "...INFORMATION ALPHA")
    final letter = _extractAtisLetter(datisText);

    // Determine label for type
    String typeLabel;
    switch (type.toLowerCase()) {
      case 'arr':
        typeLabel = 'ARRIVAL';
      case 'dep':
        typeLabel = 'DEPARTURE';
      default:
        typeLabel = 'ATIS';
    }

    final parsed = _parseAtisFields(datisText);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with ATIS letter and type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                if (letter != null)
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      letter,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                if (letter != null) const SizedBox(width: 10),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(Icons.record_voice_over,
                    size: 16,
                    color: AppColors.primary.withValues(alpha: 0.6)),
              ],
            ),
          ),

          // Parsed fields
          if (parsed.isNotEmpty) ...[
            for (final field in parsed)
              _WeatherField(label: field.label, value: field.value),
            const Divider(height: 1, color: AppColors.divider),
          ],

          // ATIS text
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              datisText,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<_ParsedField> _parseAtisFields(String text) {
    final fields = <_ParsedField>[];
    final upper = text.toUpperCase();

    // Wind: "WND 18007KT" or "WIND 180 AT 7" or "180 AT 7 KNOTS" etc.
    final windMatch = RegExp(
      r'(?:WND|WIND)\s*(\d{3})\s*(?:AT\s*)?(\d+)\s*(?:G(?:UST(?:ING)?)?\s*(\d+))?\s*(?:KT|KTS|KNOTS?)?',
      caseSensitive: false,
    ).firstMatch(upper);
    if (windMatch != null) {
      final dir = windMatch.group(1)!;
      final spd = windMatch.group(2)!;
      final gust = windMatch.group(3);
      var windStr = '$dir\u00B0 at $spd kts';
      if (gust != null) windStr += ' G$gust';
      fields.add(_ParsedField('Wind', windStr));
    }

    // Visibility
    final visMatch = RegExp(
      r'(?:VIS(?:IBILITY)?)\s+([\d]+(?:\s*\/\s*\d+)?(?:\s+\d+\/\d+)?)',
      caseSensitive: false,
    ).firstMatch(upper);
    if (visMatch != null) {
      fields.add(_ParsedField('Visibility', '${visMatch.group(1)!.trim()} sm'));
    }

    // Ceiling / Sky condition
    final skyMatch = RegExp(
      r'(?:CEILING|SKY\s*CONDITION|CIG)\s+(.+?)(?:[,.]|\bTEMP|\bVIS|\bWIND|\bALT)',
      caseSensitive: false,
    ).firstMatch(upper);
    if (skyMatch != null) {
      fields.add(_ParsedField('Ceiling', skyMatch.group(1)!.trim()));
    }

    // Temperature
    final tempMatch = RegExp(
      r'TEMP(?:ERATURE)?\s+([\w\s\-]+?)(?:[,]|\bDEW|\bALT|\bWIND)',
      caseSensitive: false,
    ).firstMatch(upper);
    if (tempMatch != null) {
      fields.add(_ParsedField('Temperature', tempMatch.group(1)!.trim()));
    }

    // Dewpoint
    final dewMatch = RegExp(
      r'DEW\s*POINT\s+([\w\s\-]+?)(?:[,.]|\bALT|\bREM|\bWIND|\bVIS)',
      caseSensitive: false,
    ).firstMatch(upper);
    if (dewMatch != null) {
      fields.add(_ParsedField('Dewpoint', dewMatch.group(1)!.trim()));
    }

    // Altimeter
    final altMatch = RegExp(
      r'ALT(?:IMETER)?\s+([\d]{4}|[\d]{2}[\.\s][\d]{2})',
      caseSensitive: false,
    ).firstMatch(upper);
    if (altMatch != null) {
      var alt = altMatch.group(1)!.trim().replaceAll(' ', '');
      if (alt.length == 4 && !alt.contains('.')) {
        alt = '${alt.substring(0, 2)}.${alt.substring(2)}';
      }
      fields.add(_ParsedField('Altimeter', '$alt inHg'));
    }

    // Runways in use
    final rwyMatches = RegExp(
      r'(?:LANDING|DEPARTING|ARRIV(?:AL|ING))\s+(?:AND\s+DEPARTING\s+)?RUNWAY[S]?\s+([\w\s,/]+?)(?:[,.]|\bEXP|\bNOT|\bBIRD)',
      caseSensitive: false,
    ).allMatches(upper);
    if (rwyMatches.isNotEmpty) {
      final rwys = rwyMatches.map((m) => m.group(1)!.trim()).join(', ');
      fields.add(_ParsedField('Runway(s)', rwys));
    }

    return fields;
  }

  static String? _extractAtisLetter(String text) {
    // Match "ATIS INFO X" or "INFORMATION ALPHA/BRAVO/..." patterns
    final infoMatch =
        RegExp(r'ATIS\s+INFO(?:RMATION)?\s+([A-Z])\b', caseSensitive: false)
            .firstMatch(text);
    if (infoMatch != null) return infoMatch.group(1);

    final informationMatch =
        RegExp(r'INFORMATION\s+([A-Z])\b', caseSensitive: false)
            .firstMatch(text);
    if (informationMatch != null) return informationMatch.group(1);

    // Try phonetic alphabet
    const phoneticToLetter = {
      'ALFA': 'A', 'ALPHA': 'A', 'BRAVO': 'B', 'CHARLIE': 'C',
      'DELTA': 'D', 'ECHO': 'E', 'FOXTROT': 'F', 'GOLF': 'G',
      'HOTEL': 'H', 'INDIA': 'I', 'JULIET': 'J', 'JULIETT': 'J',
      'KILO': 'K', 'LIMA': 'L', 'MIKE': 'M', 'NOVEMBER': 'N',
      'OSCAR': 'O', 'PAPA': 'P', 'QUEBEC': 'Q', 'ROMEO': 'R',
      'SIERRA': 'S', 'TANGO': 'T', 'UNIFORM': 'U', 'VICTOR': 'V',
      'WHISKEY': 'W', 'XRAY': 'X', 'X-RAY': 'X', 'YANKEE': 'Y',
      'ZULU': 'Z',
    };

    final phoneticPattern = phoneticToLetter.keys.join('|');
    final phoneticMatch = RegExp(
      r'INFORMATION\s+(' + phoneticPattern + r')\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (phoneticMatch != null) {
      return phoneticToLetter[phoneticMatch.group(1)!.toUpperCase()];
    }

    return null;
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
      data: (envelope) {
        if (envelope == null) {
          return const Center(
            child: Text(
              'No METAR available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final metar = envelope['metar'] as Map<String, dynamic>?;
        final isNearby = envelope['isNearby'] as bool? ?? false;
        final station = envelope['station'] as String? ?? '';
        final distanceNm = envelope['distanceNm'];
        final awos = envelope['awos'] as Map<String, dynamic>?;

        // No METAR at all (not even nearby) — show AWOS info if available
        if (metar == null) {
          return _NoMetarView(awos: awos);
        }

        final rawOb = metar['rawOb'] as String? ?? '';
        final fltCat = metar['fltCat'] as String? ?? '';
        final catColor = _flightCategoryColor(fltCat);
        final obsTime = _parseObsTime(metar);
        final ageText = obsTime != null ? _formatAge(obsTime) : '';

        return ListView(
          children: [
            // AWOS info banner (shown even when nearby METAR is available)
            if (isNearby && awos != null) _AwosInfoBanner(awos: awos),

            // Nearby station warning — prominent and unmissable
            if (isNearby)
              Container(
                margin: EdgeInsets.fromLTRB(16, awos != null ? 0 : 16, 16, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 20, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'NOT THIS AIRPORT — Showing nearest METAR from $station (${distanceNm} nm away)',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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

class _NoMetarView extends StatelessWidget {
  final Map<String, dynamic>? awos;
  const _NoMetarView({this.awos});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'No METAR Available',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This airport does not report METARs and no nearby station was found.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            if (awos != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cell_tower,
                            size: 18, color: AppColors.info),
                        const SizedBox(width: 8),
                        Text(
                          awos!['name'] as String? ?? 'AWOS',
                          style: TextStyle(
                            color: AppColors.info,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (awos!['frequency'] != null &&
                        (awos!['frequency'] as String).isNotEmpty) ...[
                      Text(
                        'Tune ${awos!['frequency']} MHz',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (awos!['phone'] != null &&
                        (awos!['phone'] as String).isNotEmpty)
                      Text(
                        'Call ${awos!['phone']}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AwosInfoBanner extends StatelessWidget {
  final Map<String, dynamic> awos;
  const _AwosInfoBanner({required this.awos});

  @override
  Widget build(BuildContext context) {
    final name = awos['name'] as String? ?? 'AWOS';
    final frequency = awos['frequency'] as String?;
    final phone = awos['phone'] as String?;

    final parts = <String>[name];
    if (frequency != null && frequency.isNotEmpty) {
      parts.add('$frequency MHz');
    }
    if (phone != null && phone.isNotEmpty) {
      parts.add(phone);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.cell_tower, size: 16, color: AppColors.info),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'This airport has ${parts.join(' — ')}',
              style: TextStyle(
                color: AppColors.info,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedField {
  final String label;
  final String value;
  const _ParsedField(this.label, this.value);
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
  int _selectedTimestampIndex = 0;

  @override
  Widget build(BuildContext context) {
    final windyAsync = ref.watch(windyWindsAloftProvider(widget.airportId));

    return windyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Failed to load winds aloft',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (data) {
        if (data == null) {
          return const Center(
            child: Text(
              'No winds aloft available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final levels = data['levels'] as List<dynamic>? ?? [];
        if (levels.isEmpty) {
          return const Center(
            child: Text(
              'No winds aloft data',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        // Extract timestamps from first level's winds array
        final firstLevelWinds =
            (levels[0] as Map<String, dynamic>)['winds'] as List<dynamic>? ??
                [];
        final timestamps = firstLevelWinds
            .map((w) => (w as Map<String, dynamic>)['timestamp'] as int)
            .toList();

        if (timestamps.isEmpty) {
          return const Center(
            child: Text(
              'No forecast timestamps available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        // Clamp selected index
        if (_selectedTimestampIndex >= timestamps.length) {
          _selectedTimestampIndex = 0;
        }

        // Find closest timestamp to now for default
        final now = DateTime.now().millisecondsSinceEpoch;

        // Filter levels: skip 'surface' and '1000h'
        final filteredLevels = levels.where((l) {
          final level = (l as Map<String, dynamic>)['level'] as String? ?? '';
          return level != 'surface' && level != '1000h';
        }).toList();

        return ListView(
          children: [
            // Forecast time pills
            _buildTimePills(timestamps, now),

            // Table header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surface,
              child: const Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text('ALT',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text('TEMP',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text('WIND',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),

            // Altitude rows
            for (int i = 0; i < filteredLevels.length; i++)
              _buildLevelRow(
                filteredLevels[i] as Map<String, dynamic>,
                i,
              ),

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildTimePills(List<int> timestamps, int nowMs) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: timestamps.length,
        itemBuilder: (context, i) {
          final ts = timestamps[i];
          final diffHours = ((ts - nowMs) / 3600000).round();
          String label;
          if (diffHours <= 0 && diffHours > -1) {
            label = 'Now';
          } else if (diffHours > 0) {
            label = '+${diffHours}h';
          } else {
            label = '${diffHours}h';
          }

          final isSelected = i == _selectedTimestampIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTimestampIndex = i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.divider,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLevelRow(Map<String, dynamic> levelData, int index) {
    final rawAltFt = (levelData['altitudeFt'] as num?)?.toInt() ?? 0;
    // Round to nearest 500 ft for display
    final altitudeFt = ((rawAltFt + 250) ~/ 500) * 500;
    final winds = levelData['winds'] as List<dynamic>? ?? [];

    // Get data for selected timestamp
    Map<String, dynamic>? windEntry;
    if (_selectedTimestampIndex < winds.length) {
      windEntry = winds[_selectedTimestampIndex] as Map<String, dynamic>;
    }

    final direction = (windEntry?['direction'] as num?)?.toInt() ?? 0;
    final speed = (windEntry?['speed'] as num?)?.toInt() ?? 0;
    final temperature = (windEntry?['temperature'] as num?)?.toDouble() ?? 0.0;
    final isaDeviation = (windEntry?['isaDeviation'] as num?)?.toInt() ?? 0;

    final bgColor = index.isEven ? AppColors.surface : AppColors.surfaceLight;

    // Format altitude
    String altText;
    if (altitudeFt >= 18000) {
      altText = 'FL${(altitudeFt / 100).round()}';
    } else {
      altText = _formatNumber(altitudeFt);
    }

    // Format temperature + ISA deviation
    final tempSign = temperature >= 0 ? '+' : '';
    final isaDev = isaDeviation >= 0 ? '+$isaDeviation' : '$isaDeviation';
    final tempText = '$tempSign${temperature.round()}°C (ISA$isaDev)';

    // ISA deviation color
    Color isaColor;
    final absIsa = isaDeviation.abs();
    if (absIsa <= 5) {
      isaColor = AppColors.success;
    } else if (absIsa <= 10) {
      isaColor = AppColors.warning;
    } else {
      isaColor = AppColors.error;
    }

    // Wind text
    final windText = '$direction° at $speed kts';

    // Wind speed color
    Color windColor;
    if (speed < 15) {
      windColor = AppColors.success;
    } else if (speed < 30) {
      windColor = AppColors.warning;
    } else if (speed < 50) {
      windColor = const Color(0xFFFF9800); // orange
    } else {
      windColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: bgColor,
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              altText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              tempText,
              style: TextStyle(
                fontSize: 14,
                color: isaColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              windText,
              style: TextStyle(
                fontSize: 14,
                color: windColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]},',
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
