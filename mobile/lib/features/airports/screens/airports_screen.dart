import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class AirportsScreen extends StatefulWidget {
  const AirportsScreen({super.key});

  @override
  State<AirportsScreen> createState() => _AirportsScreenState();
}

class _AirportsScreenState extends State<AirportsScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  // Sample airports for prototype
  static const _sampleAirports = [
    _AirportListItem(
      id: 'KAPA',
      name: 'Centennial',
      city: 'Denver, CO',
      elevation: '5,885\'',
    ),
    _AirportListItem(
      id: 'KBJC',
      name: 'Rocky Mountain Metro',
      city: 'Denver, CO',
      elevation: '5,673\'',
    ),
    _AirportListItem(
      id: 'KDEN',
      name: 'Denver Intl',
      city: 'Denver, CO',
      elevation: '5,431\'',
    ),
    _AirportListItem(
      id: 'KFNL',
      name: 'Northern Colorado Regional',
      city: 'Fort Collins, CO',
      elevation: '5,016\'',
    ),
    _AirportListItem(
      id: 'KCFO',
      name: 'Colorado Springs / Peterson Field',
      city: 'Colorado Springs, CO',
      elevation: '6,187\'',
    ),
    _AirportListItem(
      id: 'KBDU',
      name: 'Boulder Municipal',
      city: 'Boulder, CO',
      elevation: '5,288\'',
    ),
    _AirportListItem(
      id: 'KEIK',
      name: 'Erie Municipal',
      city: 'Erie, CO',
      elevation: '5,130\'',
    ),
    _AirportListItem(
      id: 'KLMO',
      name: 'Vance Brand',
      city: 'Longmont, CO',
      elevation: '5,055\'',
    ),
  ];

  List<_AirportListItem> _filtered = _sampleAirports;

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _sampleAirports;
      } else {
        final q = query.toUpperCase();
        _filtered = _sampleAirports
            .where((a) =>
                a.id.contains(q) ||
                a.name.toUpperCase().contains(q) ||
                a.city.toUpperCase().contains(q))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search header
            Container(
              color: AppColors.toolbarBackground,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_border,
                          color: AppColors.textMuted, size: 24),
                      const SizedBox(width: 8),
                      const Icon(Icons.star,
                          color: Colors.amber, size: 24),
                      const Spacer(),
                      const Text(
                        'Airports',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.person_outline,
                          color: AppColors.textPrimary, size: 24),
                      const SizedBox(width: 12),
                      const Icon(Icons.my_location,
                          color: AppColors.textPrimary, size: 24),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Search bar
                  TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by identifier, name, or city',
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textMuted, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppColors.textMuted, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // Airport list
            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 0.5),
                itemBuilder: (context, index) {
                  final airport = _filtered[index];
                  return ListTile(
                    onTap: () => context.push('/airports/${airport.id}'),
                    leading: Container(
                      width: 56,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.divider, width: 0.5),
                      ),
                      child: const Icon(Icons.flight_takeoff,
                          color: AppColors.textMuted, size: 18),
                    ),
                    title: Row(
                      children: [
                        Text(
                          airport.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            airport.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          airport.city,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Elev: ${airport.elevation}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: AppColors.textMuted),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AirportListItem {
  final String id;
  final String name;
  final String city;
  final String elevation;

  const _AirportListItem({
    required this.id,
    required this.name,
    required this.city,
    required this.elevation,
  });
}
