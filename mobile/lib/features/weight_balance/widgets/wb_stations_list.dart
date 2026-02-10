import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/weight_balance.dart';
import '../../flights/widgets/flight_section_header.dart';

class WBStationsList extends StatelessWidget {
  final WBProfile profile;
  final Map<int, double> stationWeights;
  final bool hideFuelStations;
  final ValueChanged<({int stationId, double weight})> onWeightChanged;

  const WBStationsList({
    super.key,
    required this.profile,
    required this.stationWeights,
    this.hideFuelStations = false,
    required this.onWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final stations = profile.stations;
    final seatStations =
        stations.where((s) => s.category == 'seat').toList();
    final baggageStations =
        stations.where((s) => s.category == 'baggage').toList();
    final fuelStations =
        stations.where((s) => s.category == 'fuel').toList();
    final otherStations =
        stations.where((s) => s.category == 'other').toList();

    return Column(
      children: [
        if (seatStations.isNotEmpty) ...[
          const FlightSectionHeader(title: 'Seats (lbs)'),
          ...seatStations.map((s) => _StationRow(
                station: s,
                weight: stationWeights[s.id] ?? s.defaultWeight ?? 0,
                showLateral: profile.lateralCgEnabled,
                onWeightChanged: (w) =>
                    onWeightChanged((stationId: s.id!, weight: w)),
              )),
        ],
        if (baggageStations.isNotEmpty) ...[
          const FlightSectionHeader(title: 'Baggage (lbs)'),
          ...baggageStations.map((s) => _StationRow(
                station: s,
                weight: stationWeights[s.id] ?? s.defaultWeight ?? 0,
                showLateral: profile.lateralCgEnabled,
                onWeightChanged: (w) =>
                    onWeightChanged((stationId: s.id!, weight: w)),
              )),
        ],
        if (fuelStations.isNotEmpty && !hideFuelStations) ...[
          const FlightSectionHeader(title: 'Fuel (lbs)'),
          ...fuelStations.map((s) => _StationRow(
                station: s,
                weight: stationWeights[s.id] ?? s.defaultWeight ?? 0,
                showLateral: profile.lateralCgEnabled,
                onWeightChanged: (w) =>
                    onWeightChanged((stationId: s.id!, weight: w)),
              )),
        ],
        if (otherStations.isNotEmpty) ...[
          const FlightSectionHeader(title: 'Other (lbs)'),
          ...otherStations.map((s) => _StationRow(
                station: s,
                weight: stationWeights[s.id] ?? s.defaultWeight ?? 0,
                showLateral: profile.lateralCgEnabled,
                onWeightChanged: (w) =>
                    onWeightChanged((stationId: s.id!, weight: w)),
              )),
        ],
      ],
    );
  }
}

class _StationRow extends StatelessWidget {
  final WBStation station;
  final double weight;
  final bool showLateral;
  final ValueChanged<double> onWeightChanged;

  const _StationRow({
    required this.station,
    required this.weight,
    required this.showLateral,
    required this.onWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    String armInfo = '${station.arm} in';
    if (showLateral && station.lateralArm != null) {
      final latDir = station.lateralArm! >= 0 ? 'R' : 'L';
      armInfo += ', $latDir ${station.lateralArm!.abs()} in';
    }
    final subtitle = station.groupName != null
        ? '${station.groupName} ($armInfo)'
        : armInfo;

    return InkWell(
      onTap: () => _editWeight(context),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              weight > 0 ? weight.round().toString() : '0',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: weight > 0 ? AppColors.accent : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _editWeight(BuildContext context) async {
    final controller =
        TextEditingController(text: weight > 0 ? weight.round().toString() : '');

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(station.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                TextButton(
                  onPressed: () {
                    final val =
                        double.tryParse(controller.text) ?? 0;
                    Navigator.pop(ctx, val);
                  },
                  child: const Text('Done',
                      style: TextStyle(color: AppColors.accent)),
                ),
              ],
            ),
            if (station.maxWeight != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Max: ${station.maxWeight!.round()} lbs',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Weight (lbs)',
                suffixText: 'lbs',
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx, double.tryParse(val) ?? 0);
              },
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      onWeightChanged(result);
    }
  }
}
