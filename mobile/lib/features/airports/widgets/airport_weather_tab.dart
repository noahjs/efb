import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AirportWeatherTab extends StatelessWidget {
  final String airportId;
  const AirportWeatherTab({super.key, required this.airportId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          // Sub-tabs
          Container(
            color: AppColors.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'METAR'),
                Tab(text: 'TAF'),
                Tab(text: 'MOS'),
                Tab(text: 'Daily'),
                Tab(text: 'Winds'),
              ],
              isScrollable: false,
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontSize: 12),
              indicatorSize: TabBarIndicatorSize.tab,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _MetarView(airportId: airportId),
                _PlaceholderView(label: 'TAF data coming soon'),
                _PlaceholderView(label: 'MOS data coming soon'),
                _PlaceholderView(label: 'Daily forecast coming soon'),
                _PlaceholderView(label: 'Winds aloft coming soon'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetarView extends StatelessWidget {
  final String airportId;
  const _MetarView({required this.airportId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Flight category banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.vfr.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.vfr.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.vfr,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'VFR',
                style: TextStyle(
                  color: AppColors.vfr,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              const Text(
                '8m ago',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // Raw METAR
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$airportId 072347Z 25016G21KT 10SM FEW160 BKN220 15/M08 A3015',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppColors.vfr,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Decoded fields
        _WeatherField(label: 'Time', value: '4:47 PM MST'),
        _WeatherField(label: 'Wind', value: '250° at 16 - 21 kts'),
        _WeatherField(label: 'Visibility', value: '10 sm'),
        _WeatherField(
          label: 'Clouds (AGL)',
          value: 'Few 16,000\'\nBroken 22,000\'',
          valueColor: AppColors.vfr,
        ),
        _WeatherField(
          label: 'Temperature',
          value: '15°C (59°F)',
          valueColor: AppColors.primary,
        ),
        _WeatherField(
          label: 'Dewpoint',
          value: '-8°C (18°F)',
          valueColor: AppColors.primary,
        ),
        _WeatherField(
          label: 'Altimeter',
          value: '30.15 inHg',
          valueColor: AppColors.primary,
        ),
        _WeatherField(label: 'Humidity', value: '20%'),
        _WeatherField(
          label: 'Density Altitude',
          value: '6,777\'',
          valueColor: AppColors.primary,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _WeatherField extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _WeatherField({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  final String label;
  const _PlaceholderView({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
