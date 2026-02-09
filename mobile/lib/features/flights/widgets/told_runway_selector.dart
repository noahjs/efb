import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/told_calculator.dart';
import '../../../services/told_providers.dart';

class ToldRunwaySelector extends StatelessWidget {
  final Map<String, dynamic> airportData;
  final ToldState toldState;
  final ToldStateNotifier notifier;
  final ToldMode mode;

  const ToldRunwaySelector({
    super.key,
    required this.airportData,
    required this.toldState,
    required this.notifier,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final runways = (airportData['runways'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    if (runways.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No runways available',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final windDir = toldState.windDir ?? 0;
    final windSpd = toldState.windSpeed ?? 0;

    // Find best-wind runway end
    double bestHeadwind = double.negativeInfinity;
    String? bestEndId;

    final allEnds = <_RunwayEndInfo>[];
    for (final rwy in runways) {
      final ends =
          (rwy['ends'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      for (final end in ends) {
        final heading = (end['heading'] as num?)?.toDouble();
        if (heading == null) continue;
        final hw = ToldCalculator.headwindComponent(windDir, windSpd, heading);
        final xw = ToldCalculator.crosswindComponent(windDir, windSpd, heading);
        final length = mode == ToldMode.takeoff
            ? (end['tora'] as num?)?.toDouble() ??
                (rwy['length'] as num?)?.toDouble()
            : (end['lda'] as num?)?.toDouble() ??
                (rwy['length'] as num?)?.toDouble();

        allEnds.add(_RunwayEndInfo(
          end: end,
          runway: rwy,
          headwind: hw,
          crosswind: xw,
          length: length,
        ));

        if (hw > bestHeadwind) {
          bestHeadwind = hw;
          bestEndId = end['identifier'] as String?;
        }
      }
    }

    // Sort by headwind (best first)
    allEnds.sort((a, b) => b.headwind.compareTo(a.headwind));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Select Runway',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: allEnds.length,
                  itemBuilder: (context, index) {
                    final info = allEnds[index];
                    final endId =
                        info.end['identifier'] as String? ?? '';
                    final isSelected =
                        endId == toldState.runwayEndIdentifier;
                    final isBest = endId == bestEndId;

                    return _RunwayEndTile(
                      info: info,
                      isSelected: isSelected,
                      isBestWind: isBest,
                      mode: mode,
                      onTap: () {
                        notifier.selectRunwayEnd(info.end, info.runway);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RunwayEndInfo {
  final Map<String, dynamic> end;
  final Map<String, dynamic> runway;
  final double headwind;
  final double crosswind;
  final double? length;

  const _RunwayEndInfo({
    required this.end,
    required this.runway,
    required this.headwind,
    required this.crosswind,
    this.length,
  });
}

class _RunwayEndTile extends StatelessWidget {
  final _RunwayEndInfo info;
  final bool isSelected;
  final bool isBestWind;
  final ToldMode mode;
  final VoidCallback onTap;

  const _RunwayEndTile({
    required this.info,
    required this.isSelected,
    required this.isBestWind,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final identifier = info.end['identifier'] as String? ?? '';
    final length = info.length;
    final isHeadwind = info.headwind >= 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : null,
          border: const Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                'Rwy $identifier',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (isBestWind) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Best',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Spacer(),
            // Wind components
            Icon(
              Icons.arrow_forward,
              size: 12,
              color: isHeadwind ? AppColors.vfr : AppColors.error,
            ),
            const SizedBox(width: 2),
            Text(
              '${info.headwind.abs().round()} kt',
              style: TextStyle(
                fontSize: 12,
                color: isHeadwind ? AppColors.vfr : AppColors.error,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_downward, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 2),
            Text(
              '${info.crosswind.round()} kt',
              style: TextStyle(
                fontSize: 12,
                color: info.crosswind <= 15
                    ? AppColors.textSecondary
                    : AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            // Length
            Text(
              length != null
                  ? '${mode == ToldMode.takeoff ? 'TORA' : 'LDA'}: ${_fmtNum(length.round())}\''
                  : '--',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtNum(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]},',
        );
  }
}
