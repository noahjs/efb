import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../imagery_providers.dart';
import 'advisory_map.dart';
import 'feature_detail_panel.dart';

class TfrViewer extends ConsumerWidget {
  const TfrViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(tfrsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TFRs'),
        backgroundColor: AppColors.toolbarBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(tfrsProvider),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Unable to load TFRs',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(tfrsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(
              child: Text('No data available',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          final features = (data['features'] as List<dynamic>?) ?? [];

          if (features.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 48, color: AppColors.success),
                  const SizedBox(height: 16),
                  const Text(
                    'No active TFRs',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return _TfrMapBody(geojson: data);
        },
      ),
    );
  }
}

class _TfrMapBody extends StatefulWidget {
  final Map<String, dynamic> geojson;

  const _TfrMapBody({required this.geojson});

  @override
  State<_TfrMapBody> createState() => _TfrMapBodyState();
}

class _TfrMapBodyState extends State<_TfrMapBody> {
  List<Map<String, dynamic>> _selectedTfrs = [];

  void _onFeaturesTapped(List<Map<String, dynamic>> propsList) {
    setState(() {
      _selectedTfrs = propsList;
    });
  }

  @override
  Widget build(BuildContext context) {
    final featureCount =
        (widget.geojson['features'] as List<dynamic>?)?.length ?? 0;

    return Stack(
      children: [
        AdvisoryMap(
          geojson: widget.geojson,
          onFeaturesTapped: _onFeaturesTapped,
        ),

        // Feature count badge
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$featureCount TFRs',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),

        // Legend
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _legendItem('Active', const Color(0xFFFF5252)),
                const SizedBox(height: 4),
                _legendItem('Upcoming', const Color(0xFFFFC107)),
              ],
            ),
          ),
        ),

        // Selected TFR detail panel
        if (_selectedTfrs.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FeatureDetailPanel(
              features: _selectedTfrs,
              label: 'TFR',
              labelPlural: 'TFRs',
              itemBuilder: (props) => _TfrDetailItem(properties: props),
              onClose: () => setState(() => _selectedTfrs = []),
            ),
          ),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _TfrDetailItem extends StatelessWidget {
  final Map<String, dynamic> properties;

  const _TfrDetailItem({required this.properties});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const SizedBox(height: 6),
        _buildInfoRow(),
        _buildTimes(),
        _buildDescription(),
      ],
    );
  }

  Widget _buildHeader() {
    final notamNumber = _str(properties['notamNumber']);
    final type = _str(properties['type']).toUpperCase();
    final status = _str(properties['status']);
    final isActive = status == 'active';
    final color = isActive ? const Color(0xFFFF5252) : const Color(0xFFFFC107);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            type.isNotEmpty ? type : 'TFR',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          notamNumber,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isActive ? 'ACTIVE' : 'UPCOMING',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow() {
    final badges = <Widget>[];

    // Altitude
    final altitude = _str(properties['altitude']);
    if (altitude.isNotEmpty) {
      badges.add(infoBadge(Icons.height, altitude));
    }

    // Location
    final location = _str(properties['location']);
    if (location.isNotEmpty) {
      badges.add(infoBadge(Icons.location_on_outlined, location));
    } else {
      final state = _str(properties['state']);
      if (state.isNotEmpty) {
        badges.add(infoBadge(Icons.location_on_outlined, state));
      }
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: badges,
    );
  }

  Widget _buildTimes() {
    final start = _str(properties['effectiveStart']);
    final end = _str(properties['effectiveEnd']);
    if (start.isEmpty && end.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (start.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'From: $start',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          if (end.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'To: $end',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescription() {
    // Show reason first, then the full NOTAM text
    final reason = _str(properties['reason']);
    final notamText = _str(properties['notamText']);
    final description = _str(properties['description']);

    // Use the most informative text available
    final displayText = notamText.isNotEmpty
        ? notamText
        : description.isNotEmpty
            ? description
            : '';

    if (reason.isEmpty && displayText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                reason,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (displayText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                displayText.trim(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _str(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }
}
