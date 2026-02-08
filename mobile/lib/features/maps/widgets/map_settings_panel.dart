import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MapSettingsPanel extends StatefulWidget {
  final VoidCallback onClose;

  const MapSettingsPanel({
    super.key,
    required this.onClose,
  });

  @override
  State<MapSettingsPanel> createState() => _MapSettingsPanelState();
}

class _MapSettingsPanelState extends State<MapSettingsPanel> {
  double _brightness = 0.3;
  bool _invertChartColors = false;
  final String _mapTheme = 'Dark';
  final String _terrain = 'Colored';
  bool _dayNightOverlay = false;
  bool _placeLabels = true;
  final String _culturalElements = 'All';
  String _autoCenterMode = 'north_up';
  bool _routeLabels = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.card,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // balance close button
                ],
              ),
            ),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Screen Brightness
                  _SectionLabel('SCREEN BRIGHTNESS'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.brightness_low,
                            color: AppColors.textMuted, size: 20),
                        Expanded(
                          child: Slider(
                            value: _brightness,
                            onChanged: (v) =>
                                setState(() => _brightness = v),
                            activeColor: AppColors.accent,
                            inactiveColor: AppColors.divider,
                          ),
                        ),
                        const Icon(Icons.brightness_high,
                            color: AppColors.textMuted, size: 20),
                      ],
                    ),
                  ),

                  _SettingsToggle(
                    label: 'Invert Chart Colors',
                    value: _invertChartColors,
                    onChanged: (v) =>
                        setState(() => _invertChartColors = v),
                  ),
                  const Divider(height: 1, color: AppColors.divider),

                  // ForeFlight Map section
                  _SectionLabel('FOREFLIGHT MAP'),
                  _SettingsNav(
                    label: 'Map Theme',
                    value: _mapTheme,
                    onTap: () {},
                  ),
                  _SettingsNav(
                    label: 'Terrain',
                    value: _terrain,
                    onTap: () {},
                  ),
                  _SettingsToggle(
                    label: 'Day/Night Overlay',
                    value: _dayNightOverlay,
                    onChanged: (v) =>
                        setState(() => _dayNightOverlay = v),
                  ),
                  _SettingsToggle(
                    label: 'Place Labels',
                    value: _placeLabels,
                    onChanged: (v) =>
                        setState(() => _placeLabels = v),
                  ),
                  _SettingsNav(
                    label: 'Cultural Elements',
                    value: _culturalElements,
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: AppColors.divider),

                  // Auto-Center Mode
                  _SectionLabel('AUTO-CENTER MODE'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _CenterModeButton(
                          icon: Icons.north,
                          label: 'North Up',
                          isSelected: _autoCenterMode == 'north_up',
                          onTap: () => setState(
                              () => _autoCenterMode = 'north_up'),
                        ),
                        const SizedBox(width: 12),
                        _CenterModeButton(
                          icon: Icons.flight,
                          label: 'Track Up\nCentered',
                          isSelected:
                              _autoCenterMode == 'track_up_centered',
                          onTap: () => setState(
                              () => _autoCenterMode = 'track_up_centered'),
                        ),
                        const SizedBox(width: 12),
                        _CenterModeButton(
                          icon: Icons.flight,
                          label: 'Track Up\nForward',
                          isSelected:
                              _autoCenterMode == 'track_up_forward',
                          onTap: () => setState(
                              () => _autoCenterMode = 'track_up_forward'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),

                  // Map Overlays
                  _SectionLabel('MAP OVERLAYS'),
                  _SettingsToggle(
                    label: 'Route Labels',
                    value: _routeLabels,
                    onChanged: (v) =>
                        setState(() => _routeLabels = v),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.accent,
            activeThumbColor: Colors.white,
            inactiveTrackColor: AppColors.divider,
          ),
        ],
      ),
    );
  }
}

class _SettingsNav extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SettingsNav({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CenterModeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.textMuted,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
