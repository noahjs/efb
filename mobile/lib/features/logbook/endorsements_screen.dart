import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/endorsement.dart';
import '../../services/endorsements_providers.dart';

class EndorsementsScreen extends ConsumerStatefulWidget {
  const EndorsementsScreen({super.key});

  @override
  ConsumerState<EndorsementsScreen> createState() => _EndorsementsScreenState();
}

class _EndorsementsScreenState extends ConsumerState<EndorsementsScreen> {
  @override
  Widget build(BuildContext context) {
    final endorsementsAsync = ref.watch(endorsementsListProvider(''));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/logbook'),
        ),
        title: const Text('Endorsements'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: AppColors.accent,
            onPressed: () => context.go('/endorsements/new'),
          ),
        ],
      ),
      body: endorsementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load endorsements',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(endorsementsListProvider('')),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (endorsements) {
          if (endorsements.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_outlined,
                      size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('No Endorsements',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 8),
                  const Text('Tap + to add an endorsement',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: endorsements.length,
            itemBuilder: (context, index) =>
                _buildEndorsementCard(endorsements[index]),
          );
        },
      ),
    );
  }

  Widget _buildEndorsementCard(Endorsement endorsement) {
    final type = endorsement.endorsementType ?? 'Untitled';
    final cfi = endorsement.cfiName ?? '';
    final far = endorsement.farReference ?? '';

    String dateDisplay = '';
    if (endorsement.date != null) {
      try {
        final date = DateTime.parse(endorsement.date!);
        dateDisplay = DateFormat('MMM d, yyyy').format(date);
      } catch (_) {
        dateDisplay = endorsement.date!;
      }
    }

    return InkWell(
      onTap: () {
        if (endorsement.id != null) {
          context.go('/endorsements/${endorsement.id}');
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (cfi.isNotEmpty)
                        Text(
                          cfi,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (cfi.isNotEmpty && far.isNotEmpty)
                        const Text(
                          '  \u2022  ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      if (far.isNotEmpty)
                        Text(
                          'FAR $far',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (dateDisplay.isNotEmpty)
              Text(
                dateDisplay,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.accent,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
