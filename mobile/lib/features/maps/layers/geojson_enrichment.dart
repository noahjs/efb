import '../config/declutter_config.dart';
import '../../imagery/widgets/pirep_symbols.dart';

// ── Staleness computation ────────────────────────────────────────────────────

/// Computes an opacity value (0.0–1.0) based on observation age.
/// Used for METARs, PIREPs, and flight category dots.
double computeStaleness(Map<dynamic, dynamic> data) {
  DateTime? obs;
  final rt = data['reportTime'];
  final ot = data['obsTime'];
  if (rt is String) obs = DateTime.tryParse(rt);
  obs ??= (ot is String) ? DateTime.tryParse(ot) : null;
  if (obs == null && ot is num) {
    obs = DateTime.fromMillisecondsSinceEpoch(ot.toInt() * 1000, isUtc: true);
  }
  if (obs == null) return DeclutterConfig.stalenessFreshOpacity;
  final age = DateTime.now().toUtc().difference(obs).inMinutes;
  if (age > DeclutterConfig.stalenessStaleMinutes) return DeclutterConfig.stalenessStaleOpacity;
  if (age > DeclutterConfig.stalenessAgingMinutes) return DeclutterConfig.stalenessAgingOpacity;
  return DeclutterConfig.stalenessFreshOpacity;
}

// ── Advisory enrichment ─────────────────────────────────────────────────────

/// Tags each advisory feature with a `color` property based on its hazard type.
Map<String, dynamic> enrichAdvisoryGeoJson(Map<String, dynamic> original) {
  final features = (original['features'] as List<dynamic>?) ?? [];
  final enrichedFeatures = features.map((f) {
    final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
    final props =
        Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
    if (props['color'] == null || props['color'] == '') {
      final hazard = (props['hazard'] as String? ?? '').toUpperCase();
      props['color'] = advisoryColorHex(hazard);
    }
    feature['properties'] = props;
    return feature;
  }).toList();
  return {'type': 'FeatureCollection', 'features': enrichedFeatures};
}

String advisoryColorHex(String hazard) {
  switch (hazard) {
    case 'IFR': return '#1E90FF';
    case 'MTN_OBSC': case 'MT_OBSC': return '#8D6E63';
    case 'TURB': case 'TURB-HI': case 'TURB-LO': return '#FFC107';
    case 'ICE': return '#00BCD4';
    case 'FZLVL': case 'M_FZLVL': return '#00BCD4';
    case 'LLWS': return '#FF5252';
    case 'SFC_WND': return '#FF9800';
    case 'CONV': return '#FF5252';
    default: return '#B0B4BC';
  }
}

// ── PIREP enrichment ────────────────────────────────────────────────────────

/// Tags each PIREP feature with `symbol`, `color`, and `isUrgent` properties.
Map<String, dynamic> enrichPirepGeoJson(Map<String, dynamic> original) {
  final features = (original['features'] as List<dynamic>?) ?? [];
  final enrichedFeatures = features.map((f) {
    final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
    final props =
        Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
    final airepType = props['airepType'] as String? ?? '';
    final iconName = pirepIconName(props);
    props['symbol'] = pirepSymbolChar(iconName);
    props['color'] = pirepSymbolColorHex(iconName);
    props['isUrgent'] = airepType == 'URGENT PIREP';
    props['staleness'] = computeStaleness(props);
    feature['properties'] = props;
    return feature;
  }).toList();
  return {'type': 'FeatureCollection', 'features': enrichedFeatures};
}

String pirepSymbolChar(String iconName) {
  if (iconName.contains('turb')) {
    return iconName.endsWith('-lgt') ? '\u25BD' : '\u25BC'; // ▽ or ▼
  }
  if (iconName.contains('ice')) {
    return iconName.endsWith('-lgt') ? '\u25C7' : '\u25C6'; // ◇ or ◆
  }
  return '\u25CF'; // ●
}

String pirepSymbolColorHex(String iconName) {
  if (iconName.endsWith('-lgt')) return '#29B6F6';
  if (iconName.endsWith('-mod')) return '#FFC107';
  if (iconName.endsWith('-sev')) return '#FF5252';
  if (iconName == 'pirep-neg') return '#4CAF50';
  return '#B0B4BC';
}

// ── METAR overlay (surface wind, temperature, visibility, ceiling) ──────────

/// Builds a GeoJSON FeatureCollection of colored/labelled dots for the given
/// METAR overlay type.
Map<String, dynamic> buildMetarOverlayGeoJson(
  List<dynamic> metars,
  String overlayType,
) {
  final features = <Map<String, dynamic>>[];
  for (final m in metars) {
    if (m is! Map) continue;
    final lat = m['lat'] as num?;
    final lng = m['lon'] as num?;
    if (lat == null || lng == null) continue;

    String? color;
    String? label;

    switch (overlayType) {
      case 'surface_wind':
        final rawWspd = m['wspd'];
        final wspd = (rawWspd is num)
            ? rawWspd.toDouble()
            : (rawWspd is String)
                ? double.tryParse(rawWspd)
                : null;
        if (wspd == null) continue;
        final wdir = m['wdir'];
        final dirNum = (wdir is num) ? wdir.toDouble() : null;
        var arrow = '';
        if (dirNum != null && wspd > 0) {
          const arrows = ['↑', '↗', '→', '↘', '↓', '↙', '←', '↖'];
          final downwind = (dirNum + 180) % 360;
          arrow = '${arrows[((downwind + 22.5) % 360 ~/ 45)]} ';
        }
        label = '$arrow${wspd.toInt()}';
        if (wspd <= 5) {
          color = '#4CAF50';
        } else if (wspd <= 15) {
          color = '#FFC107';
        } else if (wspd <= 25) {
          color = '#FF9800';
        } else {
          color = '#FF5252';
        }
        break;
      case 'temperature':
        final rawTemp = m['temp'];
        final temp = (rawTemp is num)
            ? rawTemp.toDouble()
            : (rawTemp is String)
                ? double.tryParse(rawTemp)
                : null;
        if (temp == null) continue;
        label = '${temp.toInt()}°';
        if (temp <= 0) {
          color = '#2196F3';
        } else if (temp <= 10) {
          color = '#29B6F6';
        } else if (temp <= 20) {
          color = '#4CAF50';
        } else if (temp <= 30) {
          color = '#FFC107';
        } else {
          color = '#FF5252';
        }
        break;
      case 'visibility':
        final rawVisib = m['visib'];
        final visib = (rawVisib is num)
            ? rawVisib.toDouble()
            : (rawVisib is String)
                ? double.tryParse(rawVisib.replaceAll('+', ''))
                : null;
        if (visib == null) continue;
        label =
            visib >= 10 ? '10+' : visib.toStringAsFixed(visib < 3 ? 1 : 0);
        if (visib < 1) {
          color = '#E040FB';
        } else if (visib < 3) {
          color = '#FF5252';
        } else if (visib < 5) {
          color = '#FFC107';
        } else {
          color = '#4CAF50';
        }
        break;
      case 'ceiling':
        final clouds = m['clouds'] as List<dynamic>?;
        if (clouds == null || clouds.isEmpty) continue;
        int? cig;
        for (final c in clouds) {
          if (c is Map) {
            final cover = (c['cover'] as String? ?? '').toUpperCase();
            if (cover == 'BKN' || cover == 'OVC') {
              final rawBase = c['base'];
              final base = (rawBase is num)
                  ? rawBase.toInt()
                  : (rawBase is String)
                      ? int.tryParse(rawBase)
                      : null;
              if (base != null && (cig == null || base < cig)) {
                cig = base.toInt();
              }
            }
          }
        }
        if (cig == null) continue;
        label = '$cig';
        if (cig < 500) {
          color = '#E040FB';
        } else if (cig < 1000) {
          color = '#FF5252';
        } else if (cig < 3000) {
          color = '#FFC107';
        } else {
          color = '#4CAF50';
        }
        break;
    }

    if (color == null) continue;
    features.add({
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [lng, lat],
      },
      'properties': {
        'color': color,
        'label': label ?? '',
        'staleness': computeStaleness(m),
      },
    });
  }
  return {'type': 'FeatureCollection', 'features': features};
}

// ── Navaid / Fix → GeoJSON ──────────────────────────────────────────────────

Map<String, dynamic> navaidsToGeoJson(List<dynamic> navaids) {
  final features = navaids
      .where((n) => n['latitude'] != null && n['longitude'] != null)
      .map((n) => {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [n['longitude'], n['latitude']],
            },
            'properties': {
              'identifier': n['identifier'] ?? '',
              'name': n['name'] ?? '',
              'navType': n['type'] ?? '',
              'frequency': n['frequency'] ?? '',
            },
          })
      .toList();
  return {'type': 'FeatureCollection', 'features': features};
}

Map<String, dynamic> fixesToGeoJson(List<dynamic> fixes) {
  final features = fixes
      .where((f) => f['latitude'] != null && f['longitude'] != null)
      .map((f) => {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [f['longitude'], f['latitude']],
            },
            'properties': {
              'identifier': f['identifier'] ?? '',
            },
          })
      .toList();
  return {'type': 'FeatureCollection', 'features': features};
}

// ── Storm Cell enrichment ────────────────────────────────────────────────────

/// Tags each storm cell feature with a `color` property based on its trait.
Map<String, dynamic> enrichStormCellGeoJson(Map<String, dynamic> original) {
  final features = (original['features'] as List<dynamic>?) ?? [];
  final enrichedFeatures = features.map((f) {
    final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
    final props =
        Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
    final trait = (props['trait'] as String? ?? '').toLowerCase();
    props['color'] = switch (trait) {
      'tornado' => '#FF1744',
      'rotating' => '#FF9100',
      'hail' => '#FFEA00',
      _ => '#FFC107',
    };
    // Symbol char for cell points
    final featureType = props['featureType'] as String? ?? '';
    if (featureType == 'cell') {
      props['symbol'] = switch (trait) {
        'tornado' => '\u26A0',  // ⚠
        'rotating' => '\u21BB', // ↻
        'hail' => '\u25C6',     // ◆
        _ => '\u25CF',          // ●
      };
    }
    feature['properties'] = props;
    return feature;
  }).toList();
  return {'type': 'FeatureCollection', 'features': enrichedFeatures};
}

// ── Lightning enrichment ─────────────────────────────────────────────────────

/// Tags each lightning feature with a `color` property.
Map<String, dynamic> enrichLightningGeoJson(Map<String, dynamic> original) {
  final features = (original['features'] as List<dynamic>?) ?? [];
  final enrichedFeatures = features.map((f) {
    final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
    final props =
        Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
    final featureType = props['featureType'] as String? ?? '';
    props['color'] = featureType == 'path' ? '#FF9100' : '#FFD600';
    feature['properties'] = props;
    return feature;
  }).toList();
  return {'type': 'FeatureCollection', 'features': enrichedFeatures};
}

// ── Weather Alert enrichment ────────────────────────────────────────────────

/// Tags each weather alert feature with a `color` property based on severity.
Map<String, dynamic> enrichWeatherAlertGeoJson(Map<String, dynamic> original) {
  final features = (original['features'] as List<dynamic>?) ?? [];
  final enrichedFeatures = features.map((f) {
    final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
    final props =
        Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
    final severity = (props['severity'] as String? ?? '').toLowerCase();
    props['color'] = switch (severity) {
      'extreme' => '#FF1744',
      'severe' => '#FF5252',
      'moderate' => '#FF9800',
      'minor' => '#FFC107',
      _ => '#B0B4BC',
    };
    feature['properties'] = props;
    return feature;
  }).toList();
  return {'type': 'FeatureCollection', 'features': enrichedFeatures};
}

// ── Airspace altitude relevance ──────────────────────────────────────────────

/// Enriches airspace GeoJSON with an `altOpacity` property based on how
/// relevant each airspace is to the given [cruiseAltitude].
/// If [cruiseAltitude] is null, all airspaces get full opacity.
Map<String, dynamic> enrichAirspaceRelevance(
  Map<String, dynamic> geojson,
  int? cruiseAltitude,
) {
  if (cruiseAltitude == null) return geojson;
  final features = (geojson['features'] as List?) ?? [];
  return {
    'type': 'FeatureCollection',
    'features': features.map((f) {
      final feature = Map<String, dynamic>.from(f as Map);
      final props = Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
      final lower = props['lower_alt'] as int?;
      final upper = props['upper_alt'] as int?;
      if (lower == null || upper == null) {
        props['altOpacity'] = DeclutterConfig.airspaceRelevantOpacity;
      } else {
        final buffer = DeclutterConfig.airspaceAltitudeBuffer;
        final relevant = cruiseAltitude >= (lower - buffer) &&
            cruiseAltitude <= (upper + buffer);
        props['altOpacity'] = relevant
            ? DeclutterConfig.airspaceRelevantOpacity
            : DeclutterConfig.airspaceIrrelevantOpacity;
      }
      feature['properties'] = props;
      return feature;
    }).toList(),
  };
}

/// Extract the features list from a GeoJSON FeatureCollection, or null.
List<dynamic>? extractFeatures(Map<String, dynamic>? geojson) {
  if (geojson == null) return null;
  return geojson['features'] as List<dynamic>?;
}
