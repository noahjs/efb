import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/approach_chart.dart';
import '../../../models/procedure.dart';
import '../../../services/api_client.dart';
import '../../../services/cifp_providers.dart';
import '../../../services/procedure_providers.dart';
import '../screens/procedure_pdf_screen.dart';

class AirportProcedureTab extends ConsumerWidget {
  final String airportId;
  const AirportProcedureTab({super.key, required this.airportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proceduresAsync = ref.watch(airportProceduresProvider(airportId));

    return proceduresAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text(
                'Failed to load procedures',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(airportProceduresProvider(airportId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (grouped) => _ProcedureTabView(
        airportId: airportId,
        grouped: grouped,
      ),
    );
  }
}

class _ProcedureTabView extends StatelessWidget {
  final String airportId;
  final Map<String, List<Procedure>> grouped;

  const _ProcedureTabView({
    required this.airportId,
    required this.grouped,
  });

  @override
  Widget build(BuildContext context) {
    // Group into tab categories
    final airport = <Procedure>[
      ...grouped['APD'] ?? [],
      ...grouped['HOT'] ?? [],
      ...grouped['LAH'] ?? [],
    ];
    final departure = grouped['DP'] ?? [];
    final arrival = grouped['STAR'] ?? [];
    final approach = grouped['IAP'] ?? [];
    final other = <Procedure>[
      ...grouped['MIN'] ?? [],
      // Include any chart codes not already categorized
      ...grouped.entries
          .where((e) => !{'APD', 'HOT', 'LAH', 'DP', 'STAR', 'IAP', 'MIN'}.contains(e.key))
          .expand((e) => e.value),
    ];

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
                _ProcedureList(airportId: airportId, items: airport),
                _ProcedureList(airportId: airportId, items: departure),
                _ProcedureList(airportId: airportId, items: arrival),
                _ApproachTabContent(airportId: airportId, govCharts: approach),
                _ProcedureList(airportId: airportId, items: other),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcedureList extends StatelessWidget {
  final String airportId;
  final List<Procedure> items;
  const _ProcedureList({required this.airportId, required this.items});

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
      itemBuilder: (context, index) => _ProcedureRow(
        airportId: airportId,
        procedure: items[index],
      ),
    );
  }
}

class _ProcedureRow extends ConsumerWidget {
  final String airportId;
  final Procedure procedure;

  const _ProcedureRow({
    required this.airportId,
    required this.procedure,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        final client = ref.read(apiClientProvider);
        final pdfUrl = client.getProcedurePdfUrl(airportId, procedure.id);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProcedurePdfScreen(
              title: procedure.chartName,
              pdfUrl: pdfUrl,
              airportId: airportId,
              chartCode: procedure.chartCode,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Source badge
            SizedBox(
              width: 32,
              child: Text(
                'GOV',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Procedure name
            Expanded(
              child: Text(
                procedure.chartName,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Chart code badge for non-obvious types
            if (procedure.copter != null && procedure.copter!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'COPTER',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Combined approach tab: CIFP data views above GOV PDF charts.
class _ApproachTabContent extends ConsumerWidget {
  final String airportId;
  final List<Procedure> govCharts;

  const _ApproachTabContent({
    required this.airportId,
    required this.govCharts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cifpAsync = ref.watch(approachListProvider(airportId));

    return cifpAsync.when(
      loading: () => _buildWithCifpSection(
        context,
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, _) => _buildWithCifpSection(context, null),
      data: (approaches) {
        // Filter to base approaches only (skip transitions)
        final base = approaches
            .where((a) =>
                a.transitionIdentifier == null ||
                a.transitionIdentifier!.isEmpty)
            .toList();

        if (base.isEmpty) {
          return _buildWithCifpSection(context, null);
        }

        return _buildWithCifpSection(
          context,
          Column(
            children: base
                .map((a) => _CifpApproachRow(
                      airportId: airportId,
                      approach: a,
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildWithCifpSection(BuildContext context, Widget? cifpContent) {
    return ListView(
      children: [
        // CIFP section
        if (cifpContent != null) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: const Text(
              'CIFP DATA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          cifpContent,
          const Divider(height: 24, thickness: 0.5),
        ],
        // GOV charts section header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: const Text(
            'GOV CHARTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (govCharts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No procedures available',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          )
        else
          ...govCharts.map((p) => _ProcedureRow(
                airportId: airportId,
                procedure: p,
              )),
      ],
    );
  }
}

class _CifpApproachRow extends StatelessWidget {
  final String airportId;
  final ApproachSummary approach;

  const _CifpApproachRow({
    required this.airportId,
    required this.approach,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.push('/airports/$airportId/approaches/${approach.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Source badge
            Container(
              width: 32,
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'CIFP',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Procedure name
            Expanded(
              child: Text(
                approach.procedureName,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Route type badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                approach.routeTypeName,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
