import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'imagery_providers.dart';

class ImageryScreen extends ConsumerWidget {
  const ImageryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(imageryCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Imagery'),
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                'Unable to load imagery catalog',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(imageryCatalogProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (catalog) {
          final sections =
              (catalog['sections'] as List<dynamic>?) ?? [];

          return ListView.builder(
            itemCount: sections.length,
            itemBuilder: (context, sectionIndex) {
              final section = sections[sectionIndex] as Map<String, dynamic>;
              final title = section['title'] as String? ?? '';
              final products =
                  (section['products'] as List<dynamic>?) ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Container(
                    width: double.infinity,
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  // Product rows
                  ...products.map((product) {
                    final p = product as Map<String, dynamic>;
                    final name = p['name'] as String? ?? '';
                    final type = p['type'] as String? ?? '';

                    return Column(
                      children: [
                        Material(
                          color: AppColors.card,
                          child: InkWell(
                            onTap: () => _onProductTap(context, p),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _iconForType(type),
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 0.5, indent: 48),
                      ],
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'gfa':
        return Icons.cloud_outlined;
      case 'geojson':
        return Icons.map_outlined;
      default:
        return Icons.image_outlined;
    }
  }

  void _onProductTap(BuildContext context, Map<String, dynamic> product) {
    final type = product['type'] as String? ?? '';
    final id = product['id'] as String? ?? '';
    final params = product['params'] as Map<String, dynamic>?;

    if (type == 'gfa' && params != null) {
      final gfaType = params['gfaType'] as String? ?? 'clouds';
      final region = params['region'] as String? ?? 'us';
      final name = product['name'] as String? ?? 'GFA';
      context.push('/imagery/gfa?type=$gfaType&region=$region&name=$name');
    } else if (type == 'geojson') {
      if (id == 'pireps') {
        context.push('/imagery/pireps');
      } else {
        final name = product['name'] as String? ?? '';
        context.push('/imagery/advisory?type=$id&name=$name');
      }
    }
  }
}
