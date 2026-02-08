import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class FlightStatsBar extends StatelessWidget {
  const FlightStatsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: 'Distance', value: '--'),
              _StatItem(label: 'ETE', value: '--'),
              _StatItem(label: 'ETA', value: '--'),
              _StatItem(label: 'Flt Fuel', value: '--'),
              _StatItem(label: 'Wind', value: '--'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Calculated --',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {},
                child: const Icon(Icons.refresh,
                    size: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
