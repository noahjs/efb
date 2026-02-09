import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/logbook_entry.dart';
import '../../services/logbook_providers.dart';

class LogbookScreen extends ConsumerStatefulWidget {
  const LogbookScreen({super.key});

  @override
  ConsumerState<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends ConsumerState<LogbookScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(logbookListProvider(_searchQuery));
    final summaryAsync = ref.watch(logbookSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logbook'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            color: AppColors.accent,
            onPressed: () => context.go('/logbook/experience'),
          ),
          IconButton(
            icon: const Icon(Icons.verified),
            color: AppColors.accent,
            onPressed: () => context.go('/endorsements'),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            color: AppColors.accent,
            onPressed: () => context.go('/logbook/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary header
          summaryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (summary) {
              final totalEntries = summary['totalEntries'] ?? 0;
              final totalTime = summary['totalTime'] ?? 0.0;
              return _buildSummaryHeader(totalEntries, totalTime, summary);
            },
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Date, Tail Number, Route, etc.',
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

          // Entries list
          Expanded(
            child: entriesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load logbook',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref
                          .invalidate(logbookListProvider(_searchQuery)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.book_outlined,
                            size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        const Text('No Logbook Entries',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 8),
                        const Text('Tap + to log a flight',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                return _buildGroupedList(entries);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(
      int totalEntries, num totalTime, Map<String, dynamic> summary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Entries section header
          _buildSummarySectionHeader('Entries'),
          const SizedBox(height: 8),
          _buildSummaryRow('All', totalTime.toStringAsFixed(1)),
          _buildSummaryRow(
              'Last 7 Days', (summary['last7Days'] ?? 0.0).toStringAsFixed(1)),
          _buildSummaryRow('Last 30 Days',
              (summary['last30Days'] ?? 0.0).toStringAsFixed(1)),
          _buildSummaryRow('Last 90 Days',
              (summary['last90Days'] ?? 0.0).toStringAsFixed(1)),
          _buildSummaryRow('Last 6 Months',
              (summary['last6Months'] ?? 0.0).toStringAsFixed(1)),
          _buildSummaryRow('Last 12 Months',
              (summary['last12Months'] ?? 0.0).toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _buildSummarySectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              )),
          Row(
            children: [
              Text(value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  )),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<LogbookEntry> entries) {
    final grouped = <String, List<LogbookEntry>>{};
    final monthFormat = DateFormat('MMMM yyyy');

    for (final entry in entries) {
      String key = 'NO DATE';
      if (entry.date != null) {
        try {
          final date = DateTime.parse(entry.date!);
          key = monthFormat.format(date).toUpperCase();
        } catch (_) {}
      }
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    final sections = grouped.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount:
          sections.fold<int>(0, (sum, e) => sum + 1 + e.value.length),
      itemBuilder: (context, index) {
        int cursor = 0;
        for (final section in sections) {
          if (index == cursor) {
            return _buildMonthHeader(section.key);
          }
          cursor++;
          if (index < cursor + section.value.length) {
            return _buildEntryCard(section.value[index - cursor]);
          }
          cursor += section.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMonthHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildEntryCard(LogbookEntry entry) {
    final from = entry.fromAirport ?? '----';
    final to = entry.toAirport ?? '----';
    final tail = entry.aircraftIdentifier ?? '--';
    final type = entry.aircraftType != null ? ' (${entry.aircraftType})' : '';
    final totalTime = entry.totalTime.toStringAsFixed(1);

    String dateDisplay = '--';
    if (entry.date != null) {
      try {
        final date = DateTime.parse(entry.date!);
        dateDisplay = DateFormat('MMM d, yyyy').format(date);
      } catch (_) {
        dateDisplay = entry.date!;
      }
    }

    final hasApproaches = entry.approaches != null &&
        entry.approaches!.isNotEmpty &&
        entry.approaches != '[]';

    return InkWell(
      onTap: () {
        if (entry.id != null) {
          context.go('/logbook/${entry.id}');
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
                  // Route: FROM - TO
                  Text(
                    '$from - $to',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Aircraft info
                  Row(
                    children: [
                      Text(
                        '$tail$type',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (hasApproaches) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.remove_red_eye,
                            size: 14, color: AppColors.textMuted),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateDisplay,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalTime Total',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
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
