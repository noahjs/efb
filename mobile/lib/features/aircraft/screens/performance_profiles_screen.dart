import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/aircraft.dart';
import '../../../services/aircraft_providers.dart';

class PerformanceProfilesScreen extends ConsumerStatefulWidget {
  final int aircraftId;

  const PerformanceProfilesScreen({super.key, required this.aircraftId});

  @override
  ConsumerState<PerformanceProfilesScreen> createState() =>
      _PerformanceProfilesScreenState();
}

class _PerformanceProfilesScreenState
    extends ConsumerState<PerformanceProfilesScreen> {
  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(aircraftDetailProvider(widget.aircraftId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/aircraft/${widget.aircraftId}'),
        ),
        title: const Text('Performance Profiles'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: AppColors.accent,
            onPressed: _addProfile,
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: AppColors.textSecondary))),
        data: (aircraft) {
          if (aircraft == null) {
            return const Center(child: Text('Aircraft not found'));
          }
          final profiles = aircraft.performanceProfiles;
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.speed,
                      size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('No Profiles',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text('Tap + to add a performance profile',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: profiles.length,
            itemBuilder: (context, index) =>
                _buildProfileTile(profiles[index]),
          );
        },
      ),
    );
  }

  Widget _buildProfileTile(PerformanceProfile profile) {
    return InkWell(
      onTap: () => context.go(
          '/aircraft/${widget.aircraftId}/profiles/${profile.id}'),
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
                  Row(
                    children: [
                      Text(profile.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      if (profile.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Default',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              )),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TAS ${profile.cruiseTas?.round() ?? '--'} kt  /  ${profile.cruiseFuelBurn ?? '--'} GPH',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _addProfile() async {
    final nameController = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('New Profile',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, nameController.text),
                  child: const Text('Create',
                      style: TextStyle(color: AppColors.accent)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                  hintText: 'e.g. Economy Cruise'),
              onSubmitted: (val) => Navigator.pop(ctx, val),
            ),
          ],
        ),
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        final service = ref.read(aircraftServiceProvider);
        await service.createProfile(widget.aircraftId, {'name': name});
        ref.invalidate(aircraftDetailProvider(widget.aircraftId));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create: $e')),
          );
        }
      }
    }
  }
}
