import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../services/airport_providers.dart';
import '../../services/map_flight_provider.dart';
import 'widgets/map_toolbar.dart';
import 'widgets/map_sidebar.dart';
import 'widgets/map_bottom_bar.dart';
import 'widgets/layer_picker.dart';
import 'widgets/map_settings_panel.dart';
import 'widgets/map_view.dart';
import 'widgets/airport_bottom_sheet.dart';
import 'widgets/flight_plan_panel.dart';

class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  bool _showLayerPicker = false;
  bool _showSettings = false;
  bool _showFlightPlan = false;
  String _selectedBaseLayer = 'satellite';
  final Set<String> _activeOverlays = {'flight_category'};
  bool _airportsOnly = true;
  final _mapController = EfbMapController();

  MapBounds? _currentBounds;
  Timer? _boundsDebounce;

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    super.dispose();
  }

  void _toggleLayerPicker() {
    setState(() {
      _showLayerPicker = !_showLayerPicker;
      if (_showLayerPicker) {
        _showSettings = false;
        _showFlightPlan = false;
      }
    });
  }

  void _toggleSettings() {
    setState(() {
      _showSettings = !_showSettings;
      if (_showSettings) {
        _showLayerPicker = false;
        _showFlightPlan = false;
      }
    });
  }

  void _toggleFlightPlan() {
    setState(() {
      _showFlightPlan = !_showFlightPlan;
      if (_showFlightPlan) {
        _showLayerPicker = false;
        _showSettings = false;
      }
    });
  }

  void _onBaseLayerChanged(String layer) {
    setState(() {
      _selectedBaseLayer = layer;
      _showLayerPicker = false;
    });
  }

  void _onOverlayToggled(String overlay) {
    setState(() {
      if (_activeOverlays.contains(overlay)) {
        _activeOverlays.remove(overlay);
      } else {
        _activeOverlays.add(overlay);
      }
    });
  }

  void _onAirportTapped(String id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AirportBottomSheet(airportId: id),
    );
  }

  void _onBoundsChanged(MapBounds bounds) {
    _boundsDebounce?.cancel();
    _boundsDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _currentBounds = bounds;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final toolbarBottom = MediaQuery.of(context).padding.top + 90;
    final showOverlay = _showLayerPicker || _showSettings;
    final showFlightCategory = _activeOverlays.contains('flight_category');

    // Always fetch airports for current map bounds
    final airportsAsync = _currentBounds != null
        ? ref.watch(mapAirportsProvider(_currentBounds!))
        : null;
    var airports = airportsAsync?.value
            ?.cast<Map<String, dynamic>>()
            .toList() ??
        [];

    // Filter to fixed-wing airports only when enabled
    if (_airportsOnly) {
      airports =
          airports.where((a) => a['facility_type'] == 'A').toList();
    }

    // When flight category overlay is active, fetch METARs and merge
    if (showFlightCategory && _currentBounds != null) {
      final metarsAsync = ref.watch(mapMetarsProvider(_currentBounds!));
      final metars = metarsAsync.value;
      if (metars != null) {
        final metarMap = <String, String>{};
        for (final m in metars) {
          if (m is Map) {
            final icao = m['icao'] as String?;
            final cat = m['flight_category'] as String?;
            if (icao != null && cat != null) {
              metarMap[icao] = cat;
            }
          }
        }
        airports = airports.map((a) {
          final id = a['identifier'] ?? a['icao_identifier'] ?? '';
          final category = metarMap[id];
          if (category != null) {
            return {...a, 'category': category};
          }
          return a;
        }).toList();
      }
    }

    // Build route line coordinates from active flight's routeString
    final activeFlight = ref.watch(activeFlightProvider);
    final routeCoordinates = <List<double>>[];
    final routeStr = activeFlight?.routeString;
    final routeWaypoints = (routeStr != null && routeStr.trim().isNotEmpty)
        ? routeStr.trim().split(RegExp(r'\s+'))
        : <String>[];
    for (final wp in routeWaypoints) {
      final aptAsync = ref.watch(airportDetailProvider(wp));
      final apt = aptAsync.value;
      if (apt != null && apt['latitude'] != null && apt['longitude'] != null) {
        routeCoordinates.add([
          (apt['longitude'] as num).toDouble(),
          (apt['latitude'] as num).toDouble(),
        ]);
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map fills the entire screen
          Positioned.fill(
            child: EfbMapView(
              baseLayer: _selectedBaseLayer,
              showFlightCategory: showFlightCategory,
              interactive: !showOverlay,
              onAirportTapped: _onAirportTapped,
              onBoundsChanged: _onBoundsChanged,
              airports: airports,
              routeCoordinates: routeCoordinates,
              controller: _mapController,
            ),
          ),

          // Left sidebar controls
          Positioned(
            left: 0,
            top: 160,
            child: MapSidebar(
              onZoomIn: _mapController.zoomIn,
              onZoomOut: _mapController.zoomOut,
            ),
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
                    color: Colors.black38,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: LayerPicker(
                        selectedBaseLayer: _selectedBaseLayer,
                        activeOverlays: _activeOverlays,
                        onBaseLayerChanged: _onBaseLayerChanged,
                        onOverlayToggled: _onOverlayToggled,
                        onClose: _toggleLayerPicker,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Settings panel overlay
          if (_showSettings)
            Positioned(
              top: toolbarBottom,
              left: 0,
              right: 0,
              bottom: 0,
              child: PointerInterceptor(
                child: GestureDetector(
                  onTap: _toggleSettings,
                  child: Container(
                    color: Colors.black38,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: MapSettingsPanel(
                        onClose: _toggleSettings,
                        airportsOnly: _airportsOnly,
                        onAirportsOnlyChanged: (v) =>
                            setState(() => _airportsOnly = v),
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
                  onSettingsTap: _toggleSettings,
                  onFplTap: _toggleFlightPlan,
                  isFplOpen: _showFlightPlan,
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
        ],
      ),
    );
  }
}
