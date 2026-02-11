import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/airport_providers.dart';
import 'sheet_actions.dart' as actions;

class WxStationBottomSheet extends ConsumerWidget {
  final String stationId;
  final Map<dynamic, dynamic>? metarData;

  const WxStationBottomSheet({
    super.key,
    required this.stationId,
    this.metarData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.15,
      maxChildSize: 0.7,
      snap: true,
      snapSizes: const [0.15, 0.45, 0.7],
      builder: (context, scrollController) {
        return Container(
          color: AppColors.surface,
          child: _WxStationSheetContent(
            stationId: stationId,
            metarData: metarData,
            scrollController: scrollController,
          ),
        );
      },
    );
  }
}

class _WxStationSheetContent extends ConsumerWidget {
  final String stationId;
  final Map<dynamic, dynamic>? metarData;
  final ScrollController scrollController;

  const _WxStationSheetContent({
    required this.stationId,
    this.metarData,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationAsync = ref.watch(wxStationDetailProvider(stationId));

    return stationAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => _buildWithMetarOnly(context, ref),
      data: (station) {
        if (station == null || station['error'] != null) {
          return _buildWithMetarOnly(context, ref);
        }
        return _buildContent(context, ref, station);
      },
    );
  }

  Widget _buildWithMetarOnly(BuildContext context, WidgetRef ref) {
    // Even if the station DB lookup fails, we still have METAR data
    return _buildContent(context, ref, null);
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? station) {
    final name = station?['name'] as String? ?? '';
    final lat = station?['latitude'] as num? ?? metarData?['lat'] as num?;
    final lng = station?['longitude'] as num? ?? metarData?['lon'] as num?;
    final elevation = station?['elevation'] as num?;
    final state = station?['state'] as String? ?? '';

    final coordStr = _formatCoordinates(lat?.toDouble(), lng?.toDouble());
    final fltCat = metarData?['fltCat'] as String? ?? '';
    final rawOb = metarData?['rawOb'] as String? ?? '';
    final temp = metarData?['temp'] as num?;
    final dewp = metarData?['dewp'] as num?;
    final wdir = metarData?['wdir'] as num?;
    final wspd = metarData?['wspd'] as num?;
    final wgst = metarData?['wgst'] as num?;
    final visib = metarData?['visib'];
    final altim = metarData?['altim'] as num?;

    final headerTitle = name.isNotEmpty ? '$stationId — $name' : stationId;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        // Header bar
        Container(
          color: AppColors.toolbarBackground,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Close',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text(
                  headerTitle,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Flight category badge
              if (fltCat.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _fltCatColor(fltCat),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    fltCat,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                const SizedBox(width: 56),
            ],
          ),
        ),

        // Action buttons row
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _ActionButton(
                label: 'Direct To',
                onTap: () => actions.directTo(context, ref, stationId),
              ),
              _ActionButton(
                label: 'Add to Route',
                onTap: () => actions.addToRoute(context, ref, stationId),
              ),
            ],
          ),
        ),

        // METAR section
        if (rawOb.isNotEmpty) ...[
          _SectionHeader(title: 'METAR'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              rawOb,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const Divider(height: 0.5, color: AppColors.divider),
          if (temp != null)
            _InfoRow(
              label: 'Temperature',
              value: '${temp.toInt()}\u00B0C'
                  '${dewp != null ? ' / ${dewp.toInt()}\u00B0C' : ''}',
            ),
          if (temp != null)
            const Divider(height: 0.5, color: AppColors.divider),
          if (wdir != null || wspd != null)
            _InfoRow(
              label: 'Wind',
              value: _formatWind(wdir, wspd, wgst),
            ),
          if (wdir != null || wspd != null)
            const Divider(height: 0.5, color: AppColors.divider),
          if (visib != null)
            _InfoRow(label: 'Visibility', value: '${visib} SM'),
          if (visib != null)
            const Divider(height: 0.5, color: AppColors.divider),
          if (altim != null)
            _InfoRow(
                label: 'Altimeter',
                value: '${altim.toStringAsFixed(2)} inHg'),
        ],

        // Station Information section
        _SectionHeader(title: 'STATION INFORMATION'),
        if (name.isNotEmpty) ...[
          _InfoRow(label: 'Name', value: name),
          const Divider(height: 0.5, color: AppColors.divider),
        ],
        if (elevation != null) ...[
          _InfoRow(
            label: 'Elevation',
            value: '${elevation.toInt()} ft',
            valueColor: AppColors.accent,
          ),
          const Divider(height: 0.5, color: AppColors.divider),
        ],
        if (state.isNotEmpty) ...[
          _InfoRow(label: 'State', value: state),
          const Divider(height: 0.5, color: AppColors.divider),
        ],
        _InfoRow(
          label: 'Coordinates',
          value: coordStr,
          valueColor: AppColors.accent,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  String _formatCoordinates(double? lat, double? lng) {
    if (lat == null || lng == null) return '---';
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    final latStr = lat.abs().toStringAsFixed(2);
    final lngStr = lng.abs().toStringAsFixed(2);
    return '$latStr\u00B0$latDir/$lngStr\u00B0$lngDir';
  }

  String _formatWind(num? wdir, num? wspd, num? wgst) {
    if (wspd == null) return '---';
    final dir = wdir != null ? '${wdir.toInt().toString().padLeft(3, '0')}\u00B0' : 'VRB';
    final gust = wgst != null && wgst > 0 ? 'G${wgst.toInt()}' : '';
    return '$dir at ${wspd.toInt()}${gust} kt';
  }

  Color _fltCatColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'VFR':
        return const Color(0xFF4CAF50);
      case 'MVFR':
        return const Color(0xFF2196F3);
      case 'IFR':
        return const Color(0xFFFF5252);
      case 'LIFR':
        return const Color(0xFFE040FB);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceLight,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                color: valueColor ?? AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
