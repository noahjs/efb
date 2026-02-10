import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/approach_chart.dart';
import '../../../services/cifp_providers.dart';

class ApproachListScreen extends ConsumerWidget {
  final String airportId;

  const ApproachListScreen({super.key, required this.airportId});

  static const _typeOrder = ['I', 'L', 'R', 'P', 'V', 'D', 'N', 'X', 'B'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approachesAsync = ref.watch(approachListProvider(airportId));

    return Scaffold(
      appBar: AppBar(
        title: Text('$airportId Approaches'),
      ),
      body: approachesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load approaches:\n$err',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (approaches) {
          if (approaches.isEmpty) {
            return const Center(
              child: Text(
                'No approaches found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          // Group by route type
          final grouped = <String, List<ApproachSummary>>{};
          for (final a in approaches) {
            // Skip transition records — only show base approaches
            if (a.transitionIdentifier != null &&
                a.transitionIdentifier!.isNotEmpty) {
              continue;
            }
            grouped.putIfAbsent(a.routeType, () => []).add(a);
          }

          // Sort groups by type order
          final sortedKeys = grouped.keys.toList()
            ..sort((a, b) {
              final ai = _typeOrder.indexOf(a);
              final bi = _typeOrder.indexOf(b);
              return (ai < 0 ? 99 : ai).compareTo(bi < 0 ? 99 : bi);
            });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sortedKeys.length,
            itemBuilder: (context, groupIdx) {
              final type = sortedKeys[groupIdx];
              final items = grouped[type]!;
              final typeName = items.first.routeTypeName;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      typeName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ...items.map((a) => _ApproachTile(
                        airportId: airportId,
                        approach: a,
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ApproachTile extends StatelessWidget {
  final String airportId;
  final ApproachSummary approach;

  const _ApproachTile({
    required this.airportId,
    required this.approach,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        dense: true,
        title: Text(
          approach.procedureName,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          [
            if (approach.runwayIdentifier != null)
              'RWY ${approach.runwayIdentifier}',
            '${approach.legCount} legs',
          ].join(' · '),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textMuted,
          size: 20,
        ),
        onTap: () {
          context.push(
            '/airports/$airportId/approaches/${approach.id}',
          );
        },
      ),
    );
  }
}
