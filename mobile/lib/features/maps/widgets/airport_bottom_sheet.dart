import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/api_client.dart';
import '../../../services/airport_providers.dart';

class AirportBottomSheet extends ConsumerWidget {
  final String airportId;

  const AirportBottomSheet({super.key, required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airportAsync = ref.watch(airportDetailProvider(airportId));
    final frequenciesAsync = ref.watch(airportFrequenciesProvider(airportId));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: airportAsync.when(
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.textMuted, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Unable to load $airportId',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () =>
                      ref.invalidate(airportDetailProvider(airportId)),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                  ),
                ),
              ],
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
          final location =
              [city, state].where((s) => s.isNotEmpty).join(', ');

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Identifier + name + star
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      airportId,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StarIcon(
                      airportId: airportId,
                      faaIdentifier: airport['identifier'] ?? airportId,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // City, state + elevation
                Row(
                  children: [
                    if (location.isNotEmpty)
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    if (elevation != null)
                      Text(
                        '${elevation}ft MSL',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Frequencies
                frequenciesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (frequencies) {
                    final keyFreqs = _filterKeyFrequencies(frequencies);
                    if (keyFreqs.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: AppColors.divider),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: keyFreqs
                              .map((f) => _FrequencyChip(
                                    type: f['type'] as String,
                                    frequency: f['frequency'] as String,
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                // View Full Details button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/airports/$airportId');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'View Full Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Map<String, String>> _filterKeyFrequencies(List<dynamic> frequencies) {
    const keyTypes = ['ATIS', 'ASOS', 'AWOS', 'TWR', 'GND', 'CD', 'CTAF', 'UNICOM'];
    final result = <Map<String, String>>[];

    for (final f in frequencies) {
      if (f is! Map) continue;
      final type = (f['type'] ?? f['frequencyType'] ?? '') as String;
      final freq = (f['frequency'] ?? '') as String;
      if (freq.isEmpty) continue;

      final upperType = type.toUpperCase();
      for (final key in keyTypes) {
        if (upperType.contains(key)) {
          result.add({'type': key, 'frequency': freq});
          break;
        }
      }
    }
    return result;
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
      child: Icon(
        isStarred ? Icons.star : Icons.star_border,
        color: isStarred ? Colors.amber : AppColors.textMuted,
        size: 24,
      ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  final String type;
  final String frequency;

  const _FrequencyChip({required this.type, required this.frequency});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            type,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          frequency,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
