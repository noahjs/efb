import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';
import '../../../imagery/widgets/pirep_symbols.dart';
import 'briefing_pirep_map.dart';

class PirepDetail extends StatefulWidget {
  final String title;
  final List<BriefingPirep> pireps;
  final List<BriefingWaypoint> waypoints;

  const PirepDetail({
    super.key,
    required this.title,
    required this.pireps,
    required this.waypoints,
  });

  @override
  State<PirepDetail> createState() => _PirepDetailState();
}

class _PirepDetailState extends State<PirepDetail> {
  BriefingPirep? _selectedPirep;

  @override
  Widget build(BuildContext context) {
    if (widget.pireps.isEmpty) {
      return Center(
        child: Text('No ${widget.title}',
            style: const TextStyle(color: AppColors.textMuted)),
      );
    }

    return Stack(
      children: [
        // Map fills the whole area
        BriefingPirepMap(
          pireps: widget.pireps,
          waypoints: widget.waypoints,
          onPirepTapped: (pirep) => setState(() => _selectedPirep = pirep),
          onEmptyTapped: () => setState(() => _selectedPirep = null),
        ),

        // Report count badge
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(230),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${widget.pireps.length} ${widget.title}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),

        // Legend
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(230),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _legendItem(PirepShape.circle, const Color(0xFF4CAF50),
                    true, 'Smooth/NEG'),
                const SizedBox(height: 4),
                _legendItem(PirepShape.triangle, const Color(0xFF29B6F6),
                    false, 'Turb Lgt'),
                const SizedBox(height: 4),
                _legendItem(PirepShape.triangle, const Color(0xFFFFC107),
                    true, 'Turb Mod'),
                const SizedBox(height: 4),
                _legendItem(PirepShape.triangle, const Color(0xFFFF5252),
                    true, 'Turb Sev'),
                const SizedBox(height: 6),
                _legendItem(PirepShape.diamond, const Color(0xFF29B6F6),
                    false, 'Ice Lgt'),
                const SizedBox(height: 4),
                _legendItem(PirepShape.diamond, const Color(0xFFFFC107),
                    true, 'Ice Mod'),
                const SizedBox(height: 4),
                _legendItem(PirepShape.diamond, const Color(0xFFFF5252),
                    true, 'Ice Sev'),
              ],
            ),
          ),
        ),

        // Detail card for selected PIREP
        if (_selectedPirep != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _PirepDetailCard(
              pirep: _selectedPirep!,
              onClose: () => setState(() => _selectedPirep = null),
            ),
          ),
      ],
    );
  }

  Widget _legendItem(
      PirepShape shape, Color color, bool filled, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(14, 14),
          painter: PirepSymbolPainter(
              shape: shape, color: color, filled: filled),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detail card shown when a PIREP is tapped
// ---------------------------------------------------------------------------

class _PirepDetailCard extends StatelessWidget {
  final BriefingPirep pirep;
  final VoidCallback onClose;

  const _PirepDetailCard({required this.pirep, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isUrgent = pirep.urgency == 'UUA';
    final tbSev = extractSeverity(pirep.turbulence);
    final iceSev = extractSeverity(pirep.icing);
    final flStr = pirep.altitude != null
        ? 'FL${pirep.altitude!.padLeft(3, '0')}'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: type badge, station, time, close
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          (isUrgent ? AppColors.error : AppColors.primary)
                              .withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pirep.urgency,
                      style: TextStyle(
                        color: isUrgent
                            ? AppColors.error
                            : AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (pirep.location != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      pirep.location!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (pirep.time != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(pirep.time!),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(Icons.close,
                        size: 20, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Info badges
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (flStr != null) _infoBadge(Icons.height, flStr),
                  if (pirep.aircraftType != null &&
                      pirep.aircraftType!.isNotEmpty &&
                      pirep.aircraftType != 'UNKN')
                    _infoBadge(
                        Icons.airplanemode_active, pirep.aircraftType!),
                  if (pirep.turbulence != null)
                    _coloredBadge('TB', pirep.turbulence!,
                        _severityColor(tbSev)),
                  if (pirep.icing != null)
                    _coloredBadge(
                        'ICE', pirep.icing!, _severityColor(iceSev)),
                ],
              ),
              // Raw observation
              if (pirep.raw.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pirep.raw,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coloredBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(38),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _severityColor(Severity sev) {
    switch (sev) {
      case Severity.none:
        return const Color(0xFF4CAF50);
      case Severity.light:
        return const Color(0xFF29B6F6);
      case Severity.moderate:
        return const Color(0xFFFFC107);
      case Severity.severe:
        return const Color(0xFFFF5252);
    }
  }

  String _formatTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr);
      return '${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}Z';
    } catch (_) {
      return timeStr;
    }
  }
}
