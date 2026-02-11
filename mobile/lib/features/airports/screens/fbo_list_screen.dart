import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/fbo.dart';
import '../../../services/airport_providers.dart';

class FboListScreen extends ConsumerWidget {
  final String airportId;

  const FboListScreen({super.key, required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fbosAsync = ref.watch(airportFbosProvider(airportId));

    return Scaffold(
      appBar: AppBar(
        title: Text('FBOs - $airportId'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: fbosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load FBOs',
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        data: (fbos) {
          if (fbos.isEmpty) {
            return const Center(
              child: Text(
                'No FBOs at this airport',
                style: TextStyle(color: AppColors.textMuted, fontSize: 16),
              ),
            );
          }
          return ListView.separated(
            itemCount: fbos.length,
            separatorBuilder: (_, _) => const Divider(
              height: 1,
              color: AppColors.divider,
            ),
            itemBuilder: (context, index) => _FboRow(
              fbo: fbos[index],
              onTap: () => context.push(
                '/airports/$airportId/fbos/${fbos[index].id}',
                extra: fbos[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FboRow extends StatelessWidget {
  final Fbo fbo;
  final VoidCallback onTap;

  const _FboRow({required this.fbo, required this.onTap});

  static const _highlightBadges = {
    'Crew cars': 'Crew Car',
    'Go Rentals': 'Rental Car',
    'CAA Preferred FBO': 'CAA',
    'Avfuel Contract Fuel': 'AvFuel',
    'U.S. Customs Service': 'Customs',
  };

  @override
  Widget build(BuildContext context) {
    final tags = fbo.badges
        .where((b) => _highlightBadges.containsKey(b))
        .map((b) => _highlightBadges[b]!)
        .toList();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fbo.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (fbo.phone != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      fbo.phone!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: AppColors.divider, width: 0.5),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (fbo.cheapest100LL != null)
                  _PriceChip(
                    label: '100LL',
                    price: fbo.cheapest100LL!,
                    color: Colors.green,
                  ),
                if (fbo.cheapest100LL != null && fbo.cheapestJetA != null)
                  const SizedBox(height: 4),
                if (fbo.cheapestJetA != null)
                  _PriceChip(
                    label: 'Jet-A',
                    price: fbo.cheapestJetA!,
                    color: Colors.blue,
                  ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final double price;
  final Color color;

  const _PriceChip({
    required this.label,
    required this.price,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
        ),
        const SizedBox(width: 4),
        Text(
          '\$${price.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
