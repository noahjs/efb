import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/airport_providers.dart';

class AirportNotamTab extends ConsumerWidget {
  final String airportId;
  const AirportNotamTab({super.key, required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notamsAsync = ref.watch(notamsProvider(airportId));

    return notamsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Failed to load NOTAMs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(notamsProvider(airportId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (data) {
        if (data == null || data['error'] != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off,
                    size: 48, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  data?['error'] as String? ?? 'Unable to fetch NOTAMs',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(notamsProvider(airportId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final notams = data['notams'] as List<dynamic>? ?? [];
        final count = data['count'] as int? ?? 0;

        if (notams.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 48, color: AppColors.vfr),
                SizedBox(height: 16),
                Text(
                  'No active NOTAMs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Count header
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '$count active NOTAM${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            for (int i = 0; i < notams.length; i++) ...[
              _NotamCard(notam: notams[i] as Map<String, dynamic>),
              if (i < notams.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

class _NotamCard extends StatelessWidget {
  final Map<String, dynamic> notam;

  const _NotamCard({required this.notam});

  @override
  Widget build(BuildContext context) {
    final id = notam['id'] as String? ?? '';
    final type = notam['type'] as String? ?? '';
    final text = notam['text'] as String? ?? '';
    final classification = notam['classification'] as String? ?? '';
    final effectiveStart = notam['effectiveStart'] as String?;
    final effectiveEnd = notam['effectiveEnd'] as String?;

    final effectiveRange = _formatEffective(effectiveStart, effectiveEnd);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (type.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _typeColor(type).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _typeColor(type),
                    ),
                  ),
                ),
              if (type.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NOTAM $id',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (classification.isNotEmpty)
                Text(
                  classification,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          if (effectiveRange.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              effectiveRange,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  static Color _typeColor(String type) {
    switch (type.toUpperCase()) {
      case 'RWY':
        return AppColors.error;
      case 'AIRSPACE':
      case 'OBST':
        return AppColors.warning;
      case 'TWY':
      case 'AD':
      case 'APRON':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  static String _formatEffective(String? start, String? end) {
    if (start == null && end == null) return '';
    final startDt = start != null ? DateTime.tryParse(start) : null;
    final endDt = end != null ? DateTime.tryParse(end) : null;
    if (startDt == null && endDt == null) return '';
    final parts = <String>[];
    if (startDt != null) parts.add(_formatDateTime(startDt.toLocal()));
    if (endDt != null) parts.add(_formatDateTime(endDt.toLocal()));
    return parts.join(' → ');
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDateTime(DateTime dt) {
    final mon = _months[dt.month - 1];
    final day = dt.day;
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final time = m == '00' ? '$h12 $period' : '$h12:$m $period';
    return '$mon $day, $time';
  }
}
