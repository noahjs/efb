import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/solar.dart';
import '../../../services/api_client.dart';
import '../../../services/airport_providers.dart';
import '../../../services/atis_audio_provider.dart';
import '../widgets/airport_info_tab.dart';
import '../widgets/airport_weather_tab.dart';
import '../widgets/airport_runway_tab.dart';
import '../widgets/airport_procedure_tab.dart';
import '../widgets/airport_notam_tab.dart';
import '../../../services/procedure_providers.dart';
import 'package:go_router/go_router.dart';
import 'airport_3d_view_screen.dart';
import 'procedure_pdf_screen.dart';

class AirportDetailScreen extends ConsumerWidget {
  final String airportId;

  const AirportDetailScreen({super.key, required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airportAsync = ref.watch(airportDetailProvider(airportId));

    // Eagerly prefetch weather & NOTAMs so data is cached before user
    // navigates to plates or other tabs.
    ref.watch(notamsProvider(airportId));
    ref.watch(metarProvider(airportId));
    ref.watch(tafProvider(airportId));

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(airportId),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            _StarButton(airportId: airportId),
          ],
        ),
        body: Column(
          children: [
            // Airport header
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(16),
              child: airportAsync.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => SizedBox(
                  height: 80,
                  child: Center(
                    child: Text(
                      'Unable to load airport data',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                data: (airport) => _AirportHeader(
                  airportId: airportId,
                  airport: airport,
                ),
              ),
            ),

            // ATIS audio bar (persists across tabs)
            airportAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (airport) {
                final hasLiveatc = airport?['has_liveatc'] == true;
                if (!hasLiveatc) return const SizedBox.shrink();
                return _AtisAudioBar(airportId: airportId);
              },
            ),

            // Tab bar
            Container(
              color: AppColors.surface,
              child: const TabBar(
                tabs: [
                  Tab(text: 'Info'),
                  Tab(text: 'Weather'),
                  Tab(text: 'Runway'),
                  Tab(text: 'Procedure'),
                  Tab(text: 'NOTAM'),
                ],
                isScrollable: false,
                labelStyle:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: TextStyle(fontSize: 13),
                indicatorSize: TabBarIndicatorSize.tab,
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  AirportInfoTab(airportId: airportId),
                  AirportWeatherTab(airportId: airportId),
                  AirportRunwayTab(airportId: airportId),
                  AirportProcedureTab(airportId: airportId),
                  AirportNotamTab(airportId: airportId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AirportHeader extends ConsumerWidget {
  final String airportId;
  final Map<String, dynamic>? airport;

  const _AirportHeader({required this.airportId, required this.airport});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = airport?['name'] ?? airportId;
    final city = airport?['city'] ?? '';
    final state = airport?['state'] ?? '';
    final elevation = airport?['elevation'];
    final lat = airport?['latitude'] as double?;
    final lng = airport?['longitude'] as double?;

    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    final elevationStr = elevation != null
        ? '${NumberFormat('#,##0').format((elevation as num).round())}\''
        : '---';

    // Compute sunrise/sunset from lat/lng
    String sunriseStr = '---';
    String sunsetStr = '---';
    if (lat != null && lng != null) {
      final now = DateTime.now();
      final solar = SolarTimes.forDate(
        date: now,
        latitude: lat,
        longitude: lng,
      );
      if (solar != null) {
        final localSunrise = solar.sunrise.toLocal();
        final localSunset = solar.sunset.toLocal();
        final timeFmt = DateFormat('h:mm a');
        sunriseStr = timeFmt.format(localSunrise);
        sunsetStr = timeFmt.format(localSunset);
      }
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Airport diagram thumbnail
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: const Icon(Icons.map_outlined,
                  color: AppColors.textMuted, size: 28),
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
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (location.isNotEmpty) location,
                      'Elevation: $elevationStr',
                    ].join('\n'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.wb_sunny_outlined,
                          size: 14, color: Colors.amber.shade300),
                      const SizedBox(width: 4),
                      Text(
                        sunriseStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.nightlight_outlined,
                          size: 14, color: Colors.blue.shade300),
                      const SizedBox(width: 4),
                      Text(
                        sunsetStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Quick action buttons
        Row(
          children: [
            _QuickAction(
              label: '3D View',
              onTap: () {
                if (airport != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Airport3dViewScreen(airport: airport!),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            _QuickAction(
              label: 'Taxiways',
              onTap: () {
                final grouped = ref.read(airportProceduresProvider(airportId)).whenOrNull(data: (d) => d);
                final apd = grouped?['APD'];
                if (apd != null && apd.isNotEmpty) {
                  final diagram = apd.first;
                  final client = ref.read(apiClientProvider);
                  final pdfUrl = client.getProcedurePdfUrl(airportId, diagram.id);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProcedurePdfScreen(
                        title: diagram.chartName,
                        pdfUrl: pdfUrl,
                        airportId: airportId,
                        chartCode: 'APD',
                        procedureId: diagram.id,
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            _QuickAction(
              label: 'Approaches',
              onTap: () {
                context.push('/airports/$airportId/approaches');
              },
            ),
            const SizedBox(width: 8),
            _QuickAction(label: 'FBOs', onTap: () => context.push('/airports/$airportId/fbos')),
          ],
        ),
      ],
    );
  }
}

class _StarButton extends ConsumerWidget {
  final String airportId;

  const _StarButton({required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final starredIdsAsync = ref.watch(starredAirportIdsProvider);
    final starredIds =
        starredIdsAsync.whenOrNull(data: (ids) => ids) ?? <String>{};

    // Check both FAA and ICAO forms
    final airportAsync = ref.watch(airportDetailProvider(airportId));
    final faaId = airportAsync.whenOrNull(
        data: (a) => a?['identifier'] as String?) ?? airportId;
    final isStarred = starredIds.contains(faaId);

    return IconButton(
      icon: Icon(
        isStarred ? Icons.star : Icons.star_border,
        color: isStarred ? Colors.amber : null,
      ),
      onPressed: () async {
        final client = ref.read(apiClientProvider);
        try {
          if (isStarred) {
            await client.unstarAirport(faaId);
          } else {
            await client.starAirport(airportId);
          }
          ref.invalidate(starredAirportsProvider);
        } catch (_) {
          // ignore
        }
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _AtisAudioBar extends ConsumerWidget {
  final String airportId;
  const _AtisAudioBar({required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(atisAudioProvider(airportId));

    // Only show the bar once the user has initiated playback
    if (!audioState.isPlaying && !audioState.isLoading) {
      return const SizedBox.shrink();
    }

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            _buildPlayButton(ref, audioState),
            const SizedBox(width: 10),
            Icon(
              Icons.cell_tower,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                audioState.error ?? 'ATIS Audio',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: audioState.error != null
                      ? AppColors.error
                      : AppColors.primary,
                ),
              ),
            ),
            if (audioState.isPlaying)
              _PulsingDot(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton(WidgetRef ref, AtisAudioState audioState) {
    return GestureDetector(
      onTap: () => ref.read(atisAudioProvider(airportId).notifier).stop(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (audioState.isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (audioState.isLoading) const SizedBox(width: 6),
          Icon(
            Icons.stop_circle,
            size: 28,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.3 + 0.7 * _controller.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
