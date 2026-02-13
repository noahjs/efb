import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/solar.dart';
import '../../../services/api_client.dart';
import '../../../services/airport_providers.dart';
import 'sheet_actions.dart' as actions;

class AirportBottomSheet extends ConsumerWidget {
  final String airportId;

  const AirportBottomSheet({super.key, required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.15,
      maxChildSize: 0.45,
      snap: true,
      snapSizes: const [0.15, 0.45],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
          ),
          child: _AirportSheetContent(
            airportId: airportId,
            scrollController: scrollController,
          ),
        );
      },
    );
  }
}

class _AirportSheetContent extends ConsumerWidget {
  final String airportId;
  final ScrollController scrollController;

  const _AirportSheetContent({
    required this.airportId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airportAsync = ref.watch(airportDetailProvider(airportId));

    return airportAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Unable to load $airportId',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (airport) {
        if (airport == null) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                '$airportId not found',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        final name = airport['name'] ?? '';
        final city = airport['city'] ?? '';
        final state = airport['state'] ?? '';
        final elevation = airport['elevation'];
        final lat = airport['latitude'] as num?;
        final lng = airport['longitude'] as num?;
        final location =
            [city, state].where((s) => s.isNotEmpty).join(', ');
        final elevationStr = elevation != null
            ? "${NumberFormat('#,##0').format((elevation as num).round())}'"
            : '---';

        // Sunrise / sunset
        String sunriseStr = '---';
        String sunsetStr = '---';
        if (lat != null && lng != null) {
          final now = DateTime.now();
          final solar = SolarTimes.forDate(
            date: now,
            latitude: lat.toDouble(),
            longitude: lng.toDouble(),
          );
          if (solar != null) {
            final timeFmt = DateFormat('h:mm a');
            sunriseStr = timeFmt.format(solar.sunrise.toLocal());
            sunsetStr = timeFmt.format(solar.sunset.toLocal());
          }
        }

        return ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            // Header bar
            Container(
              color: AppColors.toolbarBackground,
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Close',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          airportId,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _StarIcon(
                    airportId: airportId,
                    faaIdentifier:
                        airport['identifier'] ?? airportId,
                  ),
                  const SizedBox(width: 8),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  _ActionButton(
                    label: 'Direct To',
                    onTap: () => actions.directTo(
                        context, ref, airportId),
                  ),
                  _ActionButton(
                    label: 'Add to Route',
                    onTap: () => actions.addToRoute(
                        context, ref, airportId),
                  ),
                  _ActionButton(
                    label: 'Hold...',
                    onTap: () =>
                        actions.showComingSoon(context, 'Hold patterns'),
                  ),
                  _ActionButton(
                    label: 'Fullscreen',
                    onTap: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push('/airports/$airportId');
                    },
                  ),
                ],
              ),
            ),

            // Airport info section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Airport diagram thumbnail
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: const Icon(Icons.map_outlined,
                        color: AppColors.textMuted, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (location.isNotEmpty)
                          Text(
                            location,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        Text(
                          'Elevation: $elevationStr',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.wb_sunny_outlined,
                                size: 14, color: AppColors.starred),
                            const SizedBox(width: 4),
                            Text(
                              sunriseStr,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.nightlight_outlined,
                                size: 14, color: AppColors.info),
                            const SizedBox(width: 4),
                            Text(
                              sunsetStr,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // METAR summary
            _MetarSummary(airportId: airportId),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

/// Compact METAR summary shown in the bottom sheet
class _MetarSummary extends ConsumerWidget {
  final String airportId;
  const _MetarSummary({required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metarAsync = ref.watch(metarProvider(airportId));

    return metarAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (envelope) {
        if (envelope == null) return const SizedBox.shrink();

        final metar = envelope['metar'] as Map<String, dynamic>?;
        if (metar == null) return const SizedBox.shrink();

        final rawOb = metar['rawOb'] as String? ?? '';
        final fltCat = metar['fltCat'] as String? ?? '';
        final catColor = _flightCategoryColor(fltCat);
        final isNearby = envelope['isNearby'] as bool? ?? false;
        final station = envelope['station'] as String? ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flight category + station info
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: catColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        fltCat,
                        style: TextStyle(
                          color: catColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (isNearby) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(from $station)',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const Text(
                        'METAR',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Raw METAR text
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      rawOb,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: catColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static Color _flightCategoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'VFR':
        return AppColors.vfr;
      case 'MVFR':
        return AppColors.mvfr;
      case 'IFR':
        return AppColors.ifr;
      case 'LIFR':
        return AppColors.lifr;
      default:
        return AppColors.textMuted;
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

class _StarIcon extends ConsumerWidget {
  final String airportId;
  final String faaIdentifier;

  const _StarIcon({required this.airportId, required this.faaIdentifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starredIdsAsync = ref.watch(starredAirportIdsProvider);
    final starredIds =
        starredIdsAsync.whenOrNull(data: (ids) => ids) ?? <String>{};
    final isStarred = starredIds.contains(faaIdentifier);

    return GestureDetector(
      onTap: () async {
        final client = ref.read(apiClientProvider);
        try {
          if (isStarred) {
            await client.unstarAirport(faaIdentifier);
          } else {
            await client.starAirport(airportId);
          }
          ref.invalidate(starredAirportsProvider);
        } catch (_) {
          // ignore
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          isStarred ? Icons.star : Icons.star_border,
          color: isStarred ? AppColors.starred : AppColors.textMuted,
          size: 24,
        ),
      ),
    );
  }
}
