import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../imagery_providers.dart';

class ProgViewer extends ConsumerStatefulWidget {
  final String progType;
  final String name;

  const ProgViewer({
    super.key,
    required this.progType,
    required this.name,
  });

  @override
  ConsumerState<ProgViewer> createState() => _ProgViewerState();
}

class _ProgViewerState extends ConsumerState<ProgViewer> {
  static const _lowForecastHours = [6, 12, 18, 24, 30, 36, 48, 60];
  late int _selectedHour;

  bool get _isLow => widget.progType == 'low';

  String _validTimeLabel(int forecastHour) {
    final now = DateTime.now().toUtc();
    final validUtc = now.add(Duration(hours: forecastHour));
    final validLocal = validUtc.toLocal();
    final localFmt = DateFormat('EEE h:mm a').format(validLocal);
    final utcFmt = DateFormat('HH:mm').format(validUtc);
    return 'Valid ~${utcFmt}Z / $localFmt local';
  }

  @override
  void initState() {
    super.initState();
    _selectedHour = _isLow ? 6 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final params = ProgChartParams(
      progType: widget.progType,
      forecastHour: _selectedHour,
    );
    final imageAsync = ref.watch(progChartProvider(params));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.name),
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
                          ref.invalidate(progChartProvider(params)),
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
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: EdgeInsets.only(
              top: 10,
              left: 16,
              right: 16,
              bottom: _isLow ? 0 : 10,
            ),
            child: Text(
              _validTimeLabel(_selectedHour),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (_isLow)
            Container(
              color: AppColors.surface,
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _lowForecastHours.map((hour) {
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
