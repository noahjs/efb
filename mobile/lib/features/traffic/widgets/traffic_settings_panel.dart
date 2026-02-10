import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/traffic_settings.dart';

/// Bottom-sheet traffic settings panel, matching the AeronauticalSettingsPanel
/// style. All state lives in the parent [TrafficSettings] object so it
/// persists across panel open/close cycles.
class TrafficSettingsPanel extends StatelessWidget {
  final VoidCallback onClose;
  final TrafficSettings settings;
  final ValueChanged<TrafficSettings> onChanged;

  const TrafficSettingsPanel({
    super.key,
    required this.onClose,
    required this.settings,
    required this.onChanged,
  });

  void _set(TrafficSettings Function(TrafficSettings s) updater) {
    onChanged(updater(settings));
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;

    return GestureDetector(
      onTap: () {},
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── DISPLAY ──
                  const _SectionHeader('DISPLAY'),
                  _ToggleRow(
                    label: 'Show Projected Heads',
                    value: s.showHeads,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showHeads: v)),
                  ),
                  if (s.showHeads) ...[
                    const _Divider(),
                    _RadioRow(
                      label: '60-Second Line',
                      selected: s.headStyle == HeadStyle.line60s,
                      onTap: () => _set(
                          (s) => s.copyWith(headStyle: HeadStyle.line60s)),
                      indent: true,
                    ),
                    const _Divider(),
                    _RadioRow(
                      label: '2 / 5 Min with Bubbles',
                      selected: s.headStyle == HeadStyle.bubbles2m5m,
                      onTap: () => _set(
                          (s) => s.copyWith(headStyle: HeadStyle.bubbles2m5m)),
                      indent: true,
                    ),
                  ],
                  const _Divider(),
                  _ToggleRow(
                    label: 'Show Labels',
                    value: s.showLabels,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showLabels: v)),
                  ),
                  const _Divider(),
                  _ToggleRow(
                    label: 'Hide Ground Traffic',
                    value: s.hideGround,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(hideGround: v)),
                  ),
                  const _SectionDivider(),

                  // ── ALTITUDE FILTER ──
                  const _SectionHeader('ALTITUDE FILTER'),
                  _RadioRow(
                    label: 'All Traffic',
                    selected: s.altitudeFilter == AltitudeFilter.all,
                    onTap: () => _set(
                        (s) => s.copyWith(altitudeFilter: AltitudeFilter.all)),
                  ),
                  const _Divider(),
                  _RadioRow(
                    label: 'Within \u00b11,000 ft',
                    selected: s.altitudeFilter == AltitudeFilter.within1000,
                    onTap: () => _set((s) =>
                        s.copyWith(altitudeFilter: AltitudeFilter.within1000)),
                  ),
                  const _Divider(),
                  _RadioRow(
                    label: 'Within \u00b13,000 ft',
                    selected: s.altitudeFilter == AltitudeFilter.within3000,
                    onTap: () => _set((s) =>
                        s.copyWith(altitudeFilter: AltitudeFilter.within3000)),
                  ),
                  const _Divider(),
                  _RadioRow(
                    label: 'Within \u00b15,000 ft',
                    selected: s.altitudeFilter == AltitudeFilter.within5000,
                    onTap: () => _set((s) =>
                        s.copyWith(altitudeFilter: AltitudeFilter.within5000)),
                  ),
                  const _Divider(),
                  _RadioRow(
                    label: 'Below FL180 Only',
                    selected: s.altitudeFilter == AltitudeFilter.belowFL180,
                    onTap: () => _set((s) =>
                        s.copyWith(altitudeFilter: AltitudeFilter.belowFL180)),
                  ),
                  const _Divider(),
                  _RadioRow(
                    label: 'Above FL180 Only',
                    selected: s.altitudeFilter == AltitudeFilter.aboveFL180,
                    onTap: () => _set((s) =>
                        s.copyWith(altitudeFilter: AltitudeFilter.aboveFL180)),
                  ),
                  const _SectionDivider(),

                  // ── ALERTS ──
                  const _SectionHeader('ALERTS'),
                  _ToggleRow(
                    label: 'Proximity Alerts',
                    value: s.proximityAlerts,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(proximityAlerts: v)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Traffic Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 60), // balance close button
        ],
      ),
    );
  }
}

// ── Private sub-widgets ──

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 32,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.accent,
              activeThumbColor: Colors.white,
              inactiveTrackColor: AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool indent;

  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: indent ? 40 : 16,
          right: 16,
          top: 12,
          bottom: 12,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.only(top: 8),
      color: AppColors.card,
    );
  }
}
