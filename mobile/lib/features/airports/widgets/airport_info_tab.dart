import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/airport_providers.dart';

class AirportInfoTab extends ConsumerWidget {
  final String airportId;
  const AirportInfoTab({super.key, required this.airportId});

  /// Map backend frequency type codes to display section titles
  static const _typeSections = {
    'ATIS': 'WEATHER AND ADVISORY',
    'AWOS': 'WEATHER AND ADVISORY',
    'ASOS': 'WEATHER AND ADVISORY',
    'CD': 'CLEARANCE',
    'GND': 'GROUND',
    'TWR': 'TOWER',
    'APP': 'APPROACH / DEPARTURE',
    'DEP': 'APPROACH / DEPARTURE',
    'CTAF': 'UNICOM / CTAF',
    'UNIC': 'UNICOM / CTAF',
  };

  /// Ordering for sections
  static const _sectionOrder = [
    'WEATHER AND ADVISORY',
    'CLEARANCE',
    'GROUND',
    'TOWER',
    'APPROACH / DEPARTURE',
    'UNICOM / CTAF',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freqAsync = ref.watch(airportFrequenciesProvider(airportId));

    return freqAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
        child: Text(
          'Failed to load frequencies',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (frequencies) {
        if (frequencies.isEmpty) {
          return const Center(
            child: Text(
              'No frequency data available',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        // Group frequencies by section title
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final freq in frequencies) {
          final map = freq as Map<String, dynamic>;
          final type = map['type'] as String? ?? '';
          final section = _typeSections[type] ?? 'OTHER';
          grouped.putIfAbsent(section, () => []).add(map);
        }

        // Build ordered section list
        final sections = <String>[];
        for (final s in _sectionOrder) {
          if (grouped.containsKey(s)) sections.add(s);
        }
        // Add any extra sections not in the predefined order
        for (final s in grouped.keys) {
          if (!sections.contains(s)) sections.add(s);
        }

        return ListView(
          children: [
            for (final section in sections)
              _FrequencySection(
                title: section,
                items: grouped[section]!
                    .map((f) => _FrequencyItem(
                          name: f['name'] as String? ?? '',
                          phone: f['phone'] as String?,
                          frequency: f['frequency'] as String?,
                        ))
                    .toList(),
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _FrequencySection extends StatelessWidget {
  final String title;
  final List<_FrequencyItem> items;

  const _FrequencySection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _FrequencyItem extends StatelessWidget {
  final String name;
  final String? phone;
  final String? frequency;

  const _FrequencyItem({
    required this.name,
    this.phone,
    this.frequency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (phone != null && phone!.isNotEmpty)
                  Text(
                    phone!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (frequency != null && frequency!.isNotEmpty)
            Text(
              frequency!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}
