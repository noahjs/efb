import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../imagery_providers.dart';

class IcingViewer extends ConsumerStatefulWidget {
  final String icingParam;
  final String name;

  const IcingViewer({
    super.key,
    required this.icingParam,
    required this.name,
  });

  @override
  ConsumerState<IcingViewer> createState() => _IcingViewerState();
}

class _IcingViewerState extends ConsumerState<IcingViewer> {
  static const _forecastHours = [0, 3, 6, 9, 12, 15, 18];

  static const _levels = [
    ('MAX', 'max'),
    ('3K', '030'),
    ('6K', '060'),
    ('9K', '090'),
    ('12K', '120'),
    ('15K', '150'),
    ('18K', '180'),
    ('21K', '210'),
    ('24K', '240'),
    ('27K', '270'),
  ];

  int _selectedHour = 0;
  String _selectedLevel = 'max';
  late String _selectedParam;

  @override
  void initState() {
    super.initState();
    _selectedParam = widget.icingParam;
  }

  String get _title =>
      _selectedParam == 'prob' ? 'Icing Probability' : 'Icing Severity';

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
    final params = IcingChartParams(
      icingParam: _selectedParam,
      level: _selectedLevel,
      forecastHour: _selectedHour,
    );
    final imageAsync = ref.watch(icingChartProvider(params));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_title),
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
                          ref.invalidate(icingChartProvider(params)),
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
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
          // Probability / Severity toggle
          Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.only(left: 4, right: 4, top: 4, bottom: 12),
            child: Row(
              children: [
                _buildParamButton('Probability', 'prob'),
                const SizedBox(width: 4),
                _buildParamButton('Severity', 'sev'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamButton(String label, String paramCode) {
    final isSelected = paramCode == _selectedParam;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedParam = paramCode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
