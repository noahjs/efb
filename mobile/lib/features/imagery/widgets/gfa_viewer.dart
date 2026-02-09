import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../imagery_providers.dart';

class GfaViewer extends ConsumerStatefulWidget {
  final String gfaType;
  final String region;
  final String name;

  const GfaViewer({
    super.key,
    required this.gfaType,
    required this.region,
    required this.name,
  });

  @override
  ConsumerState<GfaViewer> createState() => _GfaViewerState();
}

class _GfaViewerState extends ConsumerState<GfaViewer> {
  static const _forecastHours = [3, 6, 9, 12, 15, 18];
  int _selectedHour = 3;

  @override
  Widget build(BuildContext context) {
    final params = GfaImageParams(
      gfaType: widget.gfaType,
      region: widget.region,
      forecastHour: _selectedHour,
    );
    final imageAsync = ref.watch(gfaImageProvider(params));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.name),
        backgroundColor: AppColors.toolbarBackground,
      ),
      body: Column(
        children: [
          // Image area
          Expanded(
            child: imageAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image,
                        size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load image',
                      style:
                          const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(gfaImageProvider(params)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (bytes) {
                if (bytes == null) {
                  return const Center(
                    child: Text(
                      'Image not available',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return InteractiveViewer(
                  maxScale: 5.0,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                );
              },
            ),
          ),

          // Time step selector
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _forecastHours.map((hour) {
                final isSelected = hour == _selectedHour;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedHour = hour),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${hour}HR',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
