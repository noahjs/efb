import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/airport_providers.dart';
import '../../services/aeronautical_providers.dart';
import '../../services/map_flight_provider.dart';
import 'widgets/map_toolbar.dart';
import 'widgets/map_sidebar.dart';
import 'widgets/map_bottom_bar.dart';
import 'widgets/layer_picker.dart';
import 'widgets/map_settings_panel.dart';
import 'widgets/aeronautical_settings_panel.dart';
import 'widgets/map_view.dart';
import 'widgets/airport_bottom_sheet.dart';
import 'widgets/map_long_press_sheet.dart';
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
  Set<String> _activeOverlays = {'flight_category'};
  AeroSettings _aero = const AeroSettings();
  bool _showAeroSettings = false;
  final _mapController = EfbMapController();

  MapBounds? _currentBounds;
  Timer? _boundsDebounce;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final baseLayer = prefs.getString('map_base_layer') ?? 'satellite';
    final overlays = prefs.getStringList('map_overlays') ?? ['flight_category'];
    final aero = await AeroSettings.load();
    if (mounted) {
      setState(() {
        _selectedBaseLayer = baseLayer;
        _activeOverlays = overlays.toSet();
        _aero = aero;
      });
    }
  }

  Future<void> _saveMapSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('map_base_layer', _selectedBaseLayer);
    prefs.setStringList('map_overlays', _activeOverlays.toList());
    _aero.save();
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
    _saveMapSettings();
  }

  void _onOverlayToggled(String overlay) {
    setState(() {
      if (_activeOverlays.contains(overlay)) {
        _activeOverlays.remove(overlay);
      } else {
        _activeOverlays.add(overlay);
      }
    });
    _saveMapSettings();
  }

  void _onMapLongPressed(
      double lat, double lng, List<Map<String, dynamic>> features) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PointerInterceptor(
        child: MapLongPressSheet(lat: lat, lng: lng, aeroFeatures: features),
      ),
    );
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

  void _showAeroSettingsPanel() {
    setState(() => _showAeroSettings = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PointerInterceptor(
        child: _AeroSettingsSheet(
          settings: _aero,
          onChanged: (newSettings) {
            setState(() => _aero = newSettings);
            _saveMapSettings();
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _showAeroSettings = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final toolbarBottom = MediaQuery.of(context).padding.top + 90;
    final showOverlay = _showLayerPicker || _showSettings || _showAeroSettings;
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
    if (_aero.airportsOnly) {
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

    // When aeronautical overlay is active, fetch airspace/airway/ARTCC data
    final showAeronautical = _activeOverlays.contains('aeronautical');
    Map<String, dynamic>? airspaceGeoJson;
    Map<String, dynamic>? airwayGeoJson;
    Map<String, dynamic>? artccGeoJson;
    if (showAeronautical && _currentBounds != null) {
      if (_aero.showAirspaces) {
        // Build airspace class filter from sub-toggles
        final classes = <String>['B', 'C', 'D'];
        if (_aero.showClassE) classes.add('E');
        final classesStr = classes.join(',');

        airspaceGeoJson = ref
            .watch(mapAirspacesProvider((
              minLat: _currentBounds!.minLat,
              maxLat: _currentBounds!.maxLat,
              minLng: _currentBounds!.minLng,
              maxLng: _currentBounds!.maxLng,
              classes: classesStr,
            )))
            .value;
      }
      if (_aero.showAirways) {
        // Build airway type filter from sub-toggles
        final types = <String>[];
        if (_aero.showLowAirways) types.addAll(['V', 'T']);
        if (_aero.showHighAirways) types.addAll(['J', 'Q']);
        final typesStr = types.isNotEmpty ? types.join(',') : null;

        airwayGeoJson = ref
            .watch(mapAirwaysProvider((
              minLat: _currentBounds!.minLat,
              maxLat: _currentBounds!.maxLat,
              minLng: _currentBounds!.minLng,
              maxLng: _currentBounds!.maxLng,
              types: typesStr,
            )))
            .value;
      }
      if (_aero.showArtcc) {
        artccGeoJson =
            ref.watch(mapArtccProvider(_currentBounds!)).value;
      }
    }

    // Build route line coordinates from active flight's routeString
    // Uses the waypoint resolver which handles airports, navaids, and fixes
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
              baseLayer: _selectedBaseLayer,
              showFlightCategory: showFlightCategory,
              interactive: !showOverlay,
              onAirportTapped: _onAirportTapped,
              onBoundsChanged: _onBoundsChanged,
              onMapLongPressed: _onMapLongPressed,
              airports: airports,
              routeCoordinates: routeCoordinates,
              controller: _mapController,
              airspaceGeoJson: airspaceGeoJson,
              airwayGeoJson: airwayGeoJson,
              artccGeoJson: artccGeoJson,
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

/// Stateful wrapper so the bottom sheet rebuilds on toggle changes
/// while also syncing state back to [MapsScreen].
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
