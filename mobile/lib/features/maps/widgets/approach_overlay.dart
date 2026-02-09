import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/procedure.dart';
import '../../../services/api_client.dart';
import '../../../services/procedure_providers.dart';

const _sourceId = 'approach-plate';
const _layerId = 'approach-plate-layer';

/// Manages adding/removing an approach plate image overlay on the Mapbox map.
///
/// Tracks the last-shown overlay parameters so it can be re-applied after
/// a Mapbox style reload (which destroys all user-added sources/layers).
class ApproachOverlayController {
  MapboxMap? _map;
  bool _isActive = false;
  int? _activeProcedureId;

  // Saved state for re-application after style reload
  String? _lastImageUrl;
  List<List<double>>? _lastCornerCoords;
  double _lastOpacity = 0.75;

  void attach(MapboxMap map) => _map = map;

  bool get isActive => _isActive;
  int? get activeProcedureId => _activeProcedureId;

  /// Add or update the approach plate overlay on the map.
  Future<void> show({
    required String imageUrl,
    required List<List<double>> cornerCoords,
    required int procedureId,
    double opacity = 0.75,
  }) async {
    final map = _map;
    if (map == null || cornerCoords.length < 4) return;

    // Remove existing source/layer from map (ignore errors if not present)
    await _removeFromMap();

    // Mapbox ImageSource expects coordinates as:
    // [[topLeftLng, topLeftLat], [topRightLng, topRightLat],
    //  [bottomRightLng, bottomRightLat], [bottomLeftLng, bottomLeftLat]]
    try {
      await map.style.addSource(ImageSource(
        id: _sourceId,
        url: imageUrl,
        coordinates: cornerCoords,
      ));

      await map.style.addLayer(RasterLayer(
        id: _layerId,
        sourceId: _sourceId,
        rasterOpacity: opacity,
      ));
    } catch (e) {
      debugPrint('Failed to add approach overlay: $e');
      return;
    }

    _isActive = true;
    _activeProcedureId = procedureId;
    _lastImageUrl = imageUrl;
    _lastCornerCoords = cornerCoords;
    _lastOpacity = opacity;
  }

  /// Remove the approach plate overlay from the map and clear saved state.
  Future<void> hide() async {
    await _removeFromMap();
    _isActive = false;
    _activeProcedureId = null;
    _lastImageUrl = null;
    _lastCornerCoords = null;
  }

  /// Re-apply the overlay after a style reload. Call this from _onStyleLoaded.
  /// Does nothing if no overlay was active.
  Future<void> reapply() async {
    if (!_isActive ||
        _lastImageUrl == null ||
        _lastCornerCoords == null ||
        _activeProcedureId == null) return;

    final url = _lastImageUrl!;
    final coords = _lastCornerCoords!;
    final procId = _activeProcedureId!;
    final opacity = _lastOpacity;

    // Reset active flag so show() doesn't try to remove (already gone after style reload)
    _isActive = false;

    await show(
      imageUrl: url,
      cornerCoords: coords,
      procedureId: procId,
      opacity: opacity,
    );
  }

  /// Update overlay opacity.
  Future<void> setOpacity(double opacity) async {
    final map = _map;
    if (map == null || !_isActive) return;
    _lastOpacity = opacity;
    try {
      await map.style
          .setStyleLayerProperty(_layerId, 'raster-opacity', opacity);
    } catch (_) {}
  }

  /// Remove source/layer from the map without clearing saved state.
  Future<void> _removeFromMap() async {
    final map = _map;
    if (map == null) return;
    try {
      await map.style.removeStyleLayer(_layerId);
    } catch (_) {}
    try {
      await map.style.removeStyleSource(_sourceId);
    } catch (_) {}
  }
}

/// Bottom sheet for selecting an approach plate to overlay on the map.
class ApproachPlatePicker extends ConsumerStatefulWidget {
  final String airportId;
  final ApproachOverlayController overlayController;
  final VoidCallback onOverlayChanged;

  const ApproachPlatePicker({
    super.key,
    required this.airportId,
    required this.overlayController,
    required this.onOverlayChanged,
  });

  @override
  ConsumerState<ApproachPlatePicker> createState() =>
      _ApproachPlatePickerState();
}

class _ApproachPlatePickerState extends ConsumerState<ApproachPlatePicker> {
  double _opacity = 0.75;

  @override
  Widget build(BuildContext context) {
    final proceduresAsync =
        ref.watch(airportProceduresProvider(widget.airportId));

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.15,
      maxChildSize: 0.7,
      snap: true,
      snapSizes: const [0.15, 0.45, 0.7],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title + close
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Text(
                      'Approach Plates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (widget.overlayController.isActive) ...[
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: AppColors.textMuted,
                        onPressed: () async {
                          await widget.overlayController.hide();
                          widget.onOverlayChanged();
                        },
                        tooltip: 'Remove overlay',
                      ),
                    ],
                  ],
                ),
              ),
              // Opacity slider (when overlay is active)
              if (widget.overlayController.isActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.opacity,
                          size: 16, color: AppColors.textMuted),
                      Expanded(
                        child: Slider(
                          value: _opacity,
                          min: 0.1,
                          max: 1.0,
                          activeColor: AppColors.accent,
                          onChanged: (val) {
                            setState(() => _opacity = val);
                            widget.overlayController.setOpacity(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1, color: AppColors.divider),
              // IAP procedure list
              Expanded(
                child: proceduresAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Failed to load procedures',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  data: (grouped) {
                    final iaps = grouped['IAP'] ?? [];
                    if (iaps.isEmpty) {
                      return const Center(
                        child: Text(
                          'No approach procedures available',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: iaps.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 0.5, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final proc = iaps[index];
                        final isActive = widget
                                .overlayController.activeProcedureId ==
                            proc.id;
                        return _ApproachRow(
                          procedure: proc,
                          airportId: widget.airportId,
                          isActive: isActive,
                          onTap: () => _onProcedureTapped(proc),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onProcedureTapped(Procedure proc) async {
    final client = ref.read(apiClientProvider);

    // If already showing this procedure, toggle it off
    if (widget.overlayController.activeProcedureId == proc.id) {
      await widget.overlayController.hide();
      widget.onOverlayChanged();
      return;
    }

    // Fetch georef data
    final georefData = await ref.read(
      procedureGeorefProvider(
        (airportId: widget.airportId, procedureId: proc.id),
      ).future,
    );

    if (georefData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No georef data available for this procedure'),
          ),
        );
      }
      return;
    }

    final corners = georefData.cornerCoordinates;
    if (corners.length < 4) return;

    final imageUrl =
        client.getProcedureImageUrl(widget.airportId, proc.id);

    await widget.overlayController.show(
      imageUrl: imageUrl,
      cornerCoords: corners,
      procedureId: proc.id,
      opacity: _opacity,
    );

    widget.onOverlayChanged();
  }
}

class _ApproachRow extends StatelessWidget {
  final Procedure procedure;
  final String airportId;
  final bool isActive;
  final VoidCallback onTap;

  const _ApproachRow({
    required this.procedure,
    required this.airportId,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive
          ? AppColors.primary.withValues(alpha: 0.25)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.layers : Icons.flight_land,
                size: 18,
                color:
                    isActive ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  procedure.chartName,
                  style: TextStyle(
                    fontSize: 14,
                    color: isActive
                        ? AppColors.accent
                        : AppColors.textPrimary,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isActive)
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: AppColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
