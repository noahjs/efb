import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_client.dart';
import 'pirep_map.dart';
import 'pirep_symbols.dart';

/// Provider for PIREP data.
final _pirepDataProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getPireps(bbox: '20,-130,55,-60', age: 2);
});

class PirepViewer extends ConsumerWidget {
  const PirepViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_pirepDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PIREPs'),
        backgroundColor: AppColors.toolbarBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_pirepDataProvider),
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
              const Text('Unable to load PIREPs',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(_pirepDataProvider),
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
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline,
                      size: 48, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text('No recent PIREPs',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      )),
                ],
              ),
            );
          }

          return _PirepMapBody(geojson: data);
        },
      ),
    );
  }
}

class _PirepMapBody extends StatefulWidget {
  final Map<String, dynamic> geojson;

  const _PirepMapBody({required this.geojson});

  @override
  State<_PirepMapBody> createState() => _PirepMapBodyState();
}

class _PirepMapBodyState extends State<_PirepMapBody> {
  Map<String, dynamic>? _selectedPirep;

  void _onFeatureTapped(Map<String, dynamic> props) {
    setState(() {
      _selectedPirep = props.isEmpty ? null : props;
    });
  }

  @override
  Widget build(BuildContext context) {
    final featureCount =
        (widget.geojson['features'] as List<dynamic>?)?.length ?? 0;

    return Stack(
      children: [
        // Platform map
        PirepMap(
          geojson: widget.geojson,
          onFeatureTapped: _onFeatureTapped,
        ),

        // Report count badge
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
              '$featureCount reports',
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
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _legendSymbol(PirepShape.circle, const Color(0xFF4CAF50),
                    true, 'Smooth/NEG'),
                const SizedBox(height: 4),
                _legendSymbol(PirepShape.triangle, const Color(0xFF29B6F6),
                    false, 'Turb Light'),
                const SizedBox(height: 4),
                _legendSymbol(PirepShape.triangle, const Color(0xFFFFC107),
                    true, 'Turb Mod'),
                const SizedBox(height: 4),
                _legendSymbol(PirepShape.triangle, const Color(0xFFFF5252),
                    true, 'Turb Sev'),
                const SizedBox(height: 6),
                _legendSymbol(PirepShape.diamond, const Color(0xFF29B6F6),
                    false, 'Ice Light'),
                const SizedBox(height: 4),
                _legendSymbol(PirepShape.diamond, const Color(0xFFFFC107),
                    true, 'Ice Mod'),
                const SizedBox(height: 4),
                _legendSymbol(PirepShape.diamond, const Color(0xFFFF5252),
                    true, 'Ice Sev'),
              ],
            ),
          ),
        ),

        // Selected PIREP detail card
        if (_selectedPirep != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _PirepDetailCard(
              properties: _selectedPirep!,
              onClose: () => setState(() => _selectedPirep = null),
            ),
          ),
      ],
    );
  }

  Widget _legendSymbol(
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

class _PirepDetailCard extends StatelessWidget {
  final Map<String, dynamic> properties;
  final VoidCallback onClose;

  const _PirepDetailCard({
    required this.properties,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final icaoId = properties['icaoId'] as String? ?? '';
    final rawOb = properties['rawOb'] as String? ?? '';
    final airepType = properties['airepType'] as String? ?? 'PIREP';
    final acType = properties['acType'] as String? ?? '';
    final fltlvl = properties['fltlvl'];
    final obsTime = properties['obsTime'] as String? ?? '';
    final isUrgent = airepType == 'URGENT PIREP';

    // Turbulence
    final tbInt = properties['tbInt1'] as String? ?? '';
    final tbType = properties['tbType1'] as String? ?? '';
    final tbFreq = properties['tbFreq1'] as String? ?? '';

    // Icing
    final icgInt = properties['icgInt1'] as String? ?? '';
    final icgType = properties['icgType1'] as String? ?? '';

    // Weather
    final temp = properties['temp'];
    final wdir = properties['wdir'];
    final wspd = properties['wspd'];

    // Clouds
    final clouds = properties['clouds'];

    // Format flight level
    final flStr = fltlvl != null ? 'FL${fltlvl.toString().padLeft(3, '0')}' : '';

    // Build turbulence string
    final tbParts = <String>[
      if (tbInt.isNotEmpty) tbInt,
      if (tbType.isNotEmpty) tbType,
      if (tbFreq.isNotEmpty) tbFreq,
    ];
    final tbStr = tbParts.join(' ');

    // Build icing string
    final icgParts = <String>[
      if (icgInt.isNotEmpty) icgInt,
      if (icgType.isNotEmpty) icgType,
    ];
    final icgStr = icgParts.join(' ');

    // Build wind string
    final windStr =
        (wdir != null && wspd != null) ? '$wdir°/${wspd}kt' : '';

    // Build cloud string
    final cloudStr = _formatClouds(clouds);

    return Container(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: type badge, station, time, close
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isUrgent ? AppColors.error : AppColors.primary)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isUrgent ? 'UUA' : 'UA',
                      style: TextStyle(
                        color:
                            isUrgent ? AppColors.error : AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    icaoId,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (obsTime.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(obsTime),
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
              // Info badges row (wrapping)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (flStr.isNotEmpty) _infoBadge(Icons.height, flStr),
                  if (acType.isNotEmpty && acType != 'UNKN')
                    _infoBadge(Icons.airplanemode_active, acType),
                  if (tbStr.isNotEmpty)
                    _coloredBadge('TB', tbStr, _turbulenceColor(tbInt)),
                  if (icgStr.isNotEmpty)
                    _coloredBadge('ICE', icgStr, AppColors.info),
                  if (temp != null)
                    _infoBadge(Icons.thermostat, '$temp°C'),
                  if (windStr.isNotEmpty)
                    _infoBadge(Icons.air, windStr),
                  if (cloudStr.isNotEmpty)
                    _infoBadge(Icons.cloud, cloudStr),
                ],
              ),
              if (rawOb.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    rawOb,
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
        color: color.withValues(alpha: 0.15),
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

  Color _turbulenceColor(String intensity) {
    switch (intensity.toUpperCase()) {
      case 'NEG':
      case 'SMTH':
      case 'SMOOTH':
        return const Color(0xFF4CAF50);
      case 'LGT':
      case 'LIGHT':
      case 'LGT-MOD':
        return const Color(0xFF29B6F6);
      case 'MOD':
      case 'MODERATE':
      case 'MOD-SEV':
        return const Color(0xFFFFC107);
      case 'SEV':
      case 'SEVERE':
      case 'SEV-EXTM':
      case 'EXTM':
      case 'EXTREME':
        return const Color(0xFFFF5252);
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatClouds(dynamic clouds) {
    if (clouds == null) return '';
    if (clouds is! List || clouds.isEmpty) return '';
    return clouds.map((c) {
      if (c is Map) {
        final cover = c['cover'] as String? ?? '';
        final base = c['base'];
        if (base != null) return '$cover ${base}ft';
        return cover;
      }
      return c.toString();
    }).join(', ');
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour${min}Z';
    } catch (_) {
      return isoTime;
    }
  }
}
