import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/solar.dart';
import '../../../services/api_client.dart';
import '../../../services/airport_providers.dart';
import '../../airports/widgets/airport_info_tab.dart';
import '../../airports/widgets/airport_weather_tab.dart';
import '../../airports/widgets/airport_runway_tab.dart';
import '../../airports/widgets/airport_procedure_tab.dart';
import '../../airports/widgets/airport_notam_tab.dart';

class AirportBottomSheet extends ConsumerWidget {
  final String airportId;

  const AirportBottomSheet({super.key, required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.15,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.15, 0.5, 0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
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

class _AirportSheetContent extends ConsumerStatefulWidget {
  final String airportId;
  final ScrollController scrollController;

  const _AirportSheetContent({
    required this.airportId,
    required this.scrollController,
  });

  @override
  ConsumerState<_AirportSheetContent> createState() =>
      _AirportSheetContentState();
}

class _AirportSheetContentState extends ConsumerState<_AirportSheetContent>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final airportAsync = ref.watch(airportDetailProvider(widget.airportId));
    final frequenciesAsync =
        ref.watch(airportFrequenciesProvider(widget.airportId));

    return airportAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'Unable to load ${widget.airportId}',
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
                '${widget.airportId} not found',
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

        return CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            // Header bar
            SliverToBoxAdapter(
              child: Container(
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
                            widget.airportId,
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
                      airportId: widget.airportId,
                      faaIdentifier:
                          airport['identifier'] ?? widget.airportId,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            // Action buttons row
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.divider, width: 0.5),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    _ActionButton(label: 'Direct To', onTap: () {}),
                    _ActionButton(label: 'Add to Route', onTap: () {}),
                    _ActionButton(
                      label: 'Fullscreen',
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/airports/${widget.airportId}');
                      },
                    ),
                    _ActionButton(label: 'Hold...', onTap: () {}),
                  ],
                ),
              ),
            ),

            // Airport info section
            SliverToBoxAdapter(
              child: Padding(
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
                                  size: 14, color: Colors.amber.shade300),
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
                                  size: 14, color: Colors.blue.shade300),
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
            ),

            // Quick action buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    _QuickAction(label: '3D View', onTap: () {}),
                    const SizedBox(width: 8),
                    _QuickAction(label: 'Taxiways', onTap: () {}),
                    const SizedBox(width: 8),
                    _QuickAction(label: 'FBOs', onTap: () {}),
                    const SizedBox(width: 8),
                    _QuickAction(label: 'Comments', onTap: () {}),
                  ],
                ),
              ),
            ),

            // Tab bar
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Info'),
                    Tab(text: 'Weather'),
                    Tab(text: 'Runway'),
                    Tab(text: 'Procedure'),
                    Tab(text: 'NOTAM'),
                  ],
                  isScrollable: false,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  indicatorSize: TabBarIndicatorSize.tab,
                ),
              ),
            ),

            // Tab content (fixed height section)
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  AirportInfoTab(airportId: widget.airportId),
                  AirportWeatherTab(airportId: widget.airportId),
                  AirportRunwayTab(airportId: widget.airportId),
                  AirportProcedureTab(airportId: widget.airportId),
                  AirportNotamTab(airportId: widget.airportId),
                ],
              ),
            ),
          ],
        );
      },
    );
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
          color: isStarred ? Colors.amber : AppColors.textMuted,
          size: 24,
        ),
      ),
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
