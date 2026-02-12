import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/features/maps/layers/geojson_enrichment.dart';

void main() {
  // ── Advisory enrichment ───────────────────────────────────────────────────

  group('advisoryColorHex', () {
    test('returns specific colors for known hazard types', () {
      expect(advisoryColorHex('IFR'), '#1E90FF');
      expect(advisoryColorHex('TURB'), '#FFC107');
      expect(advisoryColorHex('TURB-HI'), '#FFC107');
      expect(advisoryColorHex('ICE'), '#00BCD4');
      expect(advisoryColorHex('LLWS'), '#FF5252');
      expect(advisoryColorHex('SFC_WND'), '#FF9800');
      expect(advisoryColorHex('CONV'), '#FF5252');
      expect(advisoryColorHex('MTN_OBSC'), '#8D6E63');
      expect(advisoryColorHex('MT_OBSC'), '#8D6E63');
    });

    test('returns default gray for unknown hazard', () {
      expect(advisoryColorHex('UNKNOWN'), '#B0B4BC');
      expect(advisoryColorHex(''), '#B0B4BC');
    });
  });

  group('enrichAdvisoryGeoJson', () {
    test('adds color to features missing it', () {
      final input = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {'type': 'Polygon', 'coordinates': []},
            'properties': {'hazard': 'TURB'},
          },
        ],
      };
      final result = enrichAdvisoryGeoJson(input);
      final props = (result['features'] as List).first['properties'];
      expect(props['color'], '#FFC107');
    });

    test('preserves existing non-empty color', () {
      final input = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {'type': 'Polygon', 'coordinates': []},
            'properties': {'hazard': 'TURB', 'color': '#CUSTOM'},
          },
        ],
      };
      final result = enrichAdvisoryGeoJson(input);
      final props = (result['features'] as List).first['properties'];
      expect(props['color'], '#CUSTOM');
    });

    test('handles empty features list', () {
      final result = enrichAdvisoryGeoJson({
        'type': 'FeatureCollection',
        'features': [],
      });
      expect((result['features'] as List), isEmpty);
    });

    test('handles null features gracefully', () {
      final result = enrichAdvisoryGeoJson({'type': 'FeatureCollection'});
      expect((result['features'] as List), isEmpty);
    });
  });

  // ── PIREP enrichment ──────────────────────────────────────────────────────

  group('pirepSymbolChar', () {
    test('returns open triangle for light turbulence', () {
      expect(pirepSymbolChar('pirep-turb-lgt'), '\u25BD');
    });

    test('returns filled triangle for moderate/severe turbulence', () {
      expect(pirepSymbolChar('pirep-turb-mod'), '\u25BC');
      expect(pirepSymbolChar('pirep-turb-sev'), '\u25BC');
    });

    test('returns open diamond for light icing', () {
      expect(pirepSymbolChar('pirep-ice-lgt'), '\u25C7');
    });

    test('returns filled diamond for moderate/severe icing', () {
      expect(pirepSymbolChar('pirep-ice-mod'), '\u25C6');
      expect(pirepSymbolChar('pirep-ice-sev'), '\u25C6');
    });

    test('returns circle for other types', () {
      expect(pirepSymbolChar('pirep-neg'), '\u25CF');
      expect(pirepSymbolChar('unknown'), '\u25CF');
    });
  });

  group('pirepSymbolColorHex', () {
    test('light intensity is light blue', () {
      expect(pirepSymbolColorHex('pirep-turb-lgt'), '#29B6F6');
      expect(pirepSymbolColorHex('pirep-ice-lgt'), '#29B6F6');
    });

    test('moderate intensity is amber', () {
      expect(pirepSymbolColorHex('pirep-turb-mod'), '#FFC107');
    });

    test('severe intensity is red', () {
      expect(pirepSymbolColorHex('pirep-turb-sev'), '#FF5252');
    });

    test('negative PIREP is green', () {
      expect(pirepSymbolColorHex('pirep-neg'), '#4CAF50');
    });

    test('unknown type is default gray', () {
      expect(pirepSymbolColorHex('something-else'), '#B0B4BC');
    });
  });

  group('enrichPirepGeoJson', () {
    test('adds symbol, color, and isUrgent to each feature', () {
      final input = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [-105.0, 39.0],
            },
            'properties': {
              'airepType': 'PIREP',
              'turbType': 'MOD',
            },
          },
        ],
      };
      final result = enrichPirepGeoJson(input);
      final props = (result['features'] as List).first['properties'];
      expect(props['symbol'], isNotNull);
      expect(props['color'], isNotNull);
      expect(props['isUrgent'], isFalse);
    });

    test('marks urgent PIREPs', () {
      final input = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [-105.0, 39.0],
            },
            'properties': {
              'airepType': 'URGENT PIREP',
            },
          },
        ],
      };
      final result = enrichPirepGeoJson(input);
      final props = (result['features'] as List).first['properties'];
      expect(props['isUrgent'], isTrue);
    });
  });

  // ── METAR overlay ─────────────────────────────────────────────────────────

  group('buildMetarOverlayGeoJson', () {
    Map<String, dynamic> metar({
      num? lat,
      num? lon,
      num? wspd,
      num? wdir,
      num? temp,
      num? visib,
      List<Map<String, dynamic>>? clouds,
    }) =>
        {
          'lat': lat ?? 39.0,
          'lon': lon ?? -105.0,
          if (wspd != null) 'wspd': wspd,
          if (wdir != null) 'wdir': wdir,
          if (temp != null) 'temp': temp,
          if (visib != null) 'visib': visib,
          if (clouds != null) 'clouds': clouds,
        };

    group('surface_wind', () {
      test('calm wind is green', () {
        final result = buildMetarOverlayGeoJson(
          [metar(wspd: 3, wdir: 180)],
          'surface_wind',
        );
        final features = result['features'] as List;
        expect(features, hasLength(1));
        expect(features[0]['properties']['color'], '#4CAF50');
      });

      test('moderate wind is amber', () {
        final result = buildMetarOverlayGeoJson(
          [metar(wspd: 12, wdir: 270)],
          'surface_wind',
        );
        final features = result['features'] as List;
        expect(features[0]['properties']['color'], '#FFC107');
      });

      test('strong wind is orange', () {
        final result = buildMetarOverlayGeoJson(
          [metar(wspd: 22, wdir: 0)],
          'surface_wind',
        );
        final features = result['features'] as List;
        expect(features[0]['properties']['color'], '#FF9800');
      });

      test('very strong wind is red', () {
        final result = buildMetarOverlayGeoJson(
          [metar(wspd: 30, wdir: 90)],
          'surface_wind',
        );
        final features = result['features'] as List;
        expect(features[0]['properties']['color'], '#FF5252');
      });

      test('skips entries with null wind speed', () {
        final result = buildMetarOverlayGeoJson(
          [metar()],
          'surface_wind',
        );
        expect((result['features'] as List), isEmpty);
      });

      test('wind label includes direction arrow', () {
        final result = buildMetarOverlayGeoJson(
          [metar(wspd: 10, wdir: 0)], // North wind → arrow points south ↓
          'surface_wind',
        );
        final label =
            (result['features'] as List)[0]['properties']['label'] as String;
        expect(label, contains('10'));
        // North wind (0°) + 180° = 180° → ↓
        expect(label, contains('↓'));
      });
    });

    group('temperature', () {
      test('freezing temperatures are blue', () {
        final result = buildMetarOverlayGeoJson(
          [metar(temp: -5)],
          'temperature',
        );
        final features = result['features'] as List;
        expect(features[0]['properties']['color'], '#2196F3');
        expect(features[0]['properties']['label'], '-5°');
      });

      test('hot temperatures are red', () {
        final result = buildMetarOverlayGeoJson(
          [metar(temp: 35)],
          'temperature',
        );
        final features = result['features'] as List;
        expect(features[0]['properties']['color'], '#FF5252');
      });
    });

    group('visibility', () {
      test('low visibility is magenta', () {
        final result = buildMetarOverlayGeoJson(
          [metar(visib: 0.5)],
          'visibility',
        );
        final features = result['features'] as List;
        expect(features[0]['properties']['color'], '#E040FB');
      });

      test('good visibility is green', () {
        final result = buildMetarOverlayGeoJson(
          [metar(visib: 10)],
          'visibility',
        );
        final features = result['features'] as List;
        expect(features[0]['properties']['color'], '#4CAF50');
        expect(features[0]['properties']['label'], '10+');
      });
    });

    group('ceiling', () {
      test('low ceiling is magenta', () {
        final result = buildMetarOverlayGeoJson(
          [metar(clouds: [{'cover': 'OVC', 'base': 200}])],
          'ceiling',
        );
        final features = result['features'] as List;
        expect(features[0]['properties']['color'], '#E040FB');
      });

      test('high ceiling is green', () {
        final result = buildMetarOverlayGeoJson(
          [metar(clouds: [{'cover': 'BKN', 'base': 5000}])],
          'ceiling',
        );
        final features = result['features'] as List;
        expect(features[0]['properties']['color'], '#4CAF50');
      });

      test('ignores SCT/FEW layers (not a ceiling)', () {
        final result = buildMetarOverlayGeoJson(
          [metar(clouds: [{'cover': 'FEW', 'base': 200}])],
          'ceiling',
        );
        expect((result['features'] as List), isEmpty);
      });

      test('picks lowest BKN/OVC layer', () {
        final result = buildMetarOverlayGeoJson(
          [
            metar(clouds: [
              {'cover': 'BKN', 'base': 5000},
              {'cover': 'OVC', 'base': 800},
            ])
          ],
          'ceiling',
        );
        final features = result['features'] as List;
        // 800ft → red (< 1000)
        expect(features[0]['properties']['color'], '#FF5252');
        expect(features[0]['properties']['label'], '800');
      });
    });

    test('skips entries with missing lat/lon', () {
      final result = buildMetarOverlayGeoJson(
        [{'wspd': 10}],
        'surface_wind',
      );
      expect((result['features'] as List), isEmpty);
    });

    test('handles string numeric values', () {
      final result = buildMetarOverlayGeoJson(
        [
          {'lat': 39.0, 'lon': -105.0, 'wspd': '15', 'wdir': '180'}
        ],
        'surface_wind',
      );
      final features = result['features'] as List;
      expect(features, hasLength(1));
    });
  });

  // ── Navaid / Fix → GeoJSON ────────────────────────────────────────────────

  group('navaidsToGeoJson', () {
    test('converts navaid list to FeatureCollection', () {
      final result = navaidsToGeoJson([
        {
          'identifier': 'DEN',
          'name': 'Denver',
          'type': 'VOR',
          'frequency': '117.9',
          'latitude': 39.8,
          'longitude': -104.9,
        },
      ]);
      expect(result['type'], 'FeatureCollection');
      final features = result['features'] as List;
      expect(features, hasLength(1));
      expect(features[0]['properties']['identifier'], 'DEN');
      expect(features[0]['properties']['navType'], 'VOR');
      expect(features[0]['geometry']['coordinates'], [-104.9, 39.8]);
    });

    test('skips entries without coordinates', () {
      final result = navaidsToGeoJson([
        {'identifier': 'DEN', 'name': 'Denver'},
      ]);
      expect((result['features'] as List), isEmpty);
    });
  });

  group('fixesToGeoJson', () {
    test('converts fix list to FeatureCollection', () {
      final result = fixesToGeoJson([
        {'identifier': 'TOMSN', 'latitude': 39.5, 'longitude': -105.1},
      ]);
      expect(result['type'], 'FeatureCollection');
      final features = result['features'] as List;
      expect(features, hasLength(1));
      expect(features[0]['properties']['identifier'], 'TOMSN');
    });

    test('skips entries without coordinates', () {
      final result = fixesToGeoJson([
        {'identifier': 'TOMSN'},
      ]);
      expect((result['features'] as List), isEmpty);
    });
  });

  // ── extractFeatures ────────────────────────────────────────────────────────

  group('extractFeatures', () {
    test('extracts features from valid FeatureCollection', () {
      final features = extractFeatures({
        'type': 'FeatureCollection',
        'features': [1, 2, 3],
      });
      expect(features, [1, 2, 3]);
    });

    test('returns null for null input', () {
      expect(extractFeatures(null), isNull);
    });

    test('returns null when features key is missing', () {
      expect(extractFeatures({'type': 'FeatureCollection'}), isNull);
    });
  });
}
