import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/features/maps/config/declutter_config.dart';
import 'package:efb_mobile/features/maps/layers/geojson_enrichment.dart';
import 'package:efb_mobile/features/maps/providers/layer_data_providers.dart';

void main() {
  // ── DeclutterConfig sanity checks ────────────────────────────────────────

  group('DeclutterConfig', () {
    test('airport zoom tiers are in ascending order', () {
      expect(DeclutterConfig.airportZoomToweredHard,
          lessThan(DeclutterConfig.airportZoomHardPublic));
      expect(DeclutterConfig.airportZoomHardPublic,
          lessThan(DeclutterConfig.airportZoomSoftHeliSea));
      expect(DeclutterConfig.airportZoomSoftHeliSea,
          lessThanOrEqualTo(DeclutterConfig.airportZoomOther));
    });

    test('staleness thresholds are in ascending order', () {
      expect(DeclutterConfig.stalenessAgingMinutes,
          lessThan(DeclutterConfig.stalenessStaleMinutes));
    });

    test('staleness opacities decrease with age', () {
      expect(DeclutterConfig.stalenessFreshOpacity,
          greaterThan(DeclutterConfig.stalenessAgingOpacity));
      expect(DeclutterConfig.stalenessAgingOpacity,
          greaterThan(DeclutterConfig.stalenessStaleOpacity));
    });

    test('airspace relevant opacity is greater than irrelevant', () {
      expect(DeclutterConfig.airspaceRelevantOpacity,
          greaterThan(DeclutterConfig.airspaceIrrelevantOpacity));
    });

    test('all opacity values are between 0 and 1', () {
      for (final v in [
        DeclutterConfig.stalenessFreshOpacity,
        DeclutterConfig.stalenessAgingOpacity,
        DeclutterConfig.stalenessStaleOpacity,
        DeclutterConfig.airspaceRelevantOpacity,
        DeclutterConfig.airspaceIrrelevantOpacity,
        DeclutterConfig.airspaceBaseFillOpacity,
        DeclutterConfig.airspaceBaseBorderOpacity,
      ]) {
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThanOrEqualTo(1.0));
      }
    });
  });

  // ── Airport zoom visibility ──────────────────────────────────────────────

  group('airportVisibleAtZoom', () {
    Map<String, dynamic> airport({
      String facilityType = 'A',
      String facilityUse = 'PU',
      bool hasTower = false,
      bool hasHard = false,
    }) =>
        {
          'facility_type': facilityType,
          'facility_use': facilityUse,
          'has_tower': hasTower,
          'has_hard_surface': hasHard,
        };

    test('tier 1: towered hard-surface visible at zoom 5', () {
      final apt = airport(hasTower: true, hasHard: true);
      expect(airportVisibleAtZoom(apt, 5.0), isTrue);
      expect(airportVisibleAtZoom(apt, 4.9), isFalse);
    });

    test('tier 2: non-towered hard-surface public visible at zoom 7', () {
      final apt = airport(hasHard: true, facilityUse: 'PU', facilityType: 'A');
      expect(airportVisibleAtZoom(apt, 7.0), isTrue);
      expect(airportVisibleAtZoom(apt, 6.9), isFalse);
    });

    test('tier 3: heliport visible at zoom 9', () {
      final apt = airport(facilityType: 'H');
      expect(airportVisibleAtZoom(apt, 9.0), isTrue);
      expect(airportVisibleAtZoom(apt, 8.9), isFalse);
    });

    test('tier 3: seaplane base visible at zoom 9', () {
      final apt = airport(facilityType: 'S');
      expect(airportVisibleAtZoom(apt, 9.0), isTrue);
      expect(airportVisibleAtZoom(apt, 8.9), isFalse);
    });

    test('tier 3: soft-surface airport visible at zoom 9', () {
      final apt = airport(hasHard: false, facilityType: 'A');
      expect(airportVisibleAtZoom(apt, 9.0), isTrue);
      expect(airportVisibleAtZoom(apt, 8.9), isFalse);
    });

    test('tier 4: private hard-surface airport visible at zoom 10', () {
      final apt = airport(hasHard: true, facilityUse: 'PR', facilityType: 'A');
      // Not towered, hard surface, but private — doesn't match tier 2 (PU only)
      // Falls through to tier 4
      expect(airportVisibleAtZoom(apt, 10.0), isTrue);
      expect(airportVisibleAtZoom(apt, 9.9), isFalse);
    });

    test('high zoom shows all airport types', () {
      final types = [
        airport(hasTower: true, hasHard: true),
        airport(hasHard: true),
        airport(facilityType: 'H'),
        airport(facilityType: 'S'),
        airport(hasHard: false),
        airport(hasHard: true, facilityUse: 'PR'),
      ];
      for (final apt in types) {
        expect(airportVisibleAtZoom(apt, 12.0), isTrue,
            reason: 'All airports should be visible at zoom 12');
      }
    });

    test('very low zoom hides all airports', () {
      final types = [
        airport(hasTower: true, hasHard: true),
        airport(hasHard: true),
        airport(facilityType: 'H'),
      ];
      for (final apt in types) {
        expect(airportVisibleAtZoom(apt, 3.0), isFalse,
            reason: 'No airports should be visible at zoom 3');
      }
    });

    test('handles missing fields with defaults', () {
      // Empty map should use defaults (type=A, use=PU, no tower, no hard)
      // Soft-surface public airport → tier 3
      expect(airportVisibleAtZoom({}, 9.0), isTrue);
      expect(airportVisibleAtZoom({}, 8.9), isFalse);
    });
  });

  // ── computeStaleness ─────────────────────────────────────────────────────

  group('computeStaleness', () {
    test('fresh observation returns full opacity', () {
      final now = DateTime.now().toUtc();
      expect(
        computeStaleness({'reportTime': now.toIso8601String()}),
        DeclutterConfig.stalenessFreshOpacity,
      );
    });

    test('30-minute old observation returns full opacity', () {
      final obs = DateTime.now().toUtc().subtract(const Duration(minutes: 30));
      expect(
        computeStaleness({'reportTime': obs.toIso8601String()}),
        DeclutterConfig.stalenessFreshOpacity,
      );
    });

    test('90-minute old observation returns aging opacity', () {
      final obs = DateTime.now().toUtc().subtract(const Duration(minutes: 90));
      expect(
        computeStaleness({'reportTime': obs.toIso8601String()}),
        DeclutterConfig.stalenessAgingOpacity,
      );
    });

    test('3-hour old observation returns stale opacity', () {
      final obs = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      expect(
        computeStaleness({'reportTime': obs.toIso8601String()}),
        DeclutterConfig.stalenessStaleOpacity,
      );
    });

    test('uses obsTime string as fallback', () {
      final obs = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      expect(
        computeStaleness({'obsTime': obs.toIso8601String()}),
        DeclutterConfig.stalenessStaleOpacity,
      );
    });

    test('uses obsTime as epoch seconds', () {
      final obs = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      final epoch = obs.millisecondsSinceEpoch ~/ 1000;
      expect(
        computeStaleness({'obsTime': epoch}),
        DeclutterConfig.stalenessStaleOpacity,
      );
    });

    test('missing time data returns fresh opacity', () {
      expect(computeStaleness({}), DeclutterConfig.stalenessFreshOpacity);
    });

    test('reportTime takes precedence over obsTime', () {
      final fresh = DateTime.now().toUtc();
      final stale =
          DateTime.now().toUtc().subtract(const Duration(hours: 3));
      expect(
        computeStaleness({
          'reportTime': fresh.toIso8601String(),
          'obsTime': stale.toIso8601String(),
        }),
        DeclutterConfig.stalenessFreshOpacity,
      );
    });

    test('exactly at aging boundary returns aging opacity', () {
      // At exactly 61 minutes → aging
      final obs = DateTime.now().toUtc().subtract(const Duration(minutes: 61));
      expect(
        computeStaleness({'reportTime': obs.toIso8601String()}),
        DeclutterConfig.stalenessAgingOpacity,
      );
    });

    test('exactly at stale boundary returns stale opacity', () {
      // At exactly 121 minutes → stale
      final obs = DateTime.now().toUtc().subtract(const Duration(minutes: 121));
      expect(
        computeStaleness({'reportTime': obs.toIso8601String()}),
        DeclutterConfig.stalenessStaleOpacity,
      );
    });
  });

  // ── METAR overlay staleness integration ──────────────────────────────────

  group('buildMetarOverlayGeoJson staleness', () {
    test('fresh METAR includes staleness 1.0', () {
      final now = DateTime.now().toUtc();
      final result = buildMetarOverlayGeoJson(
        [
          {
            'lat': 39.0,
            'lon': -105.0,
            'wspd': 10,
            'wdir': 180,
            'reportTime': now.toIso8601String(),
          }
        ],
        'surface_wind',
      );
      final features = result['features'] as List;
      expect(features, hasLength(1));
      expect(features[0]['properties']['staleness'], 1.0);
    });

    test('stale METAR includes reduced staleness', () {
      final old =
          DateTime.now().toUtc().subtract(const Duration(hours: 3));
      final result = buildMetarOverlayGeoJson(
        [
          {
            'lat': 39.0,
            'lon': -105.0,
            'wspd': 10,
            'wdir': 180,
            'reportTime': old.toIso8601String(),
          }
        ],
        'surface_wind',
      );
      final features = result['features'] as List;
      expect(features[0]['properties']['staleness'],
          DeclutterConfig.stalenessStaleOpacity);
    });
  });

  // ── PIREP enrichment staleness ───────────────────────────────────────────

  group('enrichPirepGeoJson staleness', () {
    test('adds staleness property to PIREPs', () {
      final now = DateTime.now().toUtc();
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
              'obsTime': now.toIso8601String(),
            },
          },
        ],
      };
      final result = enrichPirepGeoJson(input);
      final props = (result['features'] as List).first['properties'];
      expect(props['staleness'], isNotNull);
      expect(props['staleness'], DeclutterConfig.stalenessFreshOpacity);
    });

    test('old PIREP gets reduced staleness', () {
      final old =
          DateTime.now().toUtc().subtract(const Duration(minutes: 90));
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
              'reportTime': old.toIso8601String(),
            },
          },
        ],
      };
      final result = enrichPirepGeoJson(input);
      final props = (result['features'] as List).first['properties'];
      expect(props['staleness'], DeclutterConfig.stalenessAgingOpacity);
    });
  });

  // ── Airspace altitude relevance ──────────────────────────────────────────

  group('enrichAirspaceRelevance', () {
    Map<String, dynamic> airspace({int? lower, int? upper}) => {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Polygon',
                'coordinates': [
                  [
                    [-105.0, 39.0],
                    [-104.0, 39.0],
                    [-104.0, 40.0],
                    [-105.0, 39.0],
                  ]
                ],
              },
              'properties': {
                'name': 'Test Airspace',
                if (lower != null) 'lower_alt': lower,
                if (upper != null) 'upper_alt': upper,
              },
            },
          ],
        };

    test('returns original when cruiseAltitude is null', () {
      final input = airspace(lower: 0, upper: 10000);
      final result = enrichAirspaceRelevance(input, null);
      expect(identical(result, input), isTrue);
    });

    test('relevant airspace gets full opacity', () {
      // Airspace 0–10000, cruise at 8000 → clearly inside
      final result = enrichAirspaceRelevance(airspace(lower: 0, upper: 10000), 8000);
      final props = (result['features'] as List).first['properties'];
      expect(props['altOpacity'], DeclutterConfig.airspaceRelevantOpacity);
    });

    test('irrelevant airspace gets reduced opacity', () {
      // Airspace 18000–60000 (Class A), cruise at 8000 → way below
      final result =
          enrichAirspaceRelevance(airspace(lower: 18000, upper: 60000), 8000);
      final props = (result['features'] as List).first['properties'];
      expect(props['altOpacity'], DeclutterConfig.airspaceIrrelevantOpacity);
    });

    test('airspace near cruise altitude within buffer is relevant', () {
      // Airspace 9000–10000, cruise at 8000
      // 8000 >= (9000 - 1000) = 8000 → relevant
      final result = enrichAirspaceRelevance(airspace(lower: 9000, upper: 10000), 8000);
      final props = (result['features'] as List).first['properties'];
      expect(props['altOpacity'], DeclutterConfig.airspaceRelevantOpacity);
    });

    test('airspace just outside buffer is irrelevant', () {
      // Airspace 10000–12000, cruise at 8000
      // 8000 >= (10000 - 1000) = 9000? No → irrelevant
      final result =
          enrichAirspaceRelevance(airspace(lower: 10000, upper: 12000), 8000);
      final props = (result['features'] as List).first['properties'];
      expect(props['altOpacity'], DeclutterConfig.airspaceIrrelevantOpacity);
    });

    test('surface airspace (missing altitudes) gets full opacity', () {
      final result = enrichAirspaceRelevance(airspace(), 8000);
      final props = (result['features'] as List).first['properties'];
      expect(props['altOpacity'], DeclutterConfig.airspaceRelevantOpacity);
    });

    test('partially missing altitude gets full opacity', () {
      // Only lower_alt set, no upper_alt
      final result = enrichAirspaceRelevance(airspace(lower: 0), 8000);
      final props = (result['features'] as List).first['properties'];
      expect(props['altOpacity'], DeclutterConfig.airspaceRelevantOpacity);
    });

    test('handles empty features list', () {
      final input = {'type': 'FeatureCollection', 'features': <dynamic>[]};
      final result = enrichAirspaceRelevance(input, 8000);
      expect((result['features'] as List), isEmpty);
    });

    test('handles null features', () {
      final input = <String, dynamic>{'type': 'FeatureCollection'};
      final result = enrichAirspaceRelevance(input, 8000);
      expect((result['features'] as List), isEmpty);
    });

    test('multiple features get individual altOpacity', () {
      final input = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {'type': 'Polygon', 'coordinates': []},
            'properties': {'lower_alt': 0, 'upper_alt': 10000},
          },
          {
            'type': 'Feature',
            'geometry': {'type': 'Polygon', 'coordinates': []},
            'properties': {'lower_alt': 18000, 'upper_alt': 60000},
          },
        ],
      };
      final result = enrichAirspaceRelevance(input, 8000);
      final features = result['features'] as List;
      expect(features[0]['properties']['altOpacity'],
          DeclutterConfig.airspaceRelevantOpacity);
      expect(features[1]['properties']['altOpacity'],
          DeclutterConfig.airspaceIrrelevantOpacity);
    });

    test('cruise altitude at upper bound + buffer is relevant', () {
      // Airspace 5000–7000, cruise at 8000
      // 8000 <= (7000 + 1000) = 8000 → relevant (boundary)
      final result = enrichAirspaceRelevance(airspace(lower: 5000, upper: 7000), 8000);
      final props = (result['features'] as List).first['properties'];
      expect(props['altOpacity'], DeclutterConfig.airspaceRelevantOpacity);
    });

    test('cruise altitude above upper bound + buffer is irrelevant', () {
      // Airspace 2000–4000, cruise at 8000
      // 8000 <= (4000 + 1000) = 5000? No → irrelevant
      final result =
          enrichAirspaceRelevance(airspace(lower: 2000, upper: 4000), 8000);
      final props = (result['features'] as List).first['properties'];
      expect(props['altOpacity'], DeclutterConfig.airspaceIrrelevantOpacity);
    });
  });
}
