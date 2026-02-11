import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';
import '../../../../services/api_client.dart';

class GfaDetail extends ConsumerStatefulWidget {
  final String title;
  final List<GfaProduct> products;

  const GfaDetail({
    super.key,
    required this.title,
    required this.products,
  });

  @override
  ConsumerState<GfaDetail> createState() => _GfaDetailState();
}

class _GfaDetailState extends ConsumerState<GfaDetail> {
  int _selectedProductIdx = 0;
  int _selectedHourIdx = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return Center(
        child: Text('No ${widget.title} available',
            style: const TextStyle(color: AppColors.textMuted)),
      );
    }

    final api = ref.watch(apiClientProvider);
    final product = widget.products[_selectedProductIdx];
    final forecastHour = product.forecastHours.isNotEmpty
        ? product.forecastHours[_selectedHourIdx]
        : 3;
    final imageUrl =
        api.getGfaImageUrl(product.type, product.region, forecastHour: forecastHour);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // Region selector
        if (widget.products.length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final isSelected = idx == _selectedProductIdx;
                return ChoiceChip(
                  label: Text(
                    widget.products[idx].regionName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() {
                    _selectedProductIdx = idx;
                    _selectedHourIdx = 0;
                  }),
                  selectedColor: AppColors.primary.withAlpha(60),
                  backgroundColor: AppColors.surface,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Forecast hour selector
        if (product.forecastHours.length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: product.forecastHours.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final isSelected = idx == _selectedHourIdx;
                return ChoiceChip(
                  label: Text(
                    '+${product.forecastHours[idx]}h',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _selectedHourIdx = idx),
                  selectedColor: AppColors.primary.withAlpha(60),
                  backgroundColor: AppColors.surface,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        // GFA image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
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
                  'Image unavailable',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
