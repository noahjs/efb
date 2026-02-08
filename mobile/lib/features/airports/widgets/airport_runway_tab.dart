import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AirportRunwayTab extends StatelessWidget {
  final String airportId;
  const AirportRunwayTab({super.key, required this.airportId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'RUNWAYS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),

        // Runway 03-21
        _RunwayCard(
          runwayPair: '03 - 21',
          dimensions: '3,600\' x 75\'',
          surface: 'Fair asphalt',
          ends: [
            _RunwayEnd(
              name: 'Rwy 03',
              headwind: '9-12 kts',
              crosswind: '13-17 kts',
              headwindFavorable: true,
              crosswindFavorable: false,
            ),
            _RunwayEnd(
              name: 'Rwy 21',
              headwind: '9-12 kts',
              crosswind: '13-17 kts',
              headwindFavorable: true,
              crosswindFavorable: true,
              bestWind: true,
              trafficPattern: 'Right Traffic',
            ),
          ],
          onTap: () => _showRunwayDetail(context, '03-21'),
        ),

        // Runway 12L-30R
        _RunwayCard(
          runwayPair: '12L - 30R',
          dimensions: '9,000\' x 100\'',
          surface: 'Good asphalt',
          ends: [
            _RunwayEnd(
              name: 'Rwy 12L',
              headwind: '13-17 kts',
              crosswind: '9-12 kts',
              headwindFavorable: false,
              crosswindFavorable: true,
            ),
            _RunwayEnd(
              name: 'Rwy 30R',
              headwind: '13-17 kts',
              crosswind: '9-12 kts',
              headwindFavorable: true,
              crosswindFavorable: false,
              trafficPattern: 'Right Traffic',
            ),
          ],
          onTap: () => _showRunwayDetail(context, '12L-30R'),
        ),

        // Runway 12R-30L
        _RunwayCard(
          runwayPair: '12R - 30L',
          dimensions: '7,002\' x 75\'',
          surface: 'Good asphalt',
          ends: [
            _RunwayEnd(
              name: 'Rwy 12R',
              headwind: '13-17 kts',
              crosswind: '9-12 kts',
              headwindFavorable: false,
              crosswindFavorable: true,
              trafficPattern: 'Right Traffic',
            ),
            _RunwayEnd(
              name: 'Rwy 30L',
              headwind: '13-17 kts',
              crosswind: '9-12 kts',
              headwindFavorable: true,
              crosswindFavorable: false,
            ),
          ],
          onTap: () => _showRunwayDetail(context, '12R-30L'),
        ),

        const SizedBox(height: 12),

        // Wind info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Wind: 250° at 16 - 21 kts (8m ago)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showRunwayDetail(BuildContext context, String runway) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (context) => _RunwayDetailSheet(runway: runway),
    );
  }
}

class _RunwayCard extends StatelessWidget {
  final String runwayPair;
  final String dimensions;
  final String surface;
  final List<_RunwayEnd> ends;
  final VoidCallback onTap;

  const _RunwayCard({
    required this.runwayPair,
    required this.dimensions,
    required this.surface,
    required this.ends,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Runway pair info
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    runwayPair,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dimensions,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    surface,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Runway ends
            Expanded(
              child: Column(
                children: ends
                    .map((end) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: end,
                        ))
                    .toList(),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _RunwayEnd extends StatelessWidget {
  final String name;
  final String headwind;
  final String crosswind;
  final bool headwindFavorable;
  final bool crosswindFavorable;
  final bool bestWind;
  final String? trafficPattern;

  const _RunwayEnd({
    required this.name,
    required this.headwind,
    required this.crosswind,
    required this.headwindFavorable,
    required this.crosswindFavorable,
    this.bestWind = false,
    this.trafficPattern,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (bestWind) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Best Wind',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (trafficPattern != null)
          Text(
            trafficPattern!,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.error,
            ),
          ),
        Row(
          children: [
            Icon(
              Icons.arrow_forward,
              size: 12,
              color: headwindFavorable ? AppColors.vfr : AppColors.error,
            ),
            const SizedBox(width: 2),
            Text(
              headwind,
              style: TextStyle(
                fontSize: 12,
                color: headwindFavorable ? AppColors.vfr : AppColors.error,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_downward,
              size: 12,
              color: crosswindFavorable ? AppColors.vfr : AppColors.error,
            ),
            const SizedBox(width: 2),
            Text(
              crosswind,
              style: TextStyle(
                fontSize: 12,
                color: crosswindFavorable ? AppColors.vfr : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RunwayDetailSheet extends StatelessWidget {
  final String runway;
  const _RunwayDetailSheet({required this.runway});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.toolbarBackground,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('KBJC',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 14)),
                    ),
                    const Spacer(),
                    Text(
                      'Runway Details',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _DetailSection(title: 'RUNWAY DETAILS', items: [
                _DetailRow(label: 'Dimensions', value: '3,600\' x 75\''),
                _DetailRow(label: 'Surface', value: 'Asphalt, fair condition'),
                _DetailRow(label: 'Glideslope Ind.', value: '2-light PAPI (on left)'),
                _DetailRow(label: 'Slope', value: '0.44%'),
                _DetailRow(label: 'Heading', value: '205°M'),
                _DetailRow(label: 'Strength', value: '130/F/D/X/T'),
                _DetailRow(
                  label: 'Traffic Pattern',
                  value: 'Right traffic',
                  valueColor: AppColors.error,
                ),
              ]),
              _DetailSection(title: 'ELEVATION', items: [
                _DetailRow(label: 'Touchdown', value: '5,620\' MSL'),
              ]),
              _DetailSection(title: 'DECLARED DISTANCES', items: [
                _DetailRow(label: 'TORA', value: '3,600\''),
                _DetailRow(label: 'TODA', value: '3,600\''),
                _DetailRow(label: 'ASDA', value: '3,600\''),
                _DetailRow(label: 'LDA', value: '3,600\''),
              ]),
              _DetailSection(title: 'LIGHTING', items: [
                _DetailRow(label: 'Approach', value: 'None'),
                _DetailRow(label: 'Edge', value: 'Medium Intensity'),
              ]),
              _DetailSection(title: 'COORDINATES', items: [
                _DetailRow(label: '', value: '39.91°N/105.11°W'),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailRow> items;

  const _DetailSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
