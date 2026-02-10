import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/weight_balance.dart';

/// Debug panel that shows all intermediate W&B calculation values
/// so the user can compare step-by-step with another W&B app.
class WBDebugPanel extends StatelessWidget {
  final WBProfile profile;
  final Map<int, double> stationWeights;
  final double startingFuelGallons;
  final double endingFuelGallons;
  final double fuelWeightPerGallon;
  final WBCalculationResult? result;

  const WBDebugPanel({
    super.key,
    required this.profile,
    required this.stationWeights,
    required this.startingFuelGallons,
    required this.endingFuelGallons,
    required this.fuelWeightPerGallon,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    // Recompute all intermediate values for debug display
    final bewWeight = profile.emptyWeight;
    final bewArm = profile.emptyWeightArm;
    final bewMoment = bewWeight * bewArm;

    // Payload stations
    final payloadStations =
        profile.stations.where((s) => s.category != 'fuel').toList();
    final fuelStations =
        profile.stations.where((s) => s.category == 'fuel').toList();

    double payloadWeight = 0;
    double payloadMoment = 0;
    for (final s in payloadStations) {
      final w = stationWeights[s.id] ?? 0;
      if (w > 0) {
        payloadWeight += w;
        payloadMoment += w * s.arm;
      }
    }

    final zfw = bewWeight + payloadWeight;
    final zfwMoment = bewMoment + payloadMoment;
    final zfwCg = zfw > 0 ? zfwMoment / zfw : 0.0;

    // Fuel computation details
    final totalMaxWeight =
        fuelStations.fold(0.0, (sum, s) => sum + (s.maxWeight ?? 0));

    List<double> proportions = [];
    if (fuelStations.isNotEmpty) {
      if (totalMaxWeight > 0) {
        proportions =
            fuelStations.map((s) => (s.maxWeight ?? 0) / totalMaxWeight).toList();
      } else {
        final even = 1.0 / fuelStations.length;
        proportions = List.filled(fuelStations.length, even);
      }
    }

    String fuelSource;
    double? effectiveFuelArm;
    if (fuelStations.isNotEmpty) {
      fuelSource = '${fuelStations.length} fuel station(s)';
      // Weighted average arm for display
      if (proportions.isNotEmpty) {
        effectiveFuelArm = 0;
        for (int i = 0; i < fuelStations.length; i++) {
          effectiveFuelArm =
              effectiveFuelArm! + fuelStations[i].arm * proportions[i];
        }
      }
    } else if (profile.fuelArm != null) {
      fuelSource = 'Profile fuel_arm';
      effectiveFuelArm = profile.fuelArm;
    } else {
      fuelSource = 'NONE (no fuel stations, no fuel_arm)';
      effectiveFuelArm = null;
    }

    // Fuel moments
    final startFuelWeight = startingFuelGallons * fuelWeightPerGallon;
    final startFuelMoment =
        effectiveFuelArm != null ? startFuelWeight * effectiveFuelArm : 0.0;

    final taxiGallons = profile.taxiFuelGallons;
    final taxiFuelWeight = taxiGallons * fuelWeightPerGallon;
    final taxiFuelMoment =
        effectiveFuelArm != null ? taxiFuelWeight * effectiveFuelArm : 0.0;

    final endFuelWeight = endingFuelGallons * fuelWeightPerGallon;
    final endFuelMoment =
        effectiveFuelArm != null ? endFuelWeight * effectiveFuelArm : 0.0;

    final rampWeight = zfw + startFuelWeight;
    final rampMoment = zfwMoment + startFuelMoment;
    final rampCg = rampWeight > 0 ? rampMoment / rampWeight : 0.0;

    final tow = rampWeight - taxiFuelWeight;
    final towMoment = rampMoment - taxiFuelMoment;
    final towCg = tow > 0 ? towMoment / tow : 0.0;

    final ldw = zfw + endFuelWeight;
    final ldwMoment = zfwMoment + endFuelMoment;
    final ldwCg = ldw > 0 ? ldwMoment / ldw : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.bug_report, size: 16, color: Colors.orange),
                SizedBox(width: 6),
                Text('Calculation Debug',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    )),
              ],
            ),
          ),

          // --- BEW ---
          _sectionHeader('1. Basic Empty Weight (BEW)'),
          _row('Weight', '${bewWeight.toStringAsFixed(1)} lbs'),
          _row('Arm', '${bewArm.toStringAsFixed(2)} in'),
          _row('Moment', '${bewMoment.toStringAsFixed(1)} in-lbs'),

          // --- Payload Stations ---
          _sectionHeader('2. Payload Stations'),
          for (final s in payloadStations)
            _stationRow(s, stationWeights[s.id] ?? 0),
          _divider(),
          _row('Payload Total',
              '${payloadWeight.toStringAsFixed(1)} lbs / ${payloadMoment.toStringAsFixed(1)} in-lbs'),

          // --- ZFW ---
          _sectionHeader('3. Zero Fuel Weight (ZFW)'),
          _row('ZFW', '${zfw.toStringAsFixed(1)} lbs'),
          _row('ZFW Moment', '${zfwMoment.toStringAsFixed(1)} in-lbs'),
          _row('ZFW CG', '${zfwCg.toStringAsFixed(2)} in'),
          if (profile.maxZeroFuelWeight != null)
            _row('Max ZFW', '${profile.maxZeroFuelWeight!.toStringAsFixed(1)} lbs'),

          // --- Fuel Source ---
          _sectionHeader('4. Fuel Configuration'),
          _row('Source', fuelSource),
          _row('Effective Fuel Arm',
              effectiveFuelArm != null
                  ? '${effectiveFuelArm.toStringAsFixed(2)} in'
                  : 'N/A'),
          _row('Fuel Wt/Gal', '${fuelWeightPerGallon.toStringAsFixed(2)} lbs/gal'),
          if (fuelStations.isNotEmpty) ...[
            _divider(),
            _row('Fuel Stations:', ''),
            for (int i = 0; i < fuelStations.length; i++)
              _row(
                '  ${fuelStations[i].name}',
                'arm=${fuelStations[i].arm.toStringAsFixed(2)}, '
                    'max=${fuelStations[i].maxWeight?.toStringAsFixed(0) ?? "?"}, '
                    'prop=${(proportions[i] * 100).toStringAsFixed(0)}%',
              ),
          ],

          // --- Starting Fuel / Ramp ---
          _sectionHeader('5. Ramp Weight (ZFW + Starting Fuel)'),
          _row('Starting Fuel', '${startingFuelGallons.toStringAsFixed(1)} gal'),
          _row('Starting Fuel Wt', '${startFuelWeight.toStringAsFixed(1)} lbs'),
          _row('Starting Fuel Moment', '${startFuelMoment.toStringAsFixed(1)} in-lbs'),
          _divider(),
          _row('Ramp Weight', '${rampWeight.toStringAsFixed(1)} lbs'),
          _row('Ramp Moment', '${rampMoment.toStringAsFixed(1)} in-lbs'),
          _row('Ramp CG', '${rampCg.toStringAsFixed(2)} in'),
          if (profile.maxRampWeight != null)
            _row('Max Ramp', '${profile.maxRampWeight!.toStringAsFixed(1)} lbs'),

          // --- Taxi / TOW ---
          _sectionHeader('6. Takeoff Weight (Ramp - Taxi Fuel)'),
          _row('Taxi Fuel', '${taxiGallons.toStringAsFixed(1)} gal'),
          _row('Taxi Fuel Wt', '${taxiFuelWeight.toStringAsFixed(1)} lbs'),
          _row('Taxi Fuel Moment', '${taxiFuelMoment.toStringAsFixed(1)} in-lbs'),
          _divider(),
          _row('TOW', '${tow.toStringAsFixed(1)} lbs'),
          _row('TOW Moment', '${towMoment.toStringAsFixed(1)} in-lbs'),
          _row('TOW CG', '${towCg.toStringAsFixed(2)} in'),
          _row('Max TOW', '${profile.maxTakeoffWeight.toStringAsFixed(1)} lbs'),

          // --- LDW ---
          _sectionHeader('7. Landing Weight (ZFW + Ending Fuel)'),
          _row('Ending Fuel', '${endingFuelGallons.toStringAsFixed(1)} gal'),
          _row('Ending Fuel Wt', '${endFuelWeight.toStringAsFixed(1)} lbs'),
          _row('Ending Fuel Moment', '${endFuelMoment.toStringAsFixed(1)} in-lbs'),
          _divider(),
          _row('LDW', '${ldw.toStringAsFixed(1)} lbs'),
          _row('LDW Moment', '${ldwMoment.toStringAsFixed(1)} in-lbs'),
          _row('LDW CG', '${ldwCg.toStringAsFixed(2)} in'),
          _row('Max LDW', '${profile.maxLandingWeight.toStringAsFixed(1)} lbs'),

          // --- Calculator Result Comparison ---
          if (result != null) ...[
            _sectionHeader('8. Calculator Output (for comparison)'),
            _row('ZFW', '${result!.zfw} lbs @ ${result!.zfwCg} in'),
            _row('Ramp', '${result!.rampWeight} lbs @ ${result!.rampCg} in'),
            _row('TOW', '${result!.tow} lbs @ ${result!.towCg} in'),
            _row('LDW', '${result!.ldw} lbs @ ${result!.ldwCg} in'),
            _row('In Envelope', result!.isWithinEnvelope ? 'YES' : 'NO'),
          ],

          // --- Envelope Info ---
          _sectionHeader('9. Envelope Data'),
          _row('Envelopes', '${profile.envelopes.length} defined'),
          for (final env in profile.envelopes) ...[
            _row('  ${env.envelopeType} (${env.axis})',
                '${env.points.length} points'),
            for (final pt in env.points)
              _row('', '  CG=${pt.cg.toStringAsFixed(2)}, Wt=${pt.weight.toStringAsFixed(0)}'),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.surfaceLight,
      child: Text(title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          )),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _stationRow(WBStation station, double weight) {
    final moment = weight * station.arm;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '${station.name} [${station.category}]',
              style: TextStyle(
                fontSize: 11,
                color: weight > 0 ? AppColors.textSecondary : AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              weight > 0
                  ? '${weight.toStringAsFixed(1)} lbs x ${station.arm.toStringAsFixed(2)} in = ${moment.toStringAsFixed(1)}'
                  : '(empty)',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: weight > 0 ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 4, indent: 12, endIndent: 12, color: AppColors.divider);
  }
}
