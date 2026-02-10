import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LayerPicker extends StatefulWidget {
  final String selectedBaseLayer;
  final Set<String> activeOverlays;
  final ValueChanged<String> onBaseLayerChanged;
  final ValueChanged<String> onOverlayToggled;
  final VoidCallback onClose;

  const LayerPicker({
    super.key,
    required this.selectedBaseLayer,
    required this.activeOverlays,
    required this.onBaseLayerChanged,
    required this.onOverlayToggled,
    required this.onClose,
  });

  @override
  State<LayerPicker> createState() => _LayerPickerState();
}

class _LayerPickerState extends State<LayerPicker> {
  void _onOverlayTap(String id) {
    // For exclusive weather overlays, turn off the others first
    if (_exclusiveWeatherOverlays.contains(id) &&
        !widget.activeOverlays.contains(id)) {
      for (final other in _exclusiveWeatherOverlays) {
        if (other != id && widget.activeOverlays.contains(other)) {
          widget.onOverlayToggled(other);
        }
      }
    }
    widget.onOverlayToggled(id);
  }

  static const baseLayers = [
    ('vfr', 'VFR Sectional'),
    ('satellite', 'Satellite'),
    ('dark', 'Dark'),
    ('street', 'Street'),
  ];

  static const leftOverlays = [
    ('aeronautical', 'Aeronautical'),
  ];

  static const overlayLayers = [
    ('flight_category', 'Flight Category'),
    ('traffic', 'Traffic'),
    ('tfrs', 'TFRs'),
    ('air_sigmet', 'AIR/SIGMET/CWAs'),
    ('pireps', 'PIREPs'),
    ('_divider', ''),
    ('surface_wind', 'Surface Wind'),
    ('winds_aloft', 'Winds Aloft'),
    ('temperature', 'Temperature'),
    ('visibility', 'Visibility'),
    ('ceiling', 'Ceiling'),
  ];

  /// Weather overlays that are mutually exclusive — only one at a time.
  static const _exclusiveWeatherOverlays = {
    'surface_wind',
    'winds_aloft',
    'temperature',
    'visibility',
    'ceiling',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // absorb taps on the picker itself
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Base layers + aeronautical column
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  ...leftOverlays.map((entry) {
                    final (id, label) = entry;
                    final isActive = widget.activeOverlays.contains(id);
                    return _LayerRow(
                      label: label,
                      isActive: isActive,
                      onTap: () => widget.onOverlayToggled(id),
                    );
                  }),
                  const Divider(color: AppColors.divider, height: 12),
                  ...baseLayers.map((entry) {
                    final (id, label) = entry;
                    final isSelected = widget.selectedBaseLayer == id;
                    return _LayerRow(
                      label: label,
                      isActive: isSelected,
                      onTap: () => widget.onBaseLayerChanged(id),
                    );
                  }),
                ],
              ),
            ),
            Container(
              width: 0.5,
              color: AppColors.divider,
            ),
            // Overlay layers column
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: overlayLayers.length,
                itemBuilder: (context, index) {
                  final (id, label) = overlayLayers[index];
                  if (id == '_divider') {
                    return const Divider(color: AppColors.divider, height: 12);
                  }
                  final isActive = widget.activeOverlays.contains(id);
                  return _LayerRow(
                    label: label,
                    isActive: isActive,
                    onTap: () => _onOverlayTap(id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LayerRow({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primary.withValues(alpha: 0.25) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.accent : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
