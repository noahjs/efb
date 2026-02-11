import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../services/api_client.dart';

class SynopsisDetail extends ConsumerWidget {
  const SynopsisDetail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final imageUrl = api.getProgChartUrl(type: 'sfc', forecastHour: 0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.map_outlined,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Surface Analysis Chart',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl != null
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    height: 300,
                    color: AppColors.surface,
                    child: const Center(
                      child: Text(
                        'Chart unavailable',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                )
              : Container(
                  height: 300,
                  color: AppColors.surface,
                  child: const Center(
                    child: Text(
                      'Chart unavailable',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
