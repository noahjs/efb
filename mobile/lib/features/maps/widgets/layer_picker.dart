import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LayerPicker extends StatefulWidget {
  final String selectedBaseLayer;
  final ValueChanged<String> onBaseLayerChanged;
  final VoidCallback onClose;

  const LayerPicker({
    super.key,
    required this.selectedBaseLayer,
    required this.onBaseLayerChanged,
    required this.onClose,
  });

  @override
  State<LayerPicker> createState() => _LayerPickerState();
}

class _LayerPickerState extends State<LayerPicker> {
  final Set<String> _activeOverlays = {'flight_category'};

  static const baseLayers = [
    ('vfr', 'VFR Sectional'),
    ('satellite', 'Satellite'),
    ('street', 'Street'),
  ];

  static const overlayLayers = [
    ('aeronautical', 'Aeronautical'),
    ('radar', 'Radar'),
    ('radar_classic', 'Radar (Classic)'),
    ('radar_lowest', 'Radar (Lowest Tilt)'),
    ('satellite_enhanced', 'Satellite (Enhanced)'),
    ('satellite_ir', 'Satellite (Color IR)'),
    ('icing', 'Icing (US)'),
    ('turbulence', 'Turbulence (US)'),
    ('clouds', 'Clouds'),
    ('surface_analysis', 'Surface Analysis'),
    ('winds_temps', 'Winds (Temps)'),
    ('winds_speeds', 'Winds (Speeds)'),
    ('hazard_advisor', 'Hazard Advisor'),
    ('traffic', 'Traffic'),
    ('air_sigmet', 'AIR/SIGMET/CWAs'),
    ('notams', 'NOTAMs'),
    ('tfrs', 'TFRs'),
    ('cameras', 'Cameras'),
    ('flight_category', 'Flight Category'),
    ('surface_wind', 'Surface Wind'),
    ('winds_aloft', 'Winds Aloft'),
    ('dewpoint_spread', 'Dewpoint Spread'),
    ('temperature', 'Temperature'),
    ('visibility', 'Visibility'),
    ('ceiling', 'Ceiling'),
    ('sky_coverage', 'Sky Coverage'),
    ('pireps', 'PIREPs'),
    ('lightning', 'Lightning'),
    ('obstacles', 'Obstacles'),
    ('user_waypoints', 'User Waypoints'),
    ('fuel_100ll', 'Fuel: 100LL'),
    ('fuel_jeta', 'Fuel: Jet A'),
  ];

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
            // Base layers column
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: baseLayers.length,
                itemBuilder: (context, index) {
                  final (id, label) = baseLayers[index];
                  final isSelected = widget.selectedBaseLayer == id;
                  return _LayerRow(
                    label: label,
                    isActive: isSelected,
                    onTap: () {
                      widget.onBaseLayerChanged(id);
                      widget.onClose();
                    },
                  );
                },
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
                  final isActive = _activeOverlays.contains(id);
                  return _LayerRow(
                    label: label,
                    isActive: isActive,
                    onTap: () {
                      setState(() {
                        if (isActive) {
                          _activeOverlays.remove(id);
                        } else {
                          _activeOverlays.add(id);
                        }
                      });
                    },
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
