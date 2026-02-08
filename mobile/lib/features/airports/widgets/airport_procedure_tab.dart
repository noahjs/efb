import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AirportProcedureTab extends StatelessWidget {
  final String airportId;
  const AirportProcedureTab({super.key, required this.airportId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'Airport'),
                Tab(text: 'Departure'),
                Tab(text: 'Arrival'),
                Tab(text: 'Approach'),
                Tab(text: 'Other'),
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
                _ProcedureList(items: _airportProcedures),
                _ProcedureList(items: _departureProcedures),
                _ProcedureList(items: _arrivalProcedures),
                _ProcedureList(items: _approachProcedures),
                _ProcedureList(items: _otherProcedures),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final _airportProcedures = [
  _ProcedureItem(
    source: 'GOV',
    saved: true,
    name: 'AIRPORT DIAGRAM',
    hasMap: true,
  ),
  _ProcedureItem(
    source: 'GOV',
    saved: true,
    name: 'ARRIVAL ALERT',
    hasMap: false,
  ),
  _ProcedureItem(
    source: 'GOV',
    saved: false,
    name: 'TAKEOFF MINIMUMS',
    hasMap: false,
  ),
];

final _departureProcedures = [
  _ProcedureItem(
    source: 'GOV',
    saved: true,
    name: 'ODP TAKEOFF OBSTACLE NOTES',
    hasMap: false,
  ),
];

final _arrivalProcedures = [
  _ProcedureItem(
    source: 'GOV',
    saved: false,
    name: 'COLORADO MOUNTAIN FLYING & ARRIVALS',
    hasMap: true,
  ),
];

final _approachProcedures = [
  _ProcedureItem(
    source: 'GOV',
    saved: true,
    name: 'ILS OR LOC RWY 30R',
    hasMap: true,
  ),
  _ProcedureItem(
    source: 'GOV',
    saved: true,
    name: 'RNAV (GPS) RWY 30R',
    hasMap: true,
  ),
  _ProcedureItem(
    source: 'GOV',
    saved: false,
    name: 'RNAV (GPS) RWY 12L',
    hasMap: true,
  ),
  _ProcedureItem(
    source: 'GOV',
    saved: false,
    name: 'VOR-A',
    hasMap: true,
  ),
];

final _otherProcedures = [
  _ProcedureItem(
    source: 'GOV',
    saved: false,
    name: 'ALTERNATE MINIMUMS',
    hasMap: false,
  ),
];

class _ProcedureList extends StatelessWidget {
  final List<_ProcedureItem> items;
  const _ProcedureList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No procedures available',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _ProcedureItem extends StatelessWidget {
  final String source;
  final bool saved;
  final String name;
  final bool hasMap;

  const _ProcedureItem({
    required this.source,
    required this.saved,
    required this.name,
    required this.hasMap,
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
        children: [
          // Source badge
          Column(
            children: [
              Text(
                source,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              if (saved)
                const Text(
                  'SAVED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Procedure name
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Actions
          if (hasMap) ...[
            IconButton(
              icon: const Icon(Icons.ios_share, size: 18),
              color: AppColors.textMuted,
              onPressed: () {},
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Map',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
