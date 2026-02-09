import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../imagery_providers.dart';

class ConvectiveViewer extends ConsumerStatefulWidget {
  const ConvectiveViewer({super.key});

  @override
  ConsumerState<ConvectiveViewer> createState() => _ConvectiveViewerState();
}

class _ConvectiveViewerState extends ConsumerState<ConvectiveViewer> {
  int _selectedDay = 1;
  String _selectedType = 'cat';

  // Day 1 has all types; Day 2 has cat + torn/wind/hail; Day 3 only categorical
  static const _day1Types = [
    ('Categorical', 'cat'),
    ('Tornado', 'torn'),
    ('Hail', 'hail'),
    ('Wind', 'wind'),
  ];

  static const _day2Types = [
    ('Categorical', 'cat'),
    ('Tornado', 'torn'),
    ('Hail', 'hail'),
    ('Wind', 'wind'),
  ];

  List<(String, String)> get _availableTypes {
    switch (_selectedDay) {
      case 1:
        return _day1Types;
      case 2:
        return _day2Types;
      default:
        return [('Categorical', 'cat')];
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = ConvectiveOutlookParams(
      day: _selectedDay,
      type: _selectedType,
    );
    final imageAsync = ref.watch(convectiveOutlookProvider(params));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Convective Outlook'),
        backgroundColor: AppColors.toolbarBackground,
      ),
      body: Column(
        children: [
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
                          ref.invalidate(convectiveOutlookProvider(params)),
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
          // Type selector (only when more than categorical available)
          if (_availableTypes.length > 1)
            Container(
              color: AppColors.surface,
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: _availableTypes.map((entry) {
                  final (label, code) = entry;
                  final isSelected = code == _selectedType;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedType = code),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
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
          // Day selector
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.only(
              left: 4,
              right: 4,
              top: _availableTypes.length > 1 ? 4 : 8,
              bottom: 12,
            ),
            child: Row(
              children: [1, 2, 3].map((day) {
                final isSelected = day == _selectedDay;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDay = day;
                          // Reset to categorical if current type isn't
                          // available for the new day
                          final types = _availableTypes.map((e) => e.$2);
                          if (!types.contains(_selectedType)) {
                            _selectedType = 'cat';
                          }
                        });
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Day $day',
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
