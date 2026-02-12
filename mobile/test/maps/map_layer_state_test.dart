import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/features/maps/layers/map_layer_def.dart';
import 'package:efb_mobile/features/maps/layers/map_layer_registry.dart';
import 'package:efb_mobile/features/maps/providers/map_layer_state_provider.dart';

void main() {
  group('MapLayerState', () {
    test('defaults', () {
      const state = MapLayerState();
      expect(state.baseLayer, MapLayerId.dark);
      expect(state.activeOverlays, {MapLayerId.flightCategory});
      expect(state.windsAloftAltitude, 9000);
    });

    test('isActive returns true for active overlays', () {
      const state = MapLayerState(
        activeOverlays: {MapLayerId.tfrs, MapLayerId.pireps},
      );
      expect(state.isActive(MapLayerId.tfrs), isTrue);
      expect(state.isActive(MapLayerId.pireps), isTrue);
      expect(state.isActive(MapLayerId.traffic), isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      const original = MapLayerState(
        baseLayer: MapLayerId.vfr,
        activeOverlays: {MapLayerId.traffic},
        windsAloftAltitude: 6000,
      );
      final updated = original.copyWith(baseLayer: MapLayerId.satellite);
      expect(updated.baseLayer, MapLayerId.satellite);
      expect(updated.activeOverlays, {MapLayerId.traffic});
      expect(updated.windsAloftAltitude, 6000);
    });

    test('copyWith replaces specified fields', () {
      const original = MapLayerState();
      final updated = original.copyWith(
        baseLayer: MapLayerId.satellite,
        activeOverlays: {MapLayerId.tfrs, MapLayerId.pireps},
        windsAloftAltitude: 3000,
      );
      expect(updated.baseLayer, MapLayerId.satellite);
      expect(updated.activeOverlays, {MapLayerId.tfrs, MapLayerId.pireps});
      expect(updated.windsAloftAltitude, 3000);
    });
  });

  group('Exclusive group enforcement (toggleOverlay logic)', () {
    // These tests verify the toggle logic extracted from MapLayerStateNotifier.
    // We test it on MapLayerState directly to avoid needing SharedPreferences.

    MapLayerState toggleOverlay(MapLayerState current, MapLayerId id) {
      final next = Set<MapLayerId>.from(current.activeOverlays);
      if (next.contains(id)) {
        next.remove(id);
      } else {
        // Same logic as MapLayerStateNotifier.toggleOverlay
        final def = kLayerById[id];
        if (def?.exclusiveGroup != null) {
          final group = kExclusiveGroups[def!.exclusiveGroup!] ?? {};
          next.removeAll(group);
        }
        next.add(id);
      }
      return current.copyWith(activeOverlays: next);
    }

    test('toggling on a non-exclusive layer adds it', () {
      const state = MapLayerState(activeOverlays: {});
      final result = toggleOverlay(state, MapLayerId.tfrs);
      expect(result.isActive(MapLayerId.tfrs), isTrue);
    });

    test('toggling off a layer removes it', () {
      const state = MapLayerState(activeOverlays: {MapLayerId.tfrs});
      final result = toggleOverlay(state, MapLayerId.tfrs);
      expect(result.isActive(MapLayerId.tfrs), isFalse);
    });

    test('enabling one exclusive layer disables others in the group', () {
      const state = MapLayerState(
        activeOverlays: {MapLayerId.surfaceWind, MapLayerId.pireps},
      );
      final result = toggleOverlay(state, MapLayerId.temperature);

      expect(result.isActive(MapLayerId.temperature), isTrue);
      expect(result.isActive(MapLayerId.surfaceWind), isFalse,
          reason: 'surfaceWind should be disabled by temperature');
      // Non-exclusive layers are unaffected
      expect(result.isActive(MapLayerId.pireps), isTrue);
    });

    test('switching between all weather-derived layers works', () {
      const initial = MapLayerState(activeOverlays: {});
      var state = toggleOverlay(initial, MapLayerId.surfaceWind);
      expect(state.isActive(MapLayerId.surfaceWind), isTrue);

      state = toggleOverlay(state, MapLayerId.windsAloft);
      expect(state.isActive(MapLayerId.windsAloft), isTrue);
      expect(state.isActive(MapLayerId.surfaceWind), isFalse);

      state = toggleOverlay(state, MapLayerId.ceiling);
      expect(state.isActive(MapLayerId.ceiling), isTrue);
      expect(state.isActive(MapLayerId.windsAloft), isFalse);

      state = toggleOverlay(state, MapLayerId.visibility);
      expect(state.isActive(MapLayerId.visibility), isTrue);
      expect(state.isActive(MapLayerId.ceiling), isFalse);

      state = toggleOverlay(state, MapLayerId.temperature);
      expect(state.isActive(MapLayerId.temperature), isTrue);
      expect(state.isActive(MapLayerId.visibility), isFalse);
    });

    test('toggling off an exclusive layer does not enable others', () {
      var state = const MapLayerState(
        activeOverlays: {MapLayerId.temperature},
      );
      state = toggleOverlay(state, MapLayerId.temperature);
      expect(state.isActive(MapLayerId.temperature), isFalse);
      // No other weather layers should magically turn on
      expect(state.isActive(MapLayerId.surfaceWind), isFalse);
      expect(state.isActive(MapLayerId.windsAloft), isFalse);
      expect(state.isActive(MapLayerId.visibility), isFalse);
      expect(state.isActive(MapLayerId.ceiling), isFalse);
    });

    test('multiple non-exclusive layers can be active simultaneously', () {
      var state = const MapLayerState(activeOverlays: {});
      state = toggleOverlay(state, MapLayerId.tfrs);
      state = toggleOverlay(state, MapLayerId.pireps);
      state = toggleOverlay(state, MapLayerId.airSigmet);
      state = toggleOverlay(state, MapLayerId.traffic);
      expect(state.activeOverlays, {
        MapLayerId.tfrs,
        MapLayerId.pireps,
        MapLayerId.airSigmet,
        MapLayerId.traffic,
      });
    });

    test('exclusive and non-exclusive layers coexist', () {
      var state = const MapLayerState(activeOverlays: {});
      state = toggleOverlay(state, MapLayerId.tfrs);
      state = toggleOverlay(state, MapLayerId.surfaceWind);
      state = toggleOverlay(state, MapLayerId.pireps);

      expect(state.activeOverlays, {
        MapLayerId.tfrs,
        MapLayerId.surfaceWind,
        MapLayerId.pireps,
      });

      // Switching weather layer preserves non-exclusive layers
      state = toggleOverlay(state, MapLayerId.ceiling);
      expect(state.activeOverlays, {
        MapLayerId.tfrs,
        MapLayerId.ceiling,
        MapLayerId.pireps,
      });
    });
  });
}
