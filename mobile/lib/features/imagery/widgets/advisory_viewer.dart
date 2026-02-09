import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../imagery_providers.dart';
import 'advisory_map.dart';

class AdvisoryViewer extends ConsumerWidget {
  final String advisoryType;
  final String name;

  const AdvisoryViewer({
    super.key,
    required this.advisoryType,
    required this.name,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(advisoriesProvider(advisoryType));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(name),
        backgroundColor: AppColors.toolbarBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(advisoriesProvider(advisoryType)),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Unable to load advisories',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(advisoriesProvider(advisoryType)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Text('No data available',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          final features = (data['features'] as List<dynamic>?) ?? [];

          if (features.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 48, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text(
                    'No active $name',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return _AdvisoryMapBody(
            geojson: data,
            advisoryType: advisoryType,
          );
        },
      ),
    );
  }
}

class _AdvisoryMapBody extends StatefulWidget {
  final Map<String, dynamic> geojson;
  final String advisoryType;

  const _AdvisoryMapBody({
    required this.geojson,
    required this.advisoryType,
  });

  @override
  State<_AdvisoryMapBody> createState() => _AdvisoryMapBodyState();
}

class _AdvisoryMapBodyState extends State<_AdvisoryMapBody> {
  List<Map<String, dynamic>> _selectedAdvisories = [];

  void _onFeaturesTapped(List<Map<String, dynamic>> propsList) {
    setState(() {
      _selectedAdvisories = propsList;
    });
  }

  /// Build a dynamic legend from the hazards present in the data.
  List<_LegendEntry> _buildLegend() {
    final features = (widget.geojson['features'] as List<dynamic>?) ?? [];
    final seen = <String>{};
    final entries = <_LegendEntry>[];

    for (final f in features) {
      final props = (f as Map<String, dynamic>)['properties'] as Map? ?? {};
      final hazard = (props['hazard'] as String? ?? '').toUpperCase();
      if (hazard.isEmpty || seen.contains(hazard)) continue;
      seen.add(hazard);
      entries.add(_LegendEntry(
        hazard: hazard,
        label: _hazardLabel(hazard),
        color: _colorFromHex(_hazardColorHex(hazard)),
      ));
    }

    return entries;
  }

  String _hazardLabel(String hazard) {
    switch (hazard) {
      case 'IFR':
        return 'IFR';
      case 'MTN_OBSC':
      case 'MT_OBSC':
        return 'Mtn Obscn';
      case 'TURB':
        return 'Turbulence';
      case 'TURB-HI':
        return 'Turb (High)';
      case 'TURB-LO':
        return 'Turb (Low)';
      case 'ICE':
        return 'Icing';
      case 'FZLVL':
      case 'M_FZLVL':
        return 'Frzg Level';
      case 'LLWS':
        return 'LLWS';
      case 'SFC_WND':
        return 'Sfc Wind';
      case 'CONV':
        return 'Convective';
      default:
        return hazard;
    }
  }

  Color _colorFromHex(String hex) {
    final hexStr = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hexStr', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final featureCount =
        (widget.geojson['features'] as List<dynamic>?)?.length ?? 0;
    final legend = _buildLegend();

    return Stack(
      children: [
        AdvisoryMap(
          geojson: widget.geojson,
          onFeaturesTapped: _onFeaturesTapped,
        ),

        // Feature count badge
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$featureCount advisories',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),

        // Dynamic legend
        if (legend.isNotEmpty)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < legend.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    _legendItem(legend[i]),
                  ],
                ],
              ),
            ),
          ),

        // Selected advisory detail panel
        if (_selectedAdvisories.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _AdvisoryDetailPanel(
              advisories: _selectedAdvisories,
              advisoryType: widget.advisoryType,
              onClose: () => setState(() => _selectedAdvisories = []),
            ),
          ),
      ],
    );
  }

  Widget _legendItem(_LegendEntry entry) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: entry.color.withValues(alpha: 0.3),
            border: Border.all(color: entry.color, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          entry.label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _LegendEntry {
  final String hazard;
  final String label;
  final Color color;

  const _LegendEntry({
    required this.hazard,
    required this.label,
    required this.color,
  });
}

String _hazardColorHex(String hazard) {
  switch (hazard.toUpperCase()) {
    case 'IFR':
      return '#1E90FF';
    case 'MTN_OBSC':
    case 'MT_OBSC':
      return '#8D6E63';
    case 'TURB':
    case 'TURB-HI':
    case 'TURB-LO':
      return '#FFC107';
    case 'ICE':
    case 'FZLVL':
    case 'M_FZLVL':
      return '#00BCD4';
    case 'LLWS':
    case 'CONV':
      return '#FF5252';
    case 'SFC_WND':
      return '#FF9800';
    default:
      return '#B0B4BC';
  }
}

class _AdvisoryDetailPanel extends StatelessWidget {
  final List<Map<String, dynamic>> advisories;
  final String advisoryType;
  final VoidCallback onClose;

  const _AdvisoryDetailPanel({
    required this.advisories,
    required this.advisoryType,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with count and close button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Text(
                    '${advisories.length} advisor${advisories.length == 1 ? 'y' : 'ies'} at this location',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: AppColors.textMuted),
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Advisory list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: advisories.length,
                separatorBuilder: (_, _) => const Divider(
                  color: AppColors.surfaceLight,
                  height: 16,
                ),
                itemBuilder: (_, index) => _AdvisoryDetailItem(
                  properties: advisories[index],
                  advisoryType: advisoryType,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvisoryDetailItem extends StatelessWidget {
  final Map<String, dynamic> properties;
  final String advisoryType;

  const _AdvisoryDetailItem({
    required this.properties,
    required this.advisoryType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const SizedBox(height: 6),
        _buildInfoRow(),
        _buildRawText(),
      ],
    );
  }

  Widget _buildHeader() {
    final hazard = _str(properties['hazard']).toUpperCase();
    final color = _colorFromHex(_hazardColorHex(hazard));

    String title;
    String subtitle;

    if (advisoryType == 'gairmets') {
      title = hazard;
      subtitle = _str(properties['product']);
    } else if (advisoryType == 'sigmets') {
      final sigType = _str(properties['airSigmetType']);
      title = '${sigType.isNotEmpty ? sigType : 'SIGMET'} - $hazard';
      subtitle = _str(properties['seriesId']);
    } else {
      final cwsu = _str(properties['cwsu']);
      title = 'CWA${hazard.isNotEmpty ? ' - $hazard' : ''}';
      subtitle = cwsu;
    }

    // Valid time
    String validStr = '';
    if (advisoryType == 'gairmets') {
      final vt = _str(properties['validTime']);
      if (vt.isNotEmpty) validStr = _formatTime(vt);
    } else {
      final from = _str(properties['validTimeFrom']);
      final to = _str(properties['validTimeTo']);
      if (from.isNotEmpty) {
        validStr = '${_formatTime(from)} - ${_formatTime(to)}';
      }
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const Spacer(),
        if (validStr.isNotEmpty)
          Flexible(
            child: Text(
              validStr,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow() {
    final badges = <Widget>[];

    // Altitude range
    if (advisoryType == 'gairmets') {
      final base = properties['base'];
      final top = properties['top'];
      if (base != null || top != null) {
        badges.add(_infoBadge(
          Icons.height,
          _formatAltitudeRange(base, top),
        ));
      }
    } else {
      final altLow = properties['altitudeLow1'] ?? properties['altitudeLow2'] ??
          properties['base'];
      final altHigh = properties['altitudeHi1'] ?? properties['altitudeHi2'] ??
          properties['top'];
      if (altLow != null || altHigh != null) {
        badges.add(_infoBadge(
          Icons.height,
          _formatAltitudeRange(altLow, altHigh),
        ));
      }
    }

    // Forecast hour (G-AIRMETs)
    final forecast = properties['forecast'];
    if (forecast != null) {
      badges.add(_infoBadge(Icons.schedule, '+${_numToInt(forecast)}HR'));
    }

    // Due-to text (G-AIRMETs)
    final dueTo = _str(properties['dueTo']);
    if (dueTo.isNotEmpty) {
      badges.add(_infoBadge(Icons.info_outline, dueTo));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: badges,
    );
  }

  Widget _buildRawText() {
    String rawText = '';
    if (advisoryType == 'sigmets') {
      rawText = _str(properties['rawAirSigmet']);
    } else if (advisoryType == 'cwas') {
      rawText = _str(properties['cwaText']);
    }

    if (rawText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          rawText.trim(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.4,
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

  String _formatAltitudeRange(dynamic low, dynamic high) {
    final lowFt = low != null ? _formatAlt(low) : 'SFC';
    final highFt = high != null ? _formatAlt(high) : '';
    if (highFt.isEmpty) return lowFt;
    return '$lowFt - $highFt';
  }

  String _formatAlt(dynamic alt) {
    if (alt == null) return '';
    final feet = _numToInt(alt);
    if (feet == null) return alt.toString();
    if (feet >= 18000) return 'FL${feet ~/ 100}';
    return '${feet}ft';
  }

  String _str(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  int? _numToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    return null;
  }

  String _formatTime(String isoTime) {
    if (isoTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTime);
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day/${_monthAbbr(dt.month)} $hour${min}Z';
    } catch (_) {
      return isoTime;
    }
  }

  String _monthAbbr(int month) {
    const abbrs = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return abbrs[month - 1];
  }

  Color _colorFromHex(String hex) {
    final hexStr = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hexStr', radix: 16));
  }
}
