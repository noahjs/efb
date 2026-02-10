import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/weight_balance.dart';

class WBWeightSummaryBar extends StatelessWidget {
  final WBCalculationResult result;
  final WBProfile profile;

  const WBWeightSummaryBar({
    super.key,
    required this.result,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildCondition(
            'BEW',
            profile.emptyWeight,
            null,
            true,
          ),
          _buildCondition(
            'ZFW',
            result.zfw,
            profile.maxZeroFuelWeight,
            result.zfwCondition.withinLimits,
          ),
          _buildCondition(
            'TOW',
            result.tow,
            profile.maxTakeoffWeight,
            result.towCondition.withinLimits,
          ),
          _buildCondition(
            'LDW',
            result.ldw,
            profile.maxLandingWeight,
            result.ldwCondition.withinLimits,
          ),
        ],
      ),
    );
  }

  Widget _buildCondition(
      String label, double actual, double? limit, bool withinLimits) {
    final actualStr = actual.round().toString();
    final limitStr = limit != null ? '/ ${limit.round()}' : '';
    final valueColor = withinLimits ? AppColors.textPrimary : AppColors.error;

    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            actualStr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
          if (limit != null)
            Text(
              limitStr,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
