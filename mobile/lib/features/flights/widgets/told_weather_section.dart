import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/told_providers.dart';
import 'flight_section_header.dart';

class ToldWeatherSection extends StatelessWidget {
  final ToldState toldState;
  final ToldStateNotifier notifier;

  const ToldWeatherSection({
    super.key,
    required this.toldState,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final windDir = toldState.windDir;
    final windSpeed = toldState.windSpeed;
    final tempC = toldState.tempC;
    final altimeter = toldState.altimeter;
    final metarRaw = toldState.metarRaw;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: FlightSectionHeader(title: 'Weather'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => notifier.refreshMetar(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 14, color: AppColors.accent),
                    SizedBox(width: 4),
                    Text(
                      'Refresh',
                      style: TextStyle(fontSize: 12, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        _WeatherRow(
          label: 'Wind Direction',
          value: windDir != null ? '${windDir.round()}°' : '--',
          onTap: () => _editNumericField(
            context,
            title: 'Wind Direction (°)',
            currentValue: windDir,
            onSave: (v) => notifier.setWindDir(v),
          ),
        ),
        _WeatherRow(
          label: 'Wind Speed',
          value: windSpeed != null ? '${windSpeed.round()} kts' : '--',
          onTap: () => _editNumericField(
            context,
            title: 'Wind Speed (kts)',
            currentValue: windSpeed,
            onSave: (v) => notifier.setWindSpeed(v),
          ),
        ),
        _WeatherRow(
          label: 'Temperature',
          value: tempC != null ? '${tempC.round()}°C' : '--',
          onTap: () => _editNumericField(
            context,
            title: 'Temperature (°C)',
            currentValue: tempC,
            onSave: (v) => notifier.setTempC(v),
          ),
        ),
        _WeatherRow(
          label: 'Altimeter',
          value: altimeter != null ? '${altimeter.toStringAsFixed(2)} inHg' : '--',
          onTap: () => _editNumericField(
            context,
            title: 'Altimeter (inHg)',
            currentValue: altimeter,
            onSave: (v) => notifier.setAltimeter(v),
          ),
        ),
        if (metarRaw != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              metarRaw,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
            ),
          ),
        if (toldState.usingCustomWeather)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: GestureDetector(
              onTap: () => notifier.resetWeatherToMetar(),
              child: const Text(
                'Reset to METAR',
                style: TextStyle(fontSize: 12, color: AppColors.accent),
              ),
            ),
          ),
      ],
    );
  }

  void _editNumericField(
    BuildContext context, {
    required String title,
    required double? currentValue,
    required void Function(double) onSave,
  }) {
    final controller =
        TextEditingController(text: currentValue?.toString() ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              onSubmitted: (val) {
                final parsed = double.tryParse(val);
                if (parsed != null) {
                  onSave(parsed);
                }
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final parsed = double.tryParse(controller.text);
                    if (parsed != null) {
                      onSave(parsed);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _WeatherRow({
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: onTap != null ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
