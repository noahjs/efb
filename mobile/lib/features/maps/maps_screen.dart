import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/theme/app_theme.dart';
import '../../models/flight.dart';
import '../../services/airport_providers.dart';
import '../../services/api_client.dart';
import '../../services/flight_providers.dart';
import '../../services/map_flight_provider.dart';
import '../../services/windy_providers.dart';
import '../adsb/providers/adsb_providers.dart';
import '../adsb/widgets/adsb_status_bar.dart';
import '../traffic/models/traffic_settings.dart';
import '../traffic/providers/traffic_providers.dart';
import '../traffic/providers/traffic_alert_provider.dart';
import '../traffic/widgets/traffic_settings_panel.dart';
import '../traffic/widgets/traffic_alert_banner.dart';
import 'layers/map_layer_def.dart';
import 'layers/map_layer_registry.dart';
import 'providers/follow_mode_provider.dart';
import 'providers/layer_data_providers.dart';
import 'providers/map_layer_state_provider.dart';
import 'providers/overlay_assembly_provider.dart';
import 'widgets/aeronautical_settings_panel.dart';
import 'widgets/airport_bottom_sheet.dart';
import 'widgets/approach_overlay.dart';
import 'widgets/fix_bottom_sheet.dart';
import 'widgets/flight_plan_panel.dart';
import 'widgets/layer_picker.dart';
import 'widgets/map_bottom_bar.dart';
import 'widgets/map_long_press_sheet.dart';
import 'widgets/map_sidebar.dart';
import 'widgets/map_toolbar.dart';
import 'widgets/map_view.dart';
import 'widgets/navaid_bottom_sheet.dart';
import 'widgets/pirep_bottom_sheet.dart';
import 'widgets/waypoint_callout.dart';
import 'widgets/radar_playback_control.dart';
import 'widgets/wind_altitude_slider.dart';
import 'widgets/wind_heatmap_controller.dart';
import 'widgets/wx_station_bottom_sheet.dart';

class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  // UI panel toggles (local to this widget, not persisted)
  bool _showLayerPicker = false;
  bool _showFlightPlan = false;
  bool _showAeroSettings = false;
  bool _showTrafficSettings = false;

  // Imperative controllers
  final _mapController = EfbMapController();
  final _approachController = ApproachOverlayController();
  final _heatmapController = WindHeatmapController();

  // Bounds debouncing
  Timer? _boundsDebounce;

  // Track open map-feature bottom sheet so we never stack two.
  // Generation counter prevents a stale whenComplete from clearing the flag
  // after a newer sheet has already been opened.
  bool _isFeatureSheetOpen = false;
  int _featureSheetGen = 0;

  // Waypoint callout state (Garmin-style concentric circle popup)
  MapFeatureTap? _activeCallout;

  // Search state
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearching = false;
  List<dynamic>? _searchResults;
  List<dynamic>? _navaidResults;
  List<dynamic>? _fixResults;
  bool _searchLoading = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _mapController.onMapReady = (map) {
      _approachController.attach(map);
      _heatmapController.attach(map);
    };
    _mapController.onStyleReloaded = () {
      _approachController.reapply();
      _heatmapController.reapply();
    };
    _mapController.onUserPanned = () {
      ref.read(followModeProvider.notifier).set(FollowMode.off);
      // Dismiss callout on pan
      if (_activeCallout != null) {
        setState(() => _activeCallout = null);
      }
    };
  }

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.stopParticles();
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _navaidResults = null;
        _fixResults = null;
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final client = ref.read(apiClientProvider);
        final results = await Future.wait([
          client.searchAirports(query: query, limit: 10),
          client.searchNavaids(query: query, limit: 10),
          client.searchFixes(query: query, limit: 10),
        ]);
        if (mounted && _searchController.text == query) {
          setState(() {
            _searchResults = results[0] is Map
                ? (results[0] as Map)['items'] as List<dynamic>?
                : null;
            _navaidResults = results[1] is List ? results[1] as List : null;
            _fixResults = results[2] is List ? results[2] as List : null;
            _searchLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _searchLoading = false);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _searchResults = null;
      _navaidResults = null;
      _fixResults = null;
      _searchLoading = false;
    });
  }

  void _onSearchResultTapped(Map<String, dynamic> airport) {
    final lat = airport['latitude'] as num?;
    final lng = airport['longitude'] as num?;
    if (lat != null && lng != null) {
      _mapController.flyTo(lat.toDouble(), lng.toDouble(), zoom: 12);
    }
    final identifier = airport['icao_identifier'] ?? airport['identifier'] ?? '';
    _clearSearch();
    _onAirportTapped(identifier);
  }

  void _onNavaidResultTapped(Map<String, dynamic> navaid) {
    final lat = navaid['latitude'] as num?;
    final lng = navaid['longitude'] as num?;
    if (lat != null && lng != null) {
      _mapController.flyTo(lat.toDouble(), lng.toDouble(), zoom: 12);
    }
    final identifier = navaid['identifier'] ?? '';
    _clearSearch();
    _showNavaidSheet(identifier);
  }

  void _onFixResultTapped(Map<String, dynamic> fix) {
    final lat = fix['latitude'] as num?;
    final lng = fix['longitude'] as num?;
    if (lat != null && lng != null) {
      _mapController.flyTo(lat.toDouble(), lng.toDouble(), zoom: 12);
    }
    _clearSearch();
    _showFixSheet(fix);
  }

  /// Dismiss any currently-open map-feature bottom sheet before opening another.
  void _dismissFeatureSheet() {
    if (_isFeatureSheetOpen && mounted) {
      Navigator.of(context).pop();
      _isFeatureSheetOpen = false;
    }
  }

  /// Dismiss the callout and any open sheet. Called on empty map taps.
  void _dismissCalloutAndSheet() {
    if (_activeCallout != null) {
      setState(() => _activeCallout = null);
    }
    _dismissFeatureSheet();
  }

  /// Called when an airport/navaid/fix is tapped on the map.
  /// Shows the Garmin-style callout instead of immediately opening a sheet.
  void _onFeatureTapped(MapFeatureTap feature) {
    // Enrich airport features with data from the airports list
    var enriched = feature;
    if (feature.type == MapFeatureType.airport) {
      final airports = ref.read(airportListProvider).airports;
      final match = airports.cast<Map<String, dynamic>?>().firstWhere(
            (a) =>
                (a?['icao_identifier'] ?? a?['identifier']) ==
                feature.identifier,
            orElse: () => null,
          );
      if (match != null) {
        enriched = feature.copyWith(properties: {
          ...feature.properties,
          'name': match['name'] ?? '',
          'elevation': match['elevation'],
          'city': match['city'] ?? '',
          'state': match['state'] ?? '',
        });
      }
    }
    setState(() => _activeCallout = enriched);
  }

  /// Build the action buttons for the callout based on the feature type.
  List<CalloutAction> _buildCalloutActions(MapFeatureTap feature) {
    switch (feature.type) {
      case MapFeatureType.airport:
        return [
          CalloutAction(
            label: 'Details',
            icon: Icons.info_outline,
            onTap: () {
              setState(() => _activeCallout = null);
              _onAirportTapped(feature.identifier);
            },
          ),
          CalloutAction(
            label: 'Weather',
            icon: Icons.cloud_outlined,
            onTap: () {
              setState(() => _activeCallout = null);
              context.push('/airports/${feature.identifier}?tab=weather');
            },
          ),
          CalloutAction(
            label: 'Direct To',
            icon: Icons.near_me_outlined,
            onTap: () {
              setState(() => _activeCallout = null);
              _directTo(feature.identifier);
            },
          ),
          CalloutAction(
            label: 'Add Route',
            icon: Icons.add_location_alt_outlined,
            onTap: () {
              setState(() => _activeCallout = null);
              _addToRoute(feature.identifier);
            },
          ),
        ];
      case MapFeatureType.navaid:
        return [
          CalloutAction(
            label: 'Details',
            icon: Icons.info_outline,
            onTap: () {
              setState(() => _activeCallout = null);
              _showNavaidSheet(feature.identifier);
            },
          ),
          CalloutAction(
            label: 'Direct To',
            icon: Icons.near_me_outlined,
            onTap: () {
              setState(() => _activeCallout = null);
              _directTo(feature.identifier);
            },
          ),
          CalloutAction(
            label: 'Add Route',
            icon: Icons.add_location_alt_outlined,
            onTap: () {
              setState(() => _activeCallout = null);
              _addToRoute(feature.identifier);
            },
          ),
        ];
      case MapFeatureType.fix:
        return [
          CalloutAction(
            label: 'Details',
            icon: Icons.info_outline,
            onTap: () {
              setState(() => _activeCallout = null);
              _showFixSheetById(feature.identifier);
            },
          ),
          CalloutAction(
            label: 'Direct To',
            icon: Icons.near_me_outlined,
            onTap: () {
              setState(() => _activeCallout = null);
              _directTo(feature.identifier);
            },
          ),
          CalloutAction(
            label: 'Add Route',
            icon: Icons.add_location_alt_outlined,
            onTap: () {
              setState(() => _activeCallout = null);
              _addToRoute(feature.identifier);
            },
          ),
        ];
      case MapFeatureType.pirep:
        return [
          CalloutAction(
            label: 'Details',
            icon: Icons.info_outline,
            onTap: () {
              final props = feature.properties;
              setState(() => _activeCallout = null);
              _onPirepTapped(props);
            },
          ),
        ];
    }
  }

  /// Set this identifier as the sole destination (Direct To).
  void _directTo(String identifier) {
    final flight = ref.read(activeFlightProvider);
    final id = identifier.toUpperCase();
    final updated = (flight ?? const Flight()).copyWith(
      destinationIdentifier: id,
      routeString: id,
      departureIdentifier: flight?.departureIdentifier ?? '',
    );
    _saveFlightUpdate(updated);
  }

  /// Append this identifier to the active route.
  void _addToRoute(String identifier) {
    final flight = ref.read(activeFlightProvider);
    final f = flight ?? const Flight();
    final existing = f.routeString?.trim() ?? '';
    final id = identifier.toUpperCase();
    final newRoute = existing.isEmpty ? id : '$existing $id';
    final waypoints = newRoute.split(RegExp(r'\s+'));
    final updated = f.copyWith(
      routeString: newRoute,
      departureIdentifier: waypoints.first,
      destinationIdentifier:
          waypoints.length > 1 ? waypoints.last : waypoints.first,
    );
    _saveFlightUpdate(updated);
  }

  /// Persist flight update and recalculate.
  Future<void> _saveFlightUpdate(Flight updated) async {
    ref.read(activeFlightProvider.notifier).set(updated);
    try {
      if (updated.id != null) {
        final service = ref.read(flightServiceProvider);
        final saved =
            await service.updateFlight(updated.id!, updated.toJson());
        ref.read(activeFlightProvider.notifier).set(saved);
      } else {
        final api = ref.read(apiClientProvider);
        final result = await api.calculateFlight(
          departureIdentifier: updated.departureIdentifier,
          destinationIdentifier: updated.destinationIdentifier,
          routeString: updated.routeString,
          cruiseAltitude: updated.cruiseAltitude,
          trueAirspeed: updated.trueAirspeed,
          fuelBurnRate: updated.fuelBurnRate,
          etd: updated.etd,
          performanceProfileId: updated.performanceProfileId,
        );
        ref.read(activeFlightProvider.notifier).set(Flight(
              id: updated.id,
              aircraftId: updated.aircraftId,
              performanceProfileId: updated.performanceProfileId,
              departureIdentifier: updated.departureIdentifier,
              destinationIdentifier: updated.destinationIdentifier,
              alternateIdentifier: updated.alternateIdentifier,
              etd: updated.etd,
              aircraftIdentifier: updated.aircraftIdentifier,
              aircraftType: updated.aircraftType,
              performanceProfile: updated.performanceProfile,
              trueAirspeed: updated.trueAirspeed,
              flightRules: updated.flightRules,
              routeString: updated.routeString,
              cruiseAltitude: updated.cruiseAltitude,
              peopleCount: updated.peopleCount,
              avgPersonWeight: updated.avgPersonWeight,
              cargoWeight: updated.cargoWeight,
              fuelPolicy: updated.fuelPolicy,
              startFuelGallons: updated.startFuelGallons,
              reserveFuelGallons: updated.reserveFuelGallons,
              fuelBurnRate: updated.fuelBurnRate,
              fuelAtShutdownGallons: updated.fuelAtShutdownGallons,
              filingStatus: updated.filingStatus,
              distanceNm: (result['distance_nm'] as num?)?.toDouble(),
              eteMinutes: result['ete_minutes'] as int?,
              flightFuelGallons:
                  (result['flight_fuel_gallons'] as num?)?.toDouble(),
              eta: result['eta'] as String?,
              calculatedAt: result['calculated_at'] as String?,
            ));
      }
    } catch (_) {
      // Calculation may fail for incomplete flights — that's ok
    }
  }

  /// Show a modal bottom sheet for a map feature, ensuring only one is open.
  Future<void> _showFeatureSheet(WidgetBuilder builder) {
    _dismissFeatureSheet();
    _isFeatureSheetOpen = true;
    final gen = ++_featureSheetGen;
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: builder,
    ).whenComplete(() {
      // Only clear flag if no newer sheet has been opened since
      if (_featureSheetGen == gen) {
        _isFeatureSheetOpen = false;
      }
    });
  }

  void _showNavaidSheet(String identifier) {
    _showFeatureSheet((_) => NavaidBottomSheet(navaidId: identifier));
  }

  void _showFixSheet(Map<String, dynamic> fixData) {
    final identifier = fixData['identifier'] ?? '';
    _showFeatureSheet(
        (_) => FixBottomSheet(fixId: identifier, fixData: fixData));
  }

  void _showFixSheetById(String identifier) {
    _showFeatureSheet((_) => FixBottomSheet(fixId: identifier));
  }

  // ── Panel toggles ────────────────────────────────────────────────────────

  void _toggleLayerPicker() {
    setState(() {
      _showLayerPicker = !_showLayerPicker;
      if (_showLayerPicker) {
        _showFlightPlan = false;
      }
    });
  }

  void _toggleFlightPlan() {
    setState(() {
      _showFlightPlan = !_showFlightPlan;
      if (_showFlightPlan) {
        _showLayerPicker = false;
      }
    });
  }

  // ── Map callbacks ────────────────────────────────────────────────────────

  void _onBoundsChanged(MapBounds bounds) {
    // Always keep particle viewport in sync — no debounce needed for this
    if (_mapController.particlesRunning) {
      _mapController.updateParticleViewport(
        minLat: bounds.minLat,
        maxLat: bounds.maxLat,
        minLng: bounds.minLng,
        maxLng: bounds.maxLng,
      );
    }

    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(mapBoundsProvider.notifier).set(bounds);
      }
    });
  }

  void _onMapLongPressed(
      double lat, double lng, List<Map<String, dynamic>> features) {
    _showFeatureSheet(
      (_) => PointerInterceptor(
        child: MapLongPressSheet(lat: lat, lng: lng, aeroFeatures: features),
      ),
    );
  }

  void _onAirportTapped(String id) {
    // Check if this is a synthetic weather station (non-airport METAR source)
    final wxStations = ref.read(airportListProvider).weatherStations;
    final wxEntry = wxStations[id];
    if (wxEntry != null) {
      _showFeatureSheet(
        (_) => WxStationBottomSheet(
          stationId: id,
          metarData: wxEntry['_metarData'] as Map<dynamic, dynamic>?,
        ),
      );
      return;
    }
    _showFeatureSheet((_) => AirportBottomSheet(airportId: id));
  }

  void _onPirepTapped(Map<String, dynamic> properties) {
    _showFeatureSheet((_) => PirepBottomSheet(properties: properties));
  }

  // ── Settings panels ──────────────────────────────────────────────────────

  void _showAeroSettingsPanel() {
    _dismissFeatureSheet();
    final layerState = ref.read(mapLayerStateProvider).value;
    if (layerState == null) return;
    setState(() => _showAeroSettings = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PointerInterceptor(
        child: _AeroSettingsSheet(
          settings: layerState.aeroSettings,
          onChanged: (newSettings) {
            ref.read(mapLayerStateProvider.notifier).setAeroSettings(newSettings);
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _showAeroSettings = false);
    });
  }

  void _showTrafficSettingsPanel() {
    _dismissFeatureSheet();
    final layerState = ref.read(mapLayerStateProvider).value;
    if (layerState == null) return;
    setState(() => _showTrafficSettings = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PointerInterceptor(
        child: _TrafficSettingsSheet(
          settings: layerState.trafficSettings,
          onChanged: (newSettings) {
            ref.read(mapLayerStateProvider.notifier).setTrafficSettings(newSettings);
            // Invalidate so the traffic layer picks up changes
            ref.invalidate(trafficSettingsProvider);
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _showTrafficSettings = false);
    });
  }

  void _onApproachTapped() {
    if (_approachController.isActive) {
      _approachController.hide();
      setState(() {});
      return;
    }

    final textController = TextEditingController();
    final flight = ref.read(activeFlightProvider);
    if (flight?.destinationIdentifier != null &&
        flight!.destinationIdentifier!.isNotEmpty) {
      textController.text = flight.destinationIdentifier!;
    } else if (flight?.departureIdentifier != null &&
        flight!.departureIdentifier!.isNotEmpty) {
      textController.text = flight.departureIdentifier!;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Approach Plates',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Airport ID (e.g. KAPA)',
            hintStyle: TextStyle(color: AppColors.textMuted),
          ),
          onSubmitted: (val) {
            Navigator.of(ctx).pop();
            if (val.trim().isNotEmpty) {
              _showApproachPicker(val.trim().toUpperCase());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final val = textController.text.trim().toUpperCase();
              if (val.isNotEmpty) {
                _showApproachPicker(val);
              }
            },
            child: const Text('Show Plates'),
          ),
        ],
      ),
    );
  }

  void _showApproachPicker(String airportId) {
    _dismissFeatureSheet();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PointerInterceptor(
        child: ApproachPlatePicker(
          airportId: airportId,
          overlayController: _approachController,
          onOverlayChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final toolbarBottom = MediaQuery.of(context).padding.top + 90;
    final showOverlay = _showLayerPicker || _showAeroSettings ||
        _showTrafficSettings || _showFlightPlan;

    // Read layer state from provider
    final layerState = ref.watch(mapLayerStateProvider).value;
    if (layerState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final baseLayerDef = kLayerById[layerState.baseLayer];
    final baseLayerKey = baseLayerDef?.sourceKey ?? 'dark';
    final showFlightCategory = layerState.isActive(MapLayerId.flightCategory);
    final showWindsAloft = layerState.isActive(MapLayerId.windsAloft);
    final showRadar = layerState.isActive(MapLayerId.radar);
    final showTraffic = layerState.isActive(MapLayerId.traffic);

    // Assembled overlays from all layer data providers
    final overlays = ref.watch(assembledOverlaysProvider);

    // Airport list (with flight category merge)
    final airportResult = ref.watch(airportListProvider);

    // Winds aloft side-effects: heatmap + particle animation
    final bounds = ref.watch(mapBoundsProvider);
    if (showWindsAloft && bounds != null) {
      final windParams = WindGridParams(
        bounds: bounds,
        altitude: layerState.windsAloftAltitude,
      );

      // Heatmap overlay
      final client = ref.read(apiClientProvider);
      final heatmapUrl = client.getWindHeatmapUrl(
        minLat: bounds.minLat,
        maxLat: bounds.maxLat,
        minLng: bounds.minLng,
        maxLng: bounds.maxLng,
        altitude: layerState.windsAloftAltitude,
      );
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _heatmapController.show(
          imageUrl: heatmapUrl,
          minLat: bounds.minLat,
          maxLat: bounds.maxLat,
          minLng: bounds.minLng,
          maxLng: bounds.maxLng,
        );
      });

      // Particle animation
      final windFieldAsync = ref.watch(windFieldProvider(windParams));
      final windField = windFieldAsync.value;
      if (windField != null && windField.isNotEmpty) {
        final pWindField = windField
            .map((wf) => <String, dynamic>{
                  'lat': wf.lat,
                  'lng': wf.lng,
                  'direction': wf.direction,
                  'speed': wf.speed,
                })
            .toList();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _mapController.updateParticleField(
            pWindField,
            minLat: bounds.minLat,
            maxLat: bounds.maxLat,
            minLng: bounds.minLng,
            maxLng: bounds.maxLng,
          );
          if (!_mapController.particlesRunning) {
            debugPrint(
                '[EFB] Starting particle animation with ${pWindField.length} wind field points');
            _mapController.startParticles();
          }
        });
      }
    } else {
      // Clean up when winds aloft is deactivated
      if (_heatmapController.isActive) {
        _heatmapController.hide();
      }
      if (_mapController.particlesRunning) {
        _mapController.stopParticles();
      }
    }

    // Traffic loading indicator
    final trafficLoading =
        showTraffic && ref.watch(unifiedTrafficProvider).isEmpty;

    // Follow mode
    final followMode = ref.watch(followModeProvider);
    final activePos = ref.watch(activePositionProvider);
    if (followMode != FollowMode.off && activePos != null) {
      final fLat = activePos.latitude;
      final fLng = activePos.longitude;
      final fBearing =
          followMode == FollowMode.trackUp ? activePos.track.toDouble() : 0.0;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _mapController.followTo(fLat, fLng, bearing: fBearing);
      });
    }

    // Route line from active flight
    final activeFlight = ref.watch(activeFlightProvider);
    final routeCoordinates = <List<double>>[];
    final routeStr = activeFlight?.routeString;
    final routeWaypoints = (routeStr != null && routeStr.trim().isNotEmpty)
        ? routeStr.trim().split(RegExp(r'\s+'))
        : <String>[];
    if (routeWaypoints.isNotEmpty) {
      final resolvedAsync =
          ref.watch(resolvedRouteProvider(routeWaypoints.join(',')));
      final resolved = resolvedAsync.value;
      if (resolved != null) {
        for (final wp in resolved) {
          if (wp is Map &&
              wp['latitude'] != null &&
              wp['longitude'] != null) {
            routeCoordinates.add([
              (wp['longitude'] as num).toDouble(),
              (wp['latitude'] as num).toDouble(),
            ]);
          }
        }
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map fills the entire screen
          Positioned.fill(
            child: EfbMapView(
              baseLayer: baseLayerKey,
              showFlightCategory: showFlightCategory,
              interactive: !showOverlay,
              onMapTapped: _dismissCalloutAndSheet,
              onFeatureTapped: _onFeatureTapped,
              // Fallbacks for web (which doesn't use onFeatureTapped yet)
              onAirportTapped: _onAirportTapped,
              onNavaidTapped: _showNavaidSheet,
              onFixTapped: _showFixSheetById,
              onPirepTapped: _onPirepTapped,
              onBoundsChanged: _onBoundsChanged,
              onMapLongPressed: _onMapLongPressed,
              airports: airportResult.airports,
              routeCoordinates: routeCoordinates,
              controller: _mapController,
              overlays: overlays,
            ),
          ),

          // Waypoint callout (Garmin-style concentric circles)
          if (_activeCallout != null)
            Positioned(
              left: _activeCallout!.screenX,
              top: _activeCallout!.screenY,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: WaypointCallout(
                  feature: _activeCallout!,
                  ownshipLat: activePos?.latitude,
                  ownshipLng: activePos?.longitude,
                  actions: _buildCalloutActions(_activeCallout!),
                ),
              ),
            ),

          // Left sidebar controls
          Positioned(
            left: 0,
            bottom: 80,
            child: MapSidebar(
              onZoomIn: _mapController.zoomIn,
              onZoomOut: _mapController.zoomOut,
              onAeroSettingsTap: _showAeroSettingsPanel,
              onTrafficSettingsTap: _showTrafficSettingsPanel,
              isTrafficActive: showTraffic,
              isTrafficLoading: trafficLoading,
              onApproachTap: _onApproachTapped,
              isApproachActive: _approachController.isActive,
              followMode: followMode,
              onFollowModeChanged: (mode) {
                ref.read(followModeProvider.notifier).set(mode);
                if (mode != FollowMode.off) {
                  final pos = ref.read(activePositionProvider);
                  if (pos != null) {
                    _mapController.followTo(pos.latitude, pos.longitude,
                        bearing: mode == FollowMode.trackUp
                            ? pos.track.toDouble()
                            : 0);
                  }
                }
              },
            ),
          ),

          // Wind altitude slider (right edge, only when winds aloft active)
          if (showWindsAloft)
            Positioned(
              right: 8,
              top: MediaQuery.of(context).padding.top + 100,
              child: WindAltitudeSlider(
                altitude: layerState.windsAloftAltitude,
                onChanged: (alt) {
                  ref
                      .read(mapLayerStateProvider.notifier)
                      .setWindsAloftAltitude(alt);
                },
              ),
            ),

          // Traffic proximity alert banner
          if (showTraffic && ref.watch(trafficAlertProvider) != null)
            Positioned(
              top: toolbarBottom + 8,
              left: 0,
              right: 0,
              child: Center(
                child:
                    TrafficAlertBanner(alert: ref.watch(trafficAlertProvider)!),
              ),
            ),

          // Radar playback control (above ADS-B status bar)
          if (showRadar)
            const Positioned(
              bottom: 68,
              left: 0,
              right: 0,
              child: RadarPlaybackControl(),
            ),

          // ADS-B status bar
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Center(child: AdsbStatusBar()),
          ),

          // Bottom info bar
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MapBottomBar(),
          ),

          // Layer picker overlay (below toolbar, above map)
          if (_showLayerPicker)
            Positioned(
              top: toolbarBottom,
              left: 0,
              right: 0,
              bottom: 0,
              child: PointerInterceptor(
                child: GestureDetector(
                  onTap: _toggleLayerPicker,
                  child: Container(
                    color: AppColors.scrim,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: LayerPicker(
                        onClose: _toggleLayerPicker,
                        onBaseLayerSelected: () {
                          setState(() => _showLayerPicker = false);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Top toolbar (always on top of overlays)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MapToolbar(
                  onLayersTap: _toggleLayerPicker,
                  onFplTap: _toggleFlightPlan,
                  isFplOpen: _showFlightPlan,
                  searchController: _searchController,
                  searchFocusNode: _searchFocusNode,
                  onSearchChanged: _onSearchChanged,
                  onSearchTap: () {
                    setState(() => _isSearching = true);
                  },
                  onSearchClear: _clearSearch,
                  isSearching: _isSearching,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _showFlightPlan
                      ? const FlightPlanPanel()
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Search results dropdown
          if (_isSearching && _searchController.text.isNotEmpty)
            Positioned(
              top: toolbarBottom,
              left: 8,
              right: 8,
              child: PointerInterceptor(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 320),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: AppShadows.elevated,
                    ),
                    child: _buildSearchResults(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Search results UI ─────────────────────────────────────────────────────

  Widget _buildSearchResults() {
    if (_searchLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final airports = _searchResults;
    final navaids = _navaidResults;
    final fixes = _fixResults;
    final hasAirports = airports != null && airports.isNotEmpty;
    final hasNavaids = navaids != null && navaids.isNotEmpty;
    final hasFixes = fixes != null && fixes.isNotEmpty;

    if (!hasAirports && !hasNavaids && !hasFixes) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No results found',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          if (hasAirports) ...[
            _buildSectionHeader('Airports'),
            for (int i = 0; i < airports.length; i++) ...[
              if (i > 0)
                const Divider(height: 0.5, color: AppColors.divider),
              _buildAirportRow(airports[i] as Map<String, dynamic>),
            ],
          ],
          if (hasNavaids) ...[
            if (hasAirports)
              const Divider(height: 0.5, color: AppColors.divider),
            _buildSectionHeader('Navaids'),
            for (int i = 0; i < navaids.length; i++) ...[
              if (i > 0)
                const Divider(height: 0.5, color: AppColors.divider),
              _buildNavaidRow(navaids[i] as Map<String, dynamic>),
            ],
          ],
          if (hasFixes) ...[
            if (hasAirports || hasNavaids)
              const Divider(height: 0.5, color: AppColors.divider),
            _buildSectionHeader('Fixes'),
            for (int i = 0; i < fixes.length; i++) ...[
              if (i > 0)
                const Divider(height: 0.5, color: AppColors.divider),
              _buildFixRow(fixes[i] as Map<String, dynamic>),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.surfaceLight,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAirportRow(Map<String, dynamic> airport) {
    final identifier = airport['identifier'] ?? '';
    final icao = airport['icao_identifier'] ?? '';
    final displayId = icao.isNotEmpty ? icao : identifier;
    final name = airport['name'] ?? '';
    final city = airport['city'] ?? '';
    final state = airport['state'] ?? '';
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    return InkWell(
      onTap: () => _onSearchResultTapped(airport),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                displayId,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location.isNotEmpty)
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavaidRow(Map<String, dynamic> navaid) {
    final identifier = navaid['identifier'] ?? '';
    final name = navaid['name'] ?? '';
    final type = navaid['type'] ?? '';
    final freq = navaid['frequency'] ?? '';
    final subtitle = [type, if (freq.isNotEmpty) freq]
        .where((s) => s.isNotEmpty)
        .join(' \u2022 ');

    return InkWell(
      onTap: () => _onNavaidResultTapped(navaid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                identifier,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.navigation_outlined,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixRow(Map<String, dynamic> fix) {
    final identifier = fix['identifier'] ?? '';
    final state = fix['state'] ?? '';

    return InkWell(
      onTap: () => _onFixResultTapped(fix),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                identifier,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.isNotEmpty
                    ? 'Intersection \u2022 $state'
                    : 'Intersection',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const Icon(
              Icons.change_history_outlined,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateful wrapper so the bottom sheet rebuilds on toggle changes
/// while also syncing state back to the provider.
class _AeroSettingsSheet extends StatefulWidget {
  final AeroSettings settings;
  final ValueChanged<AeroSettings> onChanged;
  final VoidCallback onClose;

  const _AeroSettingsSheet({
    required this.settings,
    required this.onChanged,
    required this.onClose,
  });

  @override
  State<_AeroSettingsSheet> createState() => _AeroSettingsSheetState();
}

class _AeroSettingsSheetState extends State<_AeroSettingsSheet> {
  late AeroSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return AeronauticalSettingsPanel(
      onClose: widget.onClose,
      settings: _settings,
      onChanged: (newSettings) {
        setState(() => _settings = newSettings);
        widget.onChanged(newSettings);
      },
    );
  }
}

/// Stateful wrapper so the traffic settings bottom sheet rebuilds on toggle
/// changes while also syncing state back to the provider.
class _TrafficSettingsSheet extends StatefulWidget {
  final TrafficSettings settings;
  final ValueChanged<TrafficSettings> onChanged;
  final VoidCallback onClose;

  const _TrafficSettingsSheet({
    required this.settings,
    required this.onChanged,
    required this.onClose,
  });

  @override
  State<_TrafficSettingsSheet> createState() => _TrafficSettingsSheetState();
}

class _TrafficSettingsSheetState extends State<_TrafficSettingsSheet> {
  late TrafficSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return TrafficSettingsPanel(
      onClose: widget.onClose,
      settings: _settings,
      onChanged: (newSettings) {
        setState(() => _settings = newSettings);
        widget.onChanged(newSettings);
      },
    );
  }
}
