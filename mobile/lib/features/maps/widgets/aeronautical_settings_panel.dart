import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

/// All aeronautical settings state, persisted in MapsScreen across
/// panel open/close cycles.
class AeroSettings {
  // Map display
  final bool placeLabels;

  // Airport
  final bool airportsOnly;
  final bool showHeliports;
  final bool showPrivateAirports;
  final bool showSeaplaneBases;
  final bool showOtherFields;

  // Airspace — controlled
  final bool autoHighlight;
  final bool activationByNotam;
  final bool showAirspaces;
  final bool showTrsa;
  final bool showClassE;
  final bool showModeC;

  // Airspace — special use
  final bool showSua;
  final bool showProhibitedRestricted;
  final bool showMoaAlertTraining;
  final bool showCautionDangerWarning;
  final bool showTraTsa;
  final bool showParachuteAreas;
  final bool showAdiz;
  final bool showSuaOther;
  final bool worldwideAltitudes;

  // Airways
  final bool showAirways;
  final bool showLowAirways;
  final bool showHighAirways;
  final bool showHelicopterAirways;

  // Waypoints
  final bool showWaypoints;
  final bool showFixesRnav;
  final bool showVfrWaypoints;
  final bool showVfrHelicopterWaypoints;

  // ATC boundaries
  final bool showAtcBoundaries;
  final bool showArtcc;
  final bool showAtcSectors;

  // Other
  final bool showOrganizedTracks;
  final bool showGridMora;

  const AeroSettings({
    this.placeLabels = true,
    this.airportsOnly = true,
    this.showHeliports = true,
    this.showPrivateAirports = true,
    this.showSeaplaneBases = false,
    this.showOtherFields = true,
    this.autoHighlight = false,
    this.activationByNotam = true,
    this.showAirspaces = true,
    this.showTrsa = true,
    this.showClassE = false,
    this.showModeC = true,
    this.showSua = true,
    this.showProhibitedRestricted = true,
    this.showMoaAlertTraining = true,
    this.showCautionDangerWarning = true,
    this.showTraTsa = true,
    this.showParachuteAreas = true,
    this.showAdiz = true,
    this.showSuaOther = true,
    this.worldwideAltitudes = true,
    this.showAirways = false,
    this.showLowAirways = true,
    this.showHighAirways = true,
    this.showHelicopterAirways = false,
    this.showWaypoints = true,
    this.showFixesRnav = true,
    this.showVfrWaypoints = true,
    this.showVfrHelicopterWaypoints = true,
    this.showAtcBoundaries = true,
    this.showArtcc = true,
    this.showAtcSectors = false,
    this.showOrganizedTracks = false,
    this.showGridMora = false,
  });

  AeroSettings copyWith({
    bool? placeLabels,
    bool? airportsOnly,
    bool? showHeliports,
    bool? showPrivateAirports,
    bool? showSeaplaneBases,
    bool? showOtherFields,
    bool? autoHighlight,
    bool? activationByNotam,
    bool? showAirspaces,
    bool? showTrsa,
    bool? showClassE,
    bool? showModeC,
    bool? showSua,
    bool? showProhibitedRestricted,
    bool? showMoaAlertTraining,
    bool? showCautionDangerWarning,
    bool? showTraTsa,
    bool? showParachuteAreas,
    bool? showAdiz,
    bool? showSuaOther,
    bool? worldwideAltitudes,
    bool? showAirways,
    bool? showLowAirways,
    bool? showHighAirways,
    bool? showHelicopterAirways,
    bool? showWaypoints,
    bool? showFixesRnav,
    bool? showVfrWaypoints,
    bool? showVfrHelicopterWaypoints,
    bool? showAtcBoundaries,
    bool? showArtcc,
    bool? showAtcSectors,
    bool? showOrganizedTracks,
    bool? showGridMora,
  }) {
    return AeroSettings(
      placeLabels: placeLabels ?? this.placeLabels,
      airportsOnly: airportsOnly ?? this.airportsOnly,
      showHeliports: showHeliports ?? this.showHeliports,
      showPrivateAirports: showPrivateAirports ?? this.showPrivateAirports,
      showSeaplaneBases: showSeaplaneBases ?? this.showSeaplaneBases,
      showOtherFields: showOtherFields ?? this.showOtherFields,
      autoHighlight: autoHighlight ?? this.autoHighlight,
      activationByNotam: activationByNotam ?? this.activationByNotam,
      showAirspaces: showAirspaces ?? this.showAirspaces,
      showTrsa: showTrsa ?? this.showTrsa,
      showClassE: showClassE ?? this.showClassE,
      showModeC: showModeC ?? this.showModeC,
      showSua: showSua ?? this.showSua,
      showProhibitedRestricted:
          showProhibitedRestricted ?? this.showProhibitedRestricted,
      showMoaAlertTraining:
          showMoaAlertTraining ?? this.showMoaAlertTraining,
      showCautionDangerWarning:
          showCautionDangerWarning ?? this.showCautionDangerWarning,
      showTraTsa: showTraTsa ?? this.showTraTsa,
      showParachuteAreas: showParachuteAreas ?? this.showParachuteAreas,
      showAdiz: showAdiz ?? this.showAdiz,
      showSuaOther: showSuaOther ?? this.showSuaOther,
      worldwideAltitudes: worldwideAltitudes ?? this.worldwideAltitudes,
      showAirways: showAirways ?? this.showAirways,
      showLowAirways: showLowAirways ?? this.showLowAirways,
      showHighAirways: showHighAirways ?? this.showHighAirways,
      showHelicopterAirways:
          showHelicopterAirways ?? this.showHelicopterAirways,
      showWaypoints: showWaypoints ?? this.showWaypoints,
      showFixesRnav: showFixesRnav ?? this.showFixesRnav,
      showVfrWaypoints: showVfrWaypoints ?? this.showVfrWaypoints,
      showVfrHelicopterWaypoints:
          showVfrHelicopterWaypoints ?? this.showVfrHelicopterWaypoints,
      showAtcBoundaries: showAtcBoundaries ?? this.showAtcBoundaries,
      showArtcc: showArtcc ?? this.showArtcc,
      showAtcSectors: showAtcSectors ?? this.showAtcSectors,
      showOrganizedTracks: showOrganizedTracks ?? this.showOrganizedTracks,
      showGridMora: showGridMora ?? this.showGridMora,
    );
  }

  Map<String, dynamic> toJson() => {
        'placeLabels': placeLabels,
        'airportsOnly': airportsOnly,
        'showHeliports': showHeliports,
        'showPrivateAirports': showPrivateAirports,
        'showSeaplaneBases': showSeaplaneBases,
        'showOtherFields': showOtherFields,
        'autoHighlight': autoHighlight,
        'activationByNotam': activationByNotam,
        'showAirspaces': showAirspaces,
        'showTrsa': showTrsa,
        'showClassE': showClassE,
        'showModeC': showModeC,
        'showSua': showSua,
        'showProhibitedRestricted': showProhibitedRestricted,
        'showMoaAlertTraining': showMoaAlertTraining,
        'showCautionDangerWarning': showCautionDangerWarning,
        'showTraTsa': showTraTsa,
        'showParachuteAreas': showParachuteAreas,
        'showAdiz': showAdiz,
        'showSuaOther': showSuaOther,
        'worldwideAltitudes': worldwideAltitudes,
        'showAirways': showAirways,
        'showLowAirways': showLowAirways,
        'showHighAirways': showHighAirways,
        'showHelicopterAirways': showHelicopterAirways,
        'showWaypoints': showWaypoints,
        'showFixesRnav': showFixesRnav,
        'showVfrWaypoints': showVfrWaypoints,
        'showVfrHelicopterWaypoints': showVfrHelicopterWaypoints,
        'showAtcBoundaries': showAtcBoundaries,
        'showArtcc': showArtcc,
        'showAtcSectors': showAtcSectors,
        'showOrganizedTracks': showOrganizedTracks,
        'showGridMora': showGridMora,
      };

  static AeroSettings fromJson(Map<String, dynamic> j) {
    bool b(String key, bool fallback) => (j[key] as bool?) ?? fallback;
    const d = AeroSettings();
    return AeroSettings(
      placeLabels: b('placeLabels', d.placeLabels),
      airportsOnly: b('airportsOnly', d.airportsOnly),
      showHeliports: b('showHeliports', d.showHeliports),
      showPrivateAirports: b('showPrivateAirports', d.showPrivateAirports),
      showSeaplaneBases: b('showSeaplaneBases', d.showSeaplaneBases),
      showOtherFields: b('showOtherFields', d.showOtherFields),
      autoHighlight: b('autoHighlight', d.autoHighlight),
      activationByNotam: b('activationByNotam', d.activationByNotam),
      showAirspaces: b('showAirspaces', d.showAirspaces),
      showTrsa: b('showTrsa', d.showTrsa),
      showClassE: b('showClassE', d.showClassE),
      showModeC: b('showModeC', d.showModeC),
      showSua: b('showSua', d.showSua),
      showProhibitedRestricted:
          b('showProhibitedRestricted', d.showProhibitedRestricted),
      showMoaAlertTraining:
          b('showMoaAlertTraining', d.showMoaAlertTraining),
      showCautionDangerWarning:
          b('showCautionDangerWarning', d.showCautionDangerWarning),
      showTraTsa: b('showTraTsa', d.showTraTsa),
      showParachuteAreas: b('showParachuteAreas', d.showParachuteAreas),
      showAdiz: b('showAdiz', d.showAdiz),
      showSuaOther: b('showSuaOther', d.showSuaOther),
      worldwideAltitudes: b('worldwideAltitudes', d.worldwideAltitudes),
      showAirways: b('showAirways', d.showAirways),
      showLowAirways: b('showLowAirways', d.showLowAirways),
      showHighAirways: b('showHighAirways', d.showHighAirways),
      showHelicopterAirways:
          b('showHelicopterAirways', d.showHelicopterAirways),
      showWaypoints: b('showWaypoints', d.showWaypoints),
      showFixesRnav: b('showFixesRnav', d.showFixesRnav),
      showVfrWaypoints: b('showVfrWaypoints', d.showVfrWaypoints),
      showVfrHelicopterWaypoints:
          b('showVfrHelicopterWaypoints', d.showVfrHelicopterWaypoints),
      showAtcBoundaries: b('showAtcBoundaries', d.showAtcBoundaries),
      showArtcc: b('showArtcc', d.showArtcc),
      showAtcSectors: b('showAtcSectors', d.showAtcSectors),
      showOrganizedTracks: b('showOrganizedTracks', d.showOrganizedTracks),
      showGridMora: b('showGridMora', d.showGridMora),
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
                  // ── MAP DISPLAY SETTINGS ──
                  const _SectionHeader('MAP DISPLAY SETTINGS'),
                  const _NavRow(label: 'Map Theme', value: 'Dark'),
                  const _Divider(),
                  const _NavRow(label: 'Terrain', value: 'Colored'),
                  const _Divider(),
                  const _NavRow(label: 'Cultural Elements', value: 'All'),
                  const _Divider(),
                  _ToggleRow(
                    label: 'Place Labels',
                    value: s.placeLabels,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(placeLabels: v)),
                  ),
                  const _SectionDivider(),

                  // ── Info text ──
                  const _InfoText(
                    'Map display settings above apply across all aeronautical modes. '
                    'The VFR settings below apply only to the VFR mode.',
                  ),

                  // ── VFR Settings header ──
                  const _ModeHeader('VFR Settings'),

                  // ── AIRPORT SETTINGS ──
                  const _SectionHeader('AIRPORT SETTINGS'),
                  _ToggleRow(
                    label: 'Heliports',
                    value: s.showHeliports,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showHeliports: v)),
                  ),
                  const _Divider(),
                  _ToggleRow(
                    label: 'Private Airports',
                    value: s.showPrivateAirports,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showPrivateAirports: v)),
                  ),
                  const _Divider(),
                  _ToggleRow(
                    label: 'Seaplane Bases',
                    value: s.showSeaplaneBases,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showSeaplaneBases: v)),
                  ),
                  const _Divider(),
                  _ToggleRow(
                    label: 'Other Fields',
                    value: s.showOtherFields,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showOtherFields: v)),
                  ),
                  const _Divider(),
                  const _NavRow(label: 'Min. Rwy Length', value: 'None'),
                  const _InfoText(
                    'Minimum runway length is based on the total length of the runway. '
                    'Review runway details for displaced threshold & other information.',
                  ),
                  const _SectionDivider(),

                  // ── AIRSPACE SETTINGS ──
                  const _SectionHeader('AIRSPACE SETTINGS'),
                  _ToggleRow(
                    label: 'Auto Highlight',
                    value: s.autoHighlight,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(autoHighlight: v)),
                  ),
                  const _Divider(),
                  const _NavRow(
                      label: 'Hide Airspace Above (FT)', value: 'Show All'),
                  const _Divider(),
                  _ToggleRow(
                    label: 'Activation by NOTAM',
                    value: s.activationByNotam,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(activationByNotam: v)),
                  ),
                  const _InfoText(
                    'Disabling Activation by NOTAM will hide airspaces that are only '
                    'activated by NOTAM.',
                  ),
                  const _Divider(),

                  // Controlled Airspace (master)
                  _ToggleRow(
                    label: 'Controlled Airspace',
                    value: s.showAirspaces,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showAirspaces: v)),
                  ),
                  if (s.showAirspaces) ...[
                    const _Divider(),
                    _ToggleRow(
                      label: 'TRSA',
                      value: s.showTrsa,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showTrsa: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'Class E',
                      value: s.showClassE,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showClassE: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'Mode C',
                      value: s.showModeC,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showModeC: v)),
                      indent: true,
                    ),
                  ],
                  const _SectionDivider(),

                  // Special Use Airspace (master)
                  _ToggleRow(
                    label: 'Special Use Airspace',
                    value: s.showSua,
                    onChanged: (v) => _set((s) => s.copyWith(showSua: v)),
                  ),
                  if (s.showSua) ...[
                    const _Divider(),
                    _ToggleRow(
                      label: 'Prohibited & Restricted',
                      value: s.showProhibitedRestricted,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showProhibitedRestricted: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'MOA, Alert, & Training',
                      value: s.showMoaAlertTraining,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showMoaAlertTraining: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'Caution, Danger, & Warning',
                      value: s.showCautionDangerWarning,
                      onChanged: (v) => _set(
                          (s) => s.copyWith(showCautionDangerWarning: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'TRA & TSA',
                      value: s.showTraTsa,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showTraTsa: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'Parachute Areas (USA)',
                      value: s.showParachuteAreas,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showParachuteAreas: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'ADIZ',
                      value: s.showAdiz,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showAdiz: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'Other',
                      value: s.showSuaOther,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showSuaOther: v)),
                      indent: true,
                    ),
                  ],
                  const _SectionDivider(),

                  // Worldwide Altitudes
                  _ToggleRow(
                    label: 'Worldwide Altitudes',
                    value: s.worldwideAltitudes,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(worldwideAltitudes: v)),
                  ),
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
                    const _Divider(),
                    _ToggleRow(
                      label: 'Helicopter',
                      value: s.showHelicopterAirways,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showHelicopterAirways: v)),
                      indent: true,
                    ),
                  ],
                  const _SectionDivider(),

                  // ── WAYPOINT SETTINGS ──
                  const _SectionHeader('WAYPOINT SETTINGS'),
                  _ToggleRow(
                    label: 'Waypoints',
                    value: s.showWaypoints,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showWaypoints: v)),
                  ),
                  if (s.showWaypoints) ...[
                    const _Divider(),
                    _ToggleRow(
                      label: 'Fixes & RNAV',
                      value: s.showFixesRnav,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showFixesRnav: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'VFR Waypoints',
                      value: s.showVfrWaypoints,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showVfrWaypoints: v)),
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'VFR Helicopter Waypoints',
                      value: s.showVfrHelicopterWaypoints,
                      onChanged: (v) => _set(
                          (s) => s.copyWith(showVfrHelicopterWaypoints: v)),
                      indent: true,
                    ),
                  ],
                  const _SectionDivider(),

                  // ── ATC BOUNDARY SETTINGS ──
                  const _SectionHeader('ATC BOUNDARY SETTINGS'),
                  _ToggleRow(
                    label: 'ATC Boundaries',
                    value: s.showAtcBoundaries,
                    onChanged: (v) {
                      // When master is toggled, also sync ARTCC
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
                    const _Divider(),
                    _ToggleRow(
                      label: 'ATC Sectors',
                      value: s.showAtcSectors,
                      onChanged: (v) =>
                          _set((s) => s.copyWith(showAtcSectors: v)),
                      indent: true,
                    ),
                  ],
                  const _SectionDivider(),

                  // ── ORGANIZED TRACKS SETTINGS ──
                  const _SectionHeader('ORGANIZED TRACKS SETTINGS'),
                  _ToggleRow(
                    label: 'Show Organized Tracks',
                    value: s.showOrganizedTracks,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showOrganizedTracks: v)),
                  ),
                  const _SectionDivider(),

                  // ── GRID MORA/LSALT SETTINGS ──
                  const _SectionHeader('GRID MORA/LSALT SETTINGS'),
                  _ToggleRow(
                    label: 'Grid MORA/LSALT (ft)',
                    value: s.showGridMora,
                    onChanged: (v) =>
                        _set((s) => s.copyWith(showGridMora: v)),
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

class _ModeHeader extends StatelessWidget {
  final String label;
  const _ModeHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.accent.withValues(alpha: 0.85),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
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

class _NavRow extends StatelessWidget {
  final String label;
  final String value;

  const _NavRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
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
    );
  }
}

class _InfoText extends StatelessWidget {
  final String text;
  const _InfoText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textMuted.withValues(alpha: 0.7),
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
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
