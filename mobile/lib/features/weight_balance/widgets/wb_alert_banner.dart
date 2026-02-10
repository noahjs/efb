import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/weight_balance.dart';

class WBAlertBanner extends StatelessWidget {
  final WBCalculationResult result;
  final WBProfile profile;

  const WBAlertBanner({
    super.key,
    required this.result,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final alerts = <String>[];

    if (!result.towCondition.withinLimits) {
      if (result.tow > profile.maxTakeoffWeight) {
        final excess = (result.tow - profile.maxTakeoffWeight).round();
        alerts.add('Takeoff weight exceeds MTOW by $excess lbs');
      } else {
        alerts.add('CG out of limits at takeoff weight');
      }
    }
    if (!result.ldwCondition.withinLimits) {
      if (result.ldw > profile.maxLandingWeight) {
        final excess = (result.ldw - profile.maxLandingWeight).round();
        alerts.add('Landing weight exceeds MLW by $excess lbs');
      } else {
        alerts.add('CG out of limits at landing weight');
      }
    }
    if (!result.zfwCondition.withinLimits) {
      if (profile.maxZeroFuelWeight != null &&
          result.zfw > profile.maxZeroFuelWeight!) {
        alerts.add('Zero fuel weight exceeds MZFW');
      } else {
        alerts.add('CG out of limits at zero fuel weight');
      }
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alerts.join('\n'),
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
