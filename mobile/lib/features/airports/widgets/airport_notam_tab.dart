import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/airport_providers.dart';

class AirportNotamTab extends ConsumerStatefulWidget {
  final String airportId;
  const AirportNotamTab({super.key, required this.airportId});

  @override
  ConsumerState<AirportNotamTab> createState() => _AirportNotamTabState();
}

class _AirportNotamTabState extends ConsumerState<AirportNotamTab>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<String> _classifications = [];

  void _updateTabs(List<dynamic> notams) {
    final classSet = <String>{};
    for (final notam in notams) {
      final c = (notam as Map<String, dynamic>)['classification'] as String?;
      if (c != null && c.isNotEmpty) classSet.add(c);
    }
    final sorted = classSet.toList()..sort();

    if (!_listEquals(sorted, _classifications)) {
      _classifications = sorted;
      _tabController?.dispose();
      _tabController = TabController(
        length: sorted.length + 1, // +1 for "All"
        vsync: this,
      );
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notamsAsync = ref.watch(notamsProvider(widget.airportId));

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
              onPressed: () =>
                  ref.invalidate(notamsProvider(widget.airportId)),
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
                  onPressed: () =>
                      ref.invalidate(notamsProvider(widget.airportId)),
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

        _updateTabs(notams);

        if (_tabController == null) {
          return _NotamListView(notams: notams, count: count);
        }

        // Count per classification
        final countByClass = <String, int>{};
        for (final notam in notams) {
          final c =
              (notam as Map<String, dynamic>)['classification'] as String? ??
                  '';
          if (c.isNotEmpty) countByClass[c] = (countByClass[c] ?? 0) + 1;
        }

        return Column(
          children: [
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(text: 'All ($count)'),
                  for (final c in _classifications)
                    Tab(text: '$c (${countByClass[c] ?? 0})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _NotamListView(notams: notams, count: count),
                  for (final c in _classifications)
                    _NotamListView(
                      notams: notams
                          .where((n) =>
                              (n as Map<String, dynamic>)['classification'] ==
                              c)
                          .toList(),
                      count: countByClass[c] ?? 0,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotamListView extends StatelessWidget {
  final List<dynamic> notams;
  final int count;

  const _NotamListView({required this.notams, required this.count});

  @override
  Widget build(BuildContext context) {
    if (notams.isEmpty) {
      return const Center(
        child: Text(
          'No NOTAMs in this category',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
          NotamCard(notam: notams[i] as Map<String, dynamic>),
          if (i < notams.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

class NotamCard extends StatelessWidget {
  final Map<String, dynamic> notam;
  final bool compact;

  const NotamCard({super.key, required this.notam, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final id = notam['id'] as String? ?? '';
    final type = notam['type'] as String? ?? '';
    final text = notam['text'] as String? ?? '';
    final classification = notam['classification'] as String? ?? '';
    final effectiveStart = notam['effectiveStart'] as String?;
    final effectiveEnd = notam['effectiveEnd'] as String?;

    final effectiveRange = _formatEffective(effectiveStart, effectiveEnd);

    return GestureDetector(
      onTap: () => showNotamDetail(context, notam),
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 12),
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
                if (classification.isNotEmpty && !compact)
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
            if (effectiveRange.isNotEmpty && !compact) ...[
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
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: compact ? 12 : 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
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

/// Shows the full NOTAM detail in a modal bottom sheet.
void showNotamDetail(BuildContext context, Map<String, dynamic> notam) {
  final id = notam['id'] as String? ?? '';
  final type = notam['type'] as String? ?? '';
  final fullText =
      notam['fullText'] as String? ?? notam['text'] as String? ?? '';
  final classification = notam['classification'] as String? ?? '';
  final effectiveStart = notam['effectiveStart'] as String?;
  final effectiveEnd = notam['effectiveEnd'] as String?;
  final effectiveRange =
      NotamCard._formatEffective(effectiveStart, effectiveEnd);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (type.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: NotamCard._typeColor(type).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: NotamCard._typeColor(type),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  'NOTAM $id',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (classification.isNotEmpty)
                  Text(
                    classification,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (effectiveRange.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  effectiveRange,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          const Divider(color: AppColors.divider, height: 16),
          // Full text
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: SelectableText(
                fullText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
