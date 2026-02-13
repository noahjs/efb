import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

/// All aeronautical settings state, persisted in MapsScreen across
/// panel open/close cycles.
class AeroSettings {
  // Airport
  final bool showAirports;
  final bool showHeliports;
  final bool showPrivateAirports;
  final bool showSeaplaneBases;
  final bool showOtherFields;

  // Airspace — controlled
  final bool showAirspaces;
  final bool showClassE;

  // Airways
  final bool showAirways;
  final bool showLowAirways;
  final bool showHighAirways;

  // Navaids & Fixes
  final bool showNavaids;
  final bool showFixes;

  // ATC boundaries
  final bool showAtcBoundaries;
  final bool showArtcc;

  const AeroSettings({
    this.showAirports = true,
    this.showHeliports = true,
    this.showPrivateAirports = true,
    this.showSeaplaneBases = true,
    this.showOtherFields = true,
    this.showAirspaces = true,
    this.showClassE = false,
    this.showAirways = true,
    this.showLowAirways = true,
    this.showHighAirways = true,
    this.showNavaids = true,
    this.showFixes = true,
    this.showAtcBoundaries = true,
    this.showArtcc = true,
  });

  AeroSettings copyWith({
    bool? showAirports,
    bool? showHeliports,
    bool? showPrivateAirports,
    bool? showSeaplaneBases,
    bool? showOtherFields,
    bool? showAirspaces,
    bool? showClassE,
    bool? showAirways,
    bool? showLowAirways,
    bool? showHighAirways,
    bool? showNavaids,
    bool? showFixes,
    bool? showAtcBoundaries,
    bool? showArtcc,
  }) {
    return AeroSettings(
      showAirports: showAirports ?? this.showAirports,
      showHeliports: showHeliports ?? this.showHeliports,
      showPrivateAirports: showPrivateAirports ?? this.showPrivateAirports,
      showSeaplaneBases: showSeaplaneBases ?? this.showSeaplaneBases,
      showOtherFields: showOtherFields ?? this.showOtherFields,
      showAirspaces: showAirspaces ?? this.showAirspaces,
      showClassE: showClassE ?? this.showClassE,
      showAirways: showAirways ?? this.showAirways,
      showLowAirways: showLowAirways ?? this.showLowAirways,
      showHighAirways: showHighAirways ?? this.showHighAirways,
      showNavaids: showNavaids ?? this.showNavaids,
      showFixes: showFixes ?? this.showFixes,
      showAtcBoundaries: showAtcBoundaries ?? this.showAtcBoundaries,
      showArtcc: showArtcc ?? this.showArtcc,
    );
  }

  Map<String, dynamic> toJson() => {
        'showAirports': showAirports,
        'showHeliports': showHeliports,
        'showPrivateAirports': showPrivateAirports,
        'showSeaplaneBases': showSeaplaneBases,
        'showOtherFields': showOtherFields,
        'showAirspaces': showAirspaces,
        'showClassE': showClassE,
        'showAirways': showAirways,
        'showLowAirways': showLowAirways,
        'showHighAirways': showHighAirways,
        'showNavaids': showNavaids,
        'showFixes': showFixes,
        'showAtcBoundaries': showAtcBoundaries,
        'showArtcc': showArtcc,
      };

  static AeroSettings fromJson(Map<String, dynamic> j) {
    bool b(String key, bool fallback) => (j[key] as bool?) ?? fallback;
    const d = AeroSettings();
    return AeroSettings(
      showAirports: b('showAirports', d.showAirports),
      showHeliports: b('showHeliports', d.showHeliports),
      showPrivateAirports: b('showPrivateAirports', d.showPrivateAirports),
      showSeaplaneBases: b('showSeaplaneBases', d.showSeaplaneBases),
      showOtherFields: b('showOtherFields', d.showOtherFields),
      showAirspaces: b('showAirspaces', d.showAirspaces),
      showClassE: b('showClassE', d.showClassE),
      showAirways: b('showAirways', d.showAirways),
      showLowAirways: b('showLowAirways', d.showLowAirways),
      showHighAirways: b('showHighAirways', d.showHighAirways),
      showNavaids: b('showNavaids', d.showNavaids),
      showFixes: b('showFixes', d.showFixes),
      showAtcBoundaries: b('showAtcBoundaries', d.showAtcBoundaries),
      showArtcc: b('showArtcc', d.showArtcc),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('map_aero_settings', jsonEncode(toJson()));
  }

  static Future<AeroSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('map_aero_settings');
    if (str == null) return const AeroSettings();
    try {
      return fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return const AeroSettings();
    }
  }
}

/// ForeFlight-style "Aeronautical Settings" bottom sheet panel.
/// Opened from the sidebar gear icon, slides up over the bottom half of the map.
///
/// All state lives in the parent [AeroSettings] object so it persists
/// across panel open/close cycles. Each toggle calls [onChanged] with
/// an updated copy.
class AeronauticalSettingsPanel extends StatelessWidget {
  final VoidCallback onClose;
  final AeroSettings settings;
  final ValueChanged<AeroSettings> onChanged;

  const AeronauticalSettingsPanel({
    super.key,
    required this.onClose,
    required this.settings,
    required this.onChanged,
  });

  void _set(AeroSettings Function(AeroSettings s) updater) {
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
            // Header bar
            _buildHeader(),

            // Scrollable settings
            Flexible(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── AIRPORT SETTINGS ──
                  const _SectionHeader('AIRPORT SETTINGS'),
                  _ToggleRow(
                    label: 'Airports',
                    value: s.showAirports,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showAirports: v)),
                  ),
                  if (s.showAirports) ...[
                    const _Divider(),
                    _ToggleRow(
                      label: 'Heliports',
                      value: s.showHeliports,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showHeliports: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'Private Airports',
                      value: s.showPrivateAirports,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showPrivateAirports: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'Seaplane Bases',
                      value: s.showSeaplaneBases,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showSeaplaneBases: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'Other Fields',
                      value: s.showOtherFields,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showOtherFields: v)),
                      indent: true,
                    ),
                  ],
                  const _SectionDivider(),

                  // ── AIRSPACE SETTINGS ──
                  const _SectionHeader('AIRSPACE SETTINGS'),
                  _ToggleRow(
                    label: 'Controlled Airspace',
                    value: s.showAirspaces,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showAirspaces: v)),
                  ),
                  if (s.showAirspaces) ...[
                    const _Divider(),
                    _ToggleRow(
                      label: 'Class E',
                      value: s.showClassE,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showClassE: v)),
                      indent: true,
                    ),
                  ],
                  const _SectionDivider(),

                  // ── AIRWAY SETTINGS ──
                  const _SectionHeader('AIRWAY SETTINGS'),
                  _ToggleRow(
                    label: 'Airways',
                    value: s.showAirways,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showAirways: v)),
                  ),
                  if (s.showAirways) ...[
                    const _Divider(),
                    _ToggleRow(
                      label: 'Low',
                      value: s.showLowAirways,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showLowAirways: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'High',
                      value: s.showHighAirways,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showHighAirways: v)),
                      indent: true,
                    ),
                  ],
                  const _SectionDivider(),

                  // ── NAVAID & FIX SETTINGS ──
                  const _SectionHeader('NAVAIDS & FIXES'),
                  _ToggleRow(
                    label: 'Navaids (VOR/NDB)',
                    value: s.showNavaids,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showNavaids: v)),
                  ),
                  const _Divider(),
                  _ToggleRow(
                    label: 'Fixes / Waypoints',
                    value: s.showFixes,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showFixes: v)),
                  ),
                  const _SectionDivider(),

                  // ── ATC BOUNDARY SETTINGS ──
                  const _SectionHeader('ATC BOUNDARY SETTINGS'),
                  _ToggleRow(
                    label: 'ATC Boundaries',
                    value: s.showAtcBoundaries,
                    onChanged: (v) {
                      if (v) {
                        _set((s) => s.copyWith(
                            showAtcBoundaries: true, showArtcc: true));
                      } else {
                        _set((s) => s.copyWith(
                            showAtcBoundaries: false, showArtcc: false));
                      }
                    },
                  ),
                  if (s.showAtcBoundaries) ...[
                    const _Divider(),
                    _ToggleRow(
                      label: 'ARTCC/FIRs',
                      value: s.showArtcc,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showArtcc: v)),
                      indent: true,
                    ),
                  ],
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
              'Aeronautical Settings',
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
  final bool indent;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: indent ? 40 : 16,
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
