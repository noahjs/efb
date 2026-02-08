import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_client.dart';
import '../../../services/airport_providers.dart';

/// Riverpod provider to fetch nearby airports for a long-press location.
final _nearbyAirportsProvider =
    FutureProvider.family<List<dynamic>, ({double lat, double lng})>(
        (ref, loc) async {
  final client = ref.watch(apiClientProvider);
  return client.getNearbyAirports(
    lat: loc.lat,
    lng: loc.lng,
    radiusNm: 30,
    limit: 5,
  );
});

/// ForeFlight-style bottom sheet shown on map long-press.
/// Displays tapped location, airspace info, and nearby airports.
class MapLongPressSheet extends ConsumerWidget {
  final double lat;
  final double lng;
  final List<Map<String, dynamic>> aeroFeatures;

  const MapLongPressSheet({
    super.key,
    required this.lat,
    required this.lng,
    required this.aeroFeatures,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearbyAsync =
        ref.watch(_nearbyAirportsProvider((lat: lat, lng: lng)));

    final airspaces = aeroFeatures
        .where((f) => f['_layerType'] == 'airspace')
        .toList();
    final artccs =
        aeroFeatures.where((f) => f['_layerType'] == 'artcc').toList();
    final airways =
        aeroFeatures.where((f) => f['_layerType'] == 'airway').toList();

    // Look up airport names for Class D airspaces by identifier
    final airportNames = <String, String>{};
    for (final a in airspaces) {
      final cls = (a['airspace_class'] ?? a['class'] ?? '').toString();
      final ident = (a['identifier'] ?? '').toString();
      if (cls == 'D' && ident.isNotEmpty) {
        final airport = ref.watch(airportDetailProvider(ident)).value;
        if (airport != null) {
          airportNames[ident] = (airport['name'] ?? '').toString();
        }
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
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
                const Expanded(
                  child: Text(
                    'Map Details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 60), // balance the Close button
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),

          // Scrollable content
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                // LOCATION
                _SectionHeader(title: 'LOCATION'),
                const SizedBox(height: 6),
                Text(
                  _formatCoords(lat, lng),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),

                // AIRSPACE (only if features found)
                if (airspaces.isNotEmpty ||
                    artccs.isNotEmpty ||
                    airways.isNotEmpty) ...[
                  _SectionHeader(title: 'AIRSPACE'),
                  const SizedBox(height: 6),
                  ...artccs.map(_buildArtccRow),
                  ...airspaces.map((f) => _buildAirspaceRow(f, airportNames)),
                  ...airways.map(_buildAirwayRow),
                  const SizedBox(height: 16),
                ],

                // NEARBY
                _SectionHeader(title: 'NEARBY'),
                const SizedBox(height: 6),
                nearbyAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, _) => const Text(
                    'Unable to load nearby airports',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  data: (airports) {
                    if (airports.isEmpty) {
                      return const Text(
                        'No airports within 30 NM',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 13),
                      );
                    }
                    return Column(
                      children: airports.map((a) {
                        final apt = a is Map ? a : <String, dynamic>{};
                        return _buildNearbyRow(apt);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAirspaceRow(
      Map<String, dynamic> feature, Map<String, String> airportNames) {
    final name = (feature['name'] ?? feature['designator'] ?? 'Airspace').toString();
    final ident = (feature['identifier'] ?? '').toString();
    final classType = (feature['class'] ?? feature['airspace_class'] ?? '').toString();

    String title;
    // For Class D, use the airport name if available (e.g. "Centennial - Class D")
    final airportName = ident.isNotEmpty ? airportNames[ident] : null;
    if (classType == 'D' && airportName != null && airportName.isNotEmpty) {
      title = '$airportName - Class D';
    } else {
      // Avoid "DENVER CLASS B Class B" — only append if not already in the name
      final alreadyHasClass = classType.isNotEmpty &&
          name.toUpperCase().contains('CLASS ${classType.toUpperCase()}');
      title = classType.isNotEmpty && !alreadyHasClass
          ? '$name Class $classType'
          : name;
    }

    final altRange = _formatAltitudeRange(feature);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.layers, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (altRange.isNotEmpty)
                  Text(
                    altRange,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtccRow(Map<String, dynamic> feature) {
    final name = feature['name'] ?? 'ARTCC';
    final ident = feature['ident'] ?? feature['designator'] ?? '';
    final title =
        ident.toString().isNotEmpty ? '$name ($ident)' : name.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.radar, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAirwayRow(Map<String, dynamic> feature) {
    final designator = feature['designator'] ?? feature['name'] ?? 'Airway';
    final mea = feature['mea'];
    final subtitle = mea != null ? "MEA $mea' MSL" : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.route, size: 16, color: AppColors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  designator.toString(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyRow(Map<dynamic, dynamic> airport) {
    final id = airport['identifier'] ?? airport['icao_identifier'] ?? '';
    final name = airport['name'] ?? '';
    final city = airport['city'] ?? '';
    final state = airport['state'] ?? '';
    final location = [city, state]
        .where((s) => s.toString().isNotEmpty)
        .join(', ');
    final distNm = airport['distance_nm'];
    final bearing = airport['bearing'];

    final distStr = distNm != null
        ? '${(distNm as num).toStringAsFixed(1)} NM'
        : '';
    final bearStr = bearing != null
        ? _bearingToCardinal((bearing as num).toDouble())
        : '';
    final distInfo = [distStr, bearStr]
        .where((s) => s.isNotEmpty)
        .join(' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.flight, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$id: ',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: name.toString(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (location.isNotEmpty || distInfo.isNotEmpty)
                  Text(
                    [location, distInfo]
                        .where((s) => s.isNotEmpty)
                        .join(' — '),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCoords(double lat, double lng) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(2)}\u00b0$latDir / ${lng.abs().toStringAsFixed(2)}\u00b0$lngDir';
  }

  static String _formatAltitudeRange(Map<String, dynamic> feature) {
    final lower = _formatAltitude(
      feature['lower_alt'] ?? feature['lower_val'],
      feature['lower_code'] ?? feature['lower_uom'],
    );
    final upper = _formatAltitude(
      feature['upper_alt'] ?? feature['upper_val'],
      feature['upper_code'] ?? feature['upper_uom'],
    );
    if (lower.isEmpty && upper.isEmpty) return '';
    if (lower.isEmpty) return 'Up to $upper';
    if (upper.isEmpty) return 'From $lower';
    return '$lower – $upper';
  }

  static String _formatAltitude(dynamic alt, dynamic code) {
    if (alt == null) return '';
    final altNum = alt is num ? alt.toInt() : int.tryParse(alt.toString());
    if (altNum == null) return alt.toString();

    final codeStr = (code ?? '').toString().toUpperCase();

    if (altNum == 0 || codeStr == 'SFC') return 'Surface';
    if (altNum >= 18000 && (codeStr == 'FL' || codeStr == 'MSL')) {
      return 'FL${altNum ~/ 100}';
    }
    final formatted = _formatNumber(altNum);
    return '$formatted\' MSL';
  }

  static String _formatNumber(int n) {
    if (n < 1000) return n.toString();
    final str = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  static String _bearingToCardinal(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) % 360 / 45).floor();
    return directions[index];
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
