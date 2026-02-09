import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/currency_item.dart';
import '../../services/logbook_providers.dart';

class CurrencyScreen extends ConsumerWidget {
  const CurrencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyAsync = ref.watch(logbookCurrencyProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/logbook'),
        ),
        title: const Text('Currency'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(logbookCurrencyProvider);
        },
        child: currencyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 100),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load currency',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(logbookCurrencyProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        const Text('No Currency Data',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            )),
                        const SizedBox(height: 8),
                        const Text(
                            'Add logbook entries and certificates to track currency',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _buildCurrencyCard(items[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrencyCard(CurrencyItem item) {
    String expirationDisplay = '';
    if (item.expirationDate != null) {
      try {
        final date = DateTime.parse(item.expirationDate!);
        expirationDisplay = DateFormat('MMM d, yyyy').format(date);
      } catch (_) {
        expirationDisplay = item.expirationDate!;
      }
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: name + status dot
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.statusColor,
                ),
              ),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                item.statusLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: item.statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // FAR reference
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              item.rule,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Details
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              item.details,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // Expiration date
          if (expirationDisplay.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Text(
                item.status == 'expired'
                    ? 'Expired: $expirationDisplay'
                    : 'Expires: $expirationDisplay',
                style: TextStyle(
                  fontSize: 13,
                  color: item.statusColor,
                ),
              ),
            ),
          ],

          // Action required
          if (item.actionRequired != null &&
              item.actionRequired!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      size: 14, color: AppColors.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.actionRequired!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
