import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/features/maps/layers/map_layer_def.dart';
import 'package:efb_mobile/features/maps/layers/map_layer_registry.dart';

void main() {
  group('MapLayerDef.sourceKey', () {
    test('every enum value has a unique sourceKey', () {
      final keys = <String>{};
      for (final id in MapLayerId.values) {
        final def = MapLayerDef(
          id: id,
          displayName: '',
          group: LayerGroup.baseLayer,
        );
        expect(keys.add(def.sourceKey), isTrue,
            reason: 'Duplicate sourceKey: ${def.sourceKey}');
      }
    });

    test('known sourceKeys match expected strings', () {
      expect(
        kLayerById[MapLayerId.dark]!.sourceKey,
        'dark',
      );
      expect(
        kLayerById[MapLayerId.flightCategory]!.sourceKey,
        'flight_category',
      );
      expect(
        kLayerById[MapLayerId.airSigmet]!.sourceKey,
        'air_sigmet',
      );
      expect(
        kLayerById[MapLayerId.windsAloft]!.sourceKey,
        'winds_aloft',
      );
      expect(
        kLayerById[MapLayerId.surfaceWind]!.sourceKey,
        'surface_wind',
      );
    });
  });

  group('kMapLayers registry', () {
    test('every MapLayerId enum value is registered', () {
      for (final id in MapLayerId.values) {
        expect(kLayerById.containsKey(id), isTrue,
            reason: '${id.name} is missing from kMapLayers');
      }
    });

    test('no duplicate IDs in the registry', () {
      final seen = <MapLayerId>{};
      for (final def in kMapLayers) {
        expect(seen.add(def.id), isTrue,
            reason: 'Duplicate ID: ${def.id.name}');
      }
    });

    test('every layer has a non-empty displayName', () {
      for (final def in kMapLayers) {
        expect(def.displayName.isNotEmpty, isTrue,
            reason: '${def.id.name} has empty displayName');
      }
    });
  });

  group('kLayerBySourceKey', () {
    test('round-trips: id → sourceKey → def → id', () {
      for (final id in MapLayerId.values) {
        final sourceKey = kLayerById[id]!.sourceKey;
        final found = kLayerBySourceKey[sourceKey];
        expect(found, isNotNull, reason: 'No def for sourceKey "$sourceKey"');
        expect(found!.id, id);
      }
    });
  });

  group('category helpers', () {
    test('kBaseLayers contains only base layers', () {
      for (final def in kBaseLayers) {
        expect(def.group, LayerGroup.baseLayer);
      }
    });

    test('kBaseLayers has expected entries', () {
      final ids = kBaseLayers.map((d) => d.id).toSet();
      expect(ids, containsAll([
        MapLayerId.dark,
        MapLayerId.vfr,
        MapLayerId.satellite,
        MapLayerId.street,
      ]));
    });

    test('kLeftOverlays contains only left overlays', () {
      for (final def in kLeftOverlays) {
        expect(def.group, LayerGroup.leftOverlay);
      }
    });

    test('kRightOverlays contains only right overlays', () {
      for (final def in kRightOverlays) {
        expect(def.group, LayerGroup.rightOverlay);
      }
    });

    test('all layers are in exactly one category', () {
      final allCategorized = {
        ...kBaseLayers.map((d) => d.id),
        ...kLeftOverlays.map((d) => d.id),
        ...kRightOverlays.map((d) => d.id),
      };
      expect(allCategorized.length, kMapLayers.length,
          reason: 'Some layers appear in multiple categories or are missing');
      for (final id in MapLayerId.values) {
        expect(allCategorized.contains(id), isTrue,
            reason: '${id.name} not in any category');
      }
    });
  });

  group('exclusive groups', () {
    test('weather_derived group has expected members', () {
      final weatherDerived = kExclusiveGroups['weather_derived']!;
      expect(weatherDerived, containsAll([
        MapLayerId.surfaceWind,
        MapLayerId.windsAloft,
        MapLayerId.temperature,
        MapLayerId.visibility,
        MapLayerId.ceiling,
      ]));
      expect(weatherDerived.length, 5);
    });

    test('non-exclusive layers have null exclusiveGroup', () {
      final nonExclusive = [
        MapLayerId.aeronautical,
        MapLayerId.flightCategory,
        MapLayerId.traffic,
        MapLayerId.tfrs,
        MapLayerId.airSigmet,
        MapLayerId.pireps,
      ];
      for (final id in nonExclusive) {
        expect(kLayerById[id]!.exclusiveGroup, isNull,
            reason: '${id.name} should not be in an exclusive group');
      }
    });

    test('base layers are not in any exclusive group', () {
      for (final def in kBaseLayers) {
        expect(def.exclusiveGroup, isNull);
      }
    });
  });

  group('needsBounds', () {
    test('bounds-dependent layers are marked', () {
      final boundsDependentIds = kMapLayers
          .where((d) => d.needsBounds)
          .map((d) => d.id)
          .toSet();
      // Aeronautical, flight category, pireps, and all weather-derived need bounds
      expect(boundsDependentIds, containsAll([
        MapLayerId.aeronautical,
        MapLayerId.flightCategory,
        MapLayerId.pireps,
        MapLayerId.surfaceWind,
        MapLayerId.windsAloft,
        MapLayerId.temperature,
        MapLayerId.visibility,
        MapLayerId.ceiling,
      ]));
    });

    test('base layers do not need bounds', () {
      for (final def in kBaseLayers) {
        expect(def.needsBounds, isFalse);
      }
    });
  });
}
