import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/aircraft.dart';
import '../../services/aircraft_providers.dart';

class AircraftScreen extends ConsumerStatefulWidget {
  const AircraftScreen({super.key});

  @override
  ConsumerState<AircraftScreen> createState() => _AircraftScreenState();
}

class _AircraftScreenState extends ConsumerState<AircraftScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final aircraftAsync = ref.watch(aircraftListProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aircraft'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: AppColors.accent,
            onPressed: () => context.go('/aircraft/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search aircraft...',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppColors.textMuted, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: aircraftAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    const Text('Failed to load aircraft',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref
                          .invalidate(aircraftListProvider(_searchQuery)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (aircraftList) {
                if (aircraftList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flight,
                            size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        const Text('No Aircraft',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 8),
                        const Text('Tap + to add an aircraft',
                            style: TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                return _buildList(aircraftList);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Aircraft> aircraftList) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: aircraftList.length,
      itemBuilder: (context, index) =>
          _buildAircraftCard(aircraftList[index]),
    );
  }

  Widget _buildAircraftCard(Aircraft aircraft) {
    final typeDisplay = aircraft.icaoTypeCode != null
        ? '${aircraft.aircraftType} (${aircraft.icaoTypeCode})'
        : aircraft.aircraftType;

    return InkWell(
      onTap: () {
        if (aircraft.id != null) {
          context.go('/aircraft/${aircraft.id}');
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.flight,
                  color: AppColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(aircraft.tailNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      if (aircraft.isDefault) ...[
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
                  const SizedBox(height: 2),
                  Text(typeDisplay,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      )),
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
}
