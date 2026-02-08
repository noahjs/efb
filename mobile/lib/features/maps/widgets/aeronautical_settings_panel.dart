import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// ForeFlight-style "Aeronautical Settings" bottom sheet panel.
/// Opened from the sidebar gear icon, slides up over the bottom half of the map.
///
/// Manages its own local state so toggles update immediately in the sheet,
/// while also calling parent callbacks so the map layers update in real-time.
class AeronauticalSettingsPanel extends StatefulWidget {
  final VoidCallback onClose;

  // Initial values
  final bool showAirspaces;
  final ValueChanged<bool> onAirspacesChanged;
  final bool showClassE;
  final ValueChanged<bool> onClassEChanged;

  final bool showAirways;
  final ValueChanged<bool> onAirwaysChanged;
  final bool showLowAirways;
  final ValueChanged<bool> onLowAirwaysChanged;
  final bool showHighAirways;
  final ValueChanged<bool> onHighAirwaysChanged;

  final bool showArtcc;
  final ValueChanged<bool> onArtccChanged;

  final bool airportsOnly;
  final ValueChanged<bool> onAirportsOnlyChanged;

  const AeronauticalSettingsPanel({
    super.key,
    required this.onClose,
    required this.showAirspaces,
    required this.onAirspacesChanged,
    required this.showClassE,
    required this.onClassEChanged,
    required this.showAirways,
    required this.onAirwaysChanged,
    required this.showLowAirways,
    required this.onLowAirwaysChanged,
    required this.showHighAirways,
    required this.onHighAirwaysChanged,
    required this.showArtcc,
    required this.onArtccChanged,
    required this.airportsOnly,
    required this.onAirportsOnlyChanged,
  });

  @override
  State<AeronauticalSettingsPanel> createState() =>
      _AeronauticalSettingsPanelState();
}

class _AeronauticalSettingsPanelState extends State<AeronauticalSettingsPanel> {
  late bool _showAirspaces;
  late bool _showClassE;
  late bool _showAirways;
  late bool _showLowAirways;
  late bool _showHighAirways;
  late bool _showArtcc;
  late bool _airportsOnly;

  @override
  void initState() {
    super.initState();
    _showAirspaces = widget.showAirspaces;
    _showClassE = widget.showClassE;
    _showAirways = widget.showAirways;
    _showLowAirways = widget.showLowAirways;
    _showHighAirways = widget.showHighAirways;
    _showArtcc = widget.showArtcc;
    _airportsOnly = widget.airportsOnly;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // absorb taps so they don't dismiss
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
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.card,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
            ),

            // Scrollable settings
            Flexible(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // --- AIRPORT SETTINGS ---
                  const _SectionHeader('AIRPORT SETTINGS'),
                  _ToggleRow(
                    label: 'Airports Only',
                    value: _airportsOnly,
                    onChanged: (v) {
                      setState(() => _airportsOnly = v);
                      widget.onAirportsOnlyChanged(v);
                    },
                  ),
                  const _SectionDivider(),

                  // --- AIRSPACE SETTINGS ---
                  const _SectionHeader('AIRSPACE SETTINGS'),
                  _ToggleRow(
                    label: 'Controlled Airspace',
                    value: _showAirspaces,
                    onChanged: (v) {
                      setState(() => _showAirspaces = v);
                      widget.onAirspacesChanged(v);
                    },
                  ),
                  if (_showAirspaces) ...[
                    const _Divider(),
                    _ToggleRow(
                      label: 'Class E',
                      value: _showClassE,
                      onChanged: (v) {
                        setState(() => _showClassE = v);
                        widget.onClassEChanged(v);
                      },
                      indent: true,
                    ),
                  ],
                  const _SectionDivider(),

                  // --- AIRWAY SETTINGS ---
                  const _SectionHeader('AIRWAY SETTINGS'),
                  _ToggleRow(
                    label: 'Airways',
                    value: _showAirways,
                    onChanged: (v) {
                      setState(() => _showAirways = v);
                      widget.onAirwaysChanged(v);
                    },
                  ),
                  if (_showAirways) ...[
                    const _Divider(),
                    _ToggleRow(
                      label: 'Low (Victor)',
                      value: _showLowAirways,
                      onChanged: (v) {
                        setState(() => _showLowAirways = v);
                        widget.onLowAirwaysChanged(v);
                      },
                      indent: true,
                    ),
                    const _Divider(),
                    _ToggleRow(
                      label: 'High (Jet)',
                      value: _showHighAirways,
                      onChanged: (v) {
                        setState(() => _showHighAirways = v);
                        widget.onHighAirwaysChanged(v);
                      },
                      indent: true,
                    ),
                  ],
                  const _SectionDivider(),

                  // --- ATC BOUNDARY SETTINGS ---
                  const _SectionHeader('ATC BOUNDARY SETTINGS'),
                  _ToggleRow(
                    label: 'ARTCC / FIRs',
                    value: _showArtcc,
                    onChanged: (v) {
                      setState(() => _showArtcc = v);
                      widget.onArtccChanged(v);
                    },
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
}

// --- Private sub-widgets ---

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
