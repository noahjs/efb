import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/airport_info_tab.dart';
import '../widgets/airport_weather_tab.dart';
import '../widgets/airport_runway_tab.dart';
import '../widgets/airport_procedure_tab.dart';
import '../widgets/airport_notam_tab.dart';

class AirportDetailScreen extends StatelessWidget {
  final String airportId;

  const AirportDetailScreen({super.key, required this.airportId});

  // Mock airport data lookup
  Map<String, String> get _airportData {
    final airports = {
      'KBJC': {
        'name': 'Rocky Mountain Metro',
        'city': 'Denver, Colorado, US',
        'elevation': '5,673\'',
        'sunrise': '7:01 AM',
        'sunset': '5:27 PM MST',
      },
      'KAPA': {
        'name': 'Centennial',
        'city': 'Denver, Colorado, US',
        'elevation': '5,885\'',
        'sunrise': '7:01 AM',
        'sunset': '5:27 PM MST',
      },
      'KDEN': {
        'name': 'Denver International',
        'city': 'Denver, Colorado, US',
        'elevation': '5,431\'',
        'sunrise': '7:01 AM',
        'sunset': '5:27 PM MST',
      },
    };
    return airports[airportId] ??
        {
          'name': airportId,
          'city': 'Unknown',
          'elevation': '---',
          'sunrise': '---',
          'sunset': '---',
        };
  }

  @override
  Widget build(BuildContext context) {
    final data = _airportData;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(airportId),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: () {},
            ),
          ],
        ),
        body: Column(
          children: [
            // Airport header
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Airport diagram thumbnail
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.divider, width: 0.5),
                        ),
                        child: const Icon(Icons.map_outlined,
                            color: AppColors.textMuted, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['name']!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${data['city']}\nElevation: ${data['elevation']}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.wb_sunny_outlined,
                                    size: 14,
                                    color: Colors.amber.shade300),
                                const SizedBox(width: 4),
                                Text(
                                  '${data['sunrise']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.nightlight_outlined,
                                    size: 14,
                                    color: Colors.blue.shade300),
                                const SizedBox(width: 4),
                                Text(
                                  '${data['sunset']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    size: 16,
                                    color: AppColors.textMuted),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Quick action buttons
                  Row(
                    children: [
                      _QuickAction(label: '3D View', onTap: () {}),
                      const SizedBox(width: 8),
                      _QuickAction(label: 'Taxiways', onTap: () {}),
                      const SizedBox(width: 8),
                      _QuickAction(label: 'FBOs', onTap: () {}),
                      const SizedBox(width: 8),
                      _QuickAction(label: 'Comments', onTap: () {}),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              color: AppColors.surface,
              child: const TabBar(
                tabs: [
                  Tab(text: 'Info'),
                  Tab(text: 'Weather'),
                  Tab(text: 'Runway'),
                  Tab(text: 'Procedure'),
                  Tab(text: 'NOTAM'),
                ],
                isScrollable: false,
                labelStyle: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: TextStyle(fontSize: 13),
                indicatorSize: TabBarIndicatorSize.tab,
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  AirportInfoTab(airportId: airportId),
                  AirportWeatherTab(airportId: airportId),
                  AirportRunwayTab(airportId: airportId),
                  AirportProcedureTab(airportId: airportId),
                  AirportNotamTab(airportId: airportId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
