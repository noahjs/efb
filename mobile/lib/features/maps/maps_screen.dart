import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/airport_providers.dart';
import '../../services/aeronautical_providers.dart';
import '../../services/map_flight_provider.dart';
import '../imagery/imagery_providers.dart';
import 'widgets/map_toolbar.dart';
import 'widgets/map_sidebar.dart';
import 'widgets/map_bottom_bar.dart';
import 'widgets/layer_picker.dart';
import 'widgets/aeronautical_settings_panel.dart';
import 'widgets/map_view.dart';
import 'widgets/airport_bottom_sheet.dart';
import 'widgets/navaid_bottom_sheet.dart';
import 'widgets/fix_bottom_sheet.dart';
import 'widgets/map_long_press_sheet.dart';
import 'widgets/flight_plan_panel.dart';
import 'widgets/approach_overlay.dart';

class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  bool _showLayerPicker = false;
  bool _showFlightPlan = false;
  String _selectedBaseLayer = 'satellite';
  Set<String> _activeOverlays = {'flight_category'};
  AeroSettings _aero = const AeroSettings();
  bool _showAeroSettings = false;
  final _mapController = EfbMapController();
  final _approachController = ApproachOverlayController();

  MapBounds? _currentBounds;
  Timer? _boundsDebounce;

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
    _loadSettings();
    _mapController.onMapReady = (map) {
      _approachController.attach(map);
    };
    _mapController.onStyleReloaded = () {
      _approachController.reapply();
    };
  }

  @override
  void dispose() {
    _boundsDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    final identifier = airport['identifier'] ?? '';
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

  void _showNavaidSheet(String identifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NavaidBottomSheet(navaidId: identifier),
    );
  }

  void _showFixSheet(Map<String, dynamic> fixData) {
    final identifier = fixData['identifier'] ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FixBottomSheet(fixId: identifier, fixData: fixData),
    );
  }

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

  void _onApproachTapped() {
    // If overlay is active, remove it
    if (_approachController.isActive) {
      _approachController.hide();
      setState(() {});
      return;
    }

    // Show a dialog to enter airport identifier
    final textController = TextEditingController();

    // Pre-fill from active flight if available
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
                state.isNotEmpty ? 'Intersection \u2022 $state' : 'Intersection',
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

  @override
  Widget build(BuildContext context) {
    final toolbarBottom = MediaQuery.of(context).padding.top + 90;
    final showOverlay = _showLayerPicker || _showAeroSettings || _showFlightPlan;
    final showFlightCategory = _activeOverlays.contains('flight_category');

    // Fetch airports when aeronautical overlay is active and airports are enabled
    final showAeronautical = _activeOverlays.contains('aeronautical');
    var airports = <Map<String, dynamic>>[];
    if (showAeronautical && _aero.showAirports && _currentBounds != null) {
      final airportsAsync = ref.watch(mapAirportsProvider(_currentBounds!));
      airports = airportsAsync.value
              ?.cast<Map<String, dynamic>>()
              .toList() ??
          [];

      // Granular airport filtering by facility type and use
      airports = airports.where((a) {
        final type = a['facility_type'] ?? '';
        final use = a['facility_use'] ?? '';
        if (type == 'H' && !_aero.showHeliports) return false;
        if (type == 'S' && !_aero.showSeaplaneBases) return false;
        if (['G', 'U', 'B'].contains(type) && !_aero.showOtherFields) return false;
        if (use == 'PR' && !_aero.showPrivateAirports) return false;
        return true;
      }).toList();
    }

    // When flight category overlay is active, fetch METARs and merge
    if (showFlightCategory && _currentBounds != null) {
      final metarsAsync = ref.watch(mapMetarsProvider(_currentBounds!));
      final metars = metarsAsync.value;
      if (metars != null) {
        final metarMap = <String, String>{};
        for (final m in metars) {
          if (m is Map) {
            final icao = m['icaoId'] as String?;
            final cat = m['fltCat'] as String?;
            if (icao != null && cat != null) {
              metarMap[icao] = cat;
            }
          }
        }
        airports = airports.map((a) {
          final icao = a['icao_identifier'] ?? a['identifier'] ?? '';
          final category = metarMap[icao];
          if (category != null) {
            return {...a, 'category': category};
          }
          return a;
        }).toList();
      }
    }

    // When aeronautical overlay is active, fetch airspace/airway/ARTCC data
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

    // When TFR overlay is active, fetch TFR GeoJSON
    final showTfrs = _activeOverlays.contains('tfrs');
    Map<String, dynamic>? tfrGeoJson;
    if (showTfrs) {
      tfrGeoJson = ref.watch(tfrsProvider).value;
    }

    // When AIR/SIGMET overlay is active, fetch advisory GeoJSON
    final showAirSigmet = _activeOverlays.contains('air_sigmet');
    Map<String, dynamic>? advisoryGeoJson;
    if (showAirSigmet) {
      // Fetch all three advisory types and merge into one FeatureCollection
      final gairmets = ref.watch(advisoriesProvider(
          const AdvisoryParams(type: 'gairmets'))).value;
      final sigmets = ref.watch(advisoriesProvider(
          const AdvisoryParams(type: 'sigmets'))).value;
      final cwas = ref.watch(advisoriesProvider(
          const AdvisoryParams(type: 'cwas'))).value;

      final allFeatures = <dynamic>[
        ...?_extractFeatures(gairmets),
        ...?_extractFeatures(sigmets),
        ...?_extractFeatures(cwas),
      ];
      if (allFeatures.isNotEmpty) {
        advisoryGeoJson = _enrichAdvisoryGeoJson({
          'type': 'FeatureCollection',
          'features': allFeatures,
        });
      }
    }

    // When PIREPs overlay is active, fetch PIREP GeoJSON
    final showPireps = _activeOverlays.contains('pireps');
    Map<String, dynamic>? pirepGeoJson;
    if (showPireps && _currentBounds != null) {
      final bbox = '${_currentBounds!.minLng},${_currentBounds!.minLat},'
          '${_currentBounds!.maxLng},${_currentBounds!.maxLat}';
      final pirepsData = ref.watch(mapPirepsProvider(bbox)).value;
      if (pirepsData != null) {
        pirepGeoJson = _enrichPirepGeoJson(pirepsData);
      }
    }

    // METAR-derived overlays (surface wind, temperature, visibility, ceiling)
    final metarOverlayTypes = {'surface_wind', 'temperature', 'visibility', 'ceiling'};
    final activeMetarOverlay = _activeOverlays.intersection(metarOverlayTypes);
    Map<String, dynamic>? metarOverlayGeoJson;
    if (activeMetarOverlay.isNotEmpty && _currentBounds != null) {
      final metarsAsync = ref.watch(mapMetarsProvider(_currentBounds!));
      final metars = metarsAsync.value;
      if (metars != null) {
        metarOverlayGeoJson = _buildMetarOverlayGeoJson(
          metars,
          activeMetarOverlay.first,
        );
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
              tfrGeoJson: tfrGeoJson,
              advisoryGeoJson: advisoryGeoJson,
              pirepGeoJson: pirepGeoJson,
              metarOverlayGeoJson: metarOverlayGeoJson,
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
              onApproachTap: _onApproachTapped,
              isApproachActive: _approachController.isActive,
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
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
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

  List<dynamic>? _extractFeatures(Map<String, dynamic>? geojson) {
    if (geojson == null) return null;
    return geojson['features'] as List<dynamic>?;
  }

  Map<String, dynamic> _enrichAdvisoryGeoJson(Map<String, dynamic> original) {
    final features = (original['features'] as List<dynamic>?) ?? [];
    final enrichedFeatures = features.map((f) {
      final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
      final props =
          Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
      if (props['color'] == null || props['color'] == '') {
        final hazard = (props['hazard'] as String? ?? '').toUpperCase();
        props['color'] = _advisoryColorHex(hazard);
      }
      feature['properties'] = props;
      return feature;
    }).toList();
    return {'type': 'FeatureCollection', 'features': enrichedFeatures};
  }

  String _advisoryColorHex(String hazard) {
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

  Map<String, dynamic> _enrichPirepGeoJson(Map<String, dynamic> original) {
    final features = (original['features'] as List<dynamic>?) ?? [];
    final enrichedFeatures = features.map((f) {
      final feature = Map<String, dynamic>.from(f as Map<String, dynamic>);
      final props =
          Map<String, dynamic>.from(feature['properties'] as Map? ?? {});
      final tbInt = (props['tbInt1'] as String? ?? '').toUpperCase();
      final icgInt = (props['icgInt1'] as String? ?? '').toUpperCase();
      final airepType = props['airepType'] as String? ?? '';
      props['color'] = _pirepColorHex(tbInt, icgInt);
      props['isUrgent'] = airepType == 'URGENT PIREP';
      feature['properties'] = props;
      return feature;
    }).toList();
    return {'type': 'FeatureCollection', 'features': enrichedFeatures};
  }

  String _pirepColorHex(String tbInt, String icgInt) {
    final primary = tbInt.isNotEmpty ? tbInt : icgInt;
    if (['LGT', 'LIGHT', 'LGT-MOD'].contains(primary)) return '#29B6F6';
    if (['MOD', 'MODERATE', 'MOD-SEV'].contains(primary)) return '#FFC107';
    if (['SEV', 'SEVERE', 'SEV-EXTM', 'EXTM', 'EXTREME'].contains(primary)) {
      return '#FF5252';
    }
    if (['NEG', 'SMTH', 'SMOOTH', 'NONE', 'TRACE'].contains(primary)) {
      return '#4CAF50';
    }
    return '#B0B4BC';
  }

  Map<String, dynamic> _buildMetarOverlayGeoJson(
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
          final wspd = m['wspd'] as num?;
          if (wspd == null) continue;
          label = '${wspd.toInt()}';
          if (wspd <= 5) { color = '#4CAF50'; }
          else if (wspd <= 15) { color = '#FFC107'; }
          else if (wspd <= 25) { color = '#FF9800'; }
          else { color = '#FF5252'; }
          break;
        case 'temperature':
          final temp = m['temp'] as num?;
          if (temp == null) continue;
          label = '${temp.toInt()}°';
          if (temp <= 0) { color = '#2196F3'; }
          else if (temp <= 10) { color = '#29B6F6'; }
          else if (temp <= 20) { color = '#4CAF50'; }
          else if (temp <= 30) { color = '#FFC107'; }
          else { color = '#FF5252'; }
          break;
        case 'visibility':
          final visib = m['visib'] as num?;
          if (visib == null) continue;
          label = visib >= 10 ? '10+' : visib.toStringAsFixed(visib < 3 ? 1 : 0);
          if (visib < 1) { color = '#E040FB'; }
          else if (visib < 3) { color = '#FF5252'; }
          else if (visib < 5) { color = '#FFC107'; }
          else { color = '#4CAF50'; }
          break;
        case 'ceiling':
          final clouds = m['clouds'] as List<dynamic>?;
          if (clouds == null || clouds.isEmpty) continue;
          int? cig;
          for (final c in clouds) {
            if (c is Map) {
              final cover = (c['cover'] as String? ?? '').toUpperCase();
              if (cover == 'BKN' || cover == 'OVC') {
                final base = c['base'] as num?;
                if (base != null && (cig == null || base.toInt() < cig)) {
                  cig = base.toInt();
                }
              }
            }
          }
          if (cig == null) continue;
          label = '$cig';
          if (cig < 500) { color = '#E040FB'; }
          else if (cig < 1000) { color = '#FF5252'; }
          else if (cig < 3000) { color = '#FFC107'; }
          else { color = '#4CAF50'; }
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
        },
      });
    }
    return {'type': 'FeatureCollection', 'features': features};
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
