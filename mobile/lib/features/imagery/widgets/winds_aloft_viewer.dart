import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../imagery_providers.dart';

class WindsAloftViewer extends ConsumerStatefulWidget {
  const WindsAloftViewer({super.key});

  @override
  ConsumerState<WindsAloftViewer> createState() => _WindsAloftViewerState();
}

class _WindsAloftViewerState extends ConsumerState<WindsAloftViewer> {
  static const _forecastHours = [6, 12, 18, 24, 30, 36];

  static const _levels = [
    ('5K', '050'),
    ('10K', '100'),
    ('18K', '180'),
    ('24K', '240'),
    ('30K', '300'),
    ('34K', '340'),
    ('39K', '390'),
    ('45K', '450'),
  ];

  static const _areas = [
    ('NE', 'a'),
    ('SE', 'b1'),
    ('N.Cen', 'c'),
    ('S.Cen', 'd'),
    ('Rockies', 'e'),
    ('Pacific', 'f'),
    ('Gr.Basin', 'g'),
    ('Alaska', 'h'),
    ('Hawaii', 'j'),
  ];

  int _selectedHour = 6;
  String _selectedLevel = '100';
  String _selectedArea = 'a';

  String _validTimeLabel(int forecastHour) {
    final now = DateTime.now().toUtc();
    final validUtc = now.add(Duration(hours: forecastHour));
    final validLocal = validUtc.toLocal();
    final localFmt = DateFormat('EEE h:mm a').format(validLocal);
    final utcFmt = DateFormat('HH:mm').format(validUtc);
    return 'Valid ~${utcFmt}Z / $localFmt local';
  }

  @override
  Widget build(BuildContext context) {
    final params = WindsAloftChartParams(
      level: _selectedLevel,
      area: _selectedArea,
      forecastHour: _selectedHour,
    );
    final imageAsync = ref.watch(windsAloftChartProvider(params));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Winds Aloft'),
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
                          ref.invalidate(windsAloftChartProvider(params)),
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
          // Valid time label
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.only(top: 10, left: 16, right: 16),
            child: Text(
              _validTimeLabel(_selectedHour),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          // Area selector
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _areas.map((entry) {
                  final (label, code) = entry;
                  final isSelected = code == _selectedArea;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedArea = code),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
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
                  );
                }).toList(),
              ),
            ),
          ),
          // Altitude level selector
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _levels.map((entry) {
                  final (label, code) = entry;
                  final isSelected = code == _selectedLevel;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedLevel = code),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
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
                  );
                }).toList(),
              ),
            ),
          ),
          // Forecast hour selector
          Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.only(left: 4, right: 4, top: 8, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _forecastHours.map((hour) {
                final isSelected = hour == _selectedHour;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedHour = hour),
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
