import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

/// Bottom sheet shown when tapping a PIREP dot on the map.
class PirepBottomSheet extends StatelessWidget {
  final Map<String, dynamic> properties;

  const PirepBottomSheet({super.key, required this.properties});

  @override
  Widget build(BuildContext context) {
    final airepType = (properties['airepType'] ?? 'PIREP').toString();
    final isUrgent = airepType == 'URGENT PIREP';
    final rawOb = (properties['rawOb'] ?? '').toString();
    final aircraft = (properties['aircraft'] ?? '').toString();
    final acType = (properties['acType'] ?? '').toString();
    final fltlvl = properties['fltlvl'];
    final obsTime = (properties['obsTime'] ?? '').toString();

    // Turbulence
    final tbInt = (properties['tbInt1'] ?? '').toString();
    final tbType = (properties['tbType1'] ?? '').toString();
    final tbFreq = (properties['tbFreq1'] ?? '').toString();

    // Icing
    final icgInt = (properties['icgInt1'] ?? '').toString();
    final icgType = (properties['icgType1'] ?? '').toString();

    // Other
    final temp = properties['temp'];
    final clouds = properties['clouds'];

    final severityColor = _severityColor(tbInt, icgInt);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: AppColors.accent, fontSize: 15),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: severityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isUrgent ? 'URGENT PIREP' : 'PIREP',
                        style: TextStyle(
                          color: isUrgent
                              ? AppColors.error
                              : AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 60),
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),

          // Content
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                // Raw observation
                if (rawOb.isNotEmpty) ...[
                  _label('RAW OBSERVATION'),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rawOb,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Details grid
                _label('DETAILS'),
                const SizedBox(height: 6),
                if (obsTime.isNotEmpty)
                  _detailRow('Time', _formatTime(obsTime)),
                if (fltlvl != null)
                  _detailRow('Altitude', _formatAltitude(fltlvl)),
                if (aircraft.isNotEmpty)
                  _detailRow(
                      'Aircraft', acType.isNotEmpty ? '$aircraft ($acType)' : aircraft),

                // Turbulence section
                if (tbInt.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _label('TURBULENCE'),
                  const SizedBox(height: 6),
                  _detailRow('Intensity', tbInt, color: _intensityColor(tbInt)),
                  if (tbType.isNotEmpty) _detailRow('Type', tbType),
                  if (tbFreq.isNotEmpty) _detailRow('Frequency', tbFreq),
                ],

                // Icing section
                if (icgInt.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _label('ICING'),
                  const SizedBox(height: 6),
                  _detailRow('Intensity', icgInt, color: _intensityColor(icgInt)),
                  if (icgType.isNotEmpty) _detailRow('Type', icgType),
                ],

                // Weather
                if (temp != null || (clouds is List && clouds.isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  _label('WEATHER'),
                  const SizedBox(height: 6),
                  if (temp != null) _detailRow('Temperature', '$temp\u00b0C'),
                  if (clouds is List)
                    for (final c in clouds)
                      if (c is Map)
                        _detailRow(
                          'Clouds',
                          _formatCloud(c),
                        ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color ?? AppColors.textPrimary,
                fontSize: 14,
                fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toUtc();
      return '${DateFormat('HH:mm').format(dt)}Z';
    } catch (_) {
      return isoTime;
    }
  }

  String _formatAltitude(dynamic fltlvl) {
    final level = fltlvl is num ? fltlvl.toInt() : int.tryParse(fltlvl.toString());
    if (level == null) return fltlvl.toString();
    if (level >= 180) return 'FL$level';
    return '${level * 100}\' MSL';
  }

  String _formatCloud(Map c) {
    final cover = (c['cover'] ?? '').toString();
    final base = c['base'];
    final top = c['top'];
    final parts = <String>[cover];
    if (base != null && base != 0) parts.add('base $base\'');
    if (top != null && top != 0) parts.add('top $top\'');
    return parts.join(' ');
  }

  Color _severityColor(String tbInt, String icgInt) {
    final primary = tbInt.isNotEmpty ? tbInt : icgInt;
    final upper = primary.toUpperCase();
    if (['SEV', 'SEVERE', 'SEV-EXTM', 'EXTM', 'EXTREME'].contains(upper)) {
      return const Color(0xFFFF5252);
    }
    if (['MOD', 'MODERATE', 'MOD-SEV'].contains(upper)) {
      return const Color(0xFFFFC107);
    }
    if (['LGT', 'LIGHT', 'LGT-MOD'].contains(upper)) {
      return const Color(0xFF29B6F6);
    }
    if (['NEG', 'SMTH', 'SMOOTH', 'NONE', 'TRACE'].contains(upper)) {
      return const Color(0xFF4CAF50);
    }
    return const Color(0xFFB0B4BC);
  }

  Color _intensityColor(String intensity) {
    final upper = intensity.toUpperCase();
    if (['SEV', 'SEVERE', 'SEV-EXTM', 'EXTM', 'EXTREME'].contains(upper)) {
      return const Color(0xFFFF5252);
    }
    if (['MOD', 'MODERATE', 'MOD-SEV'].contains(upper)) {
      return const Color(0xFFFFC107);
    }
    if (['LGT', 'LIGHT', 'LGT-MOD'].contains(upper)) {
      return const Color(0xFF29B6F6);
    }
    return const Color(0xFF4CAF50);
  }
}
