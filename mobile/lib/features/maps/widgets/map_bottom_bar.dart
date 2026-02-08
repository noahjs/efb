import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MapBottomBar extends StatelessWidget {
  const MapBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface.withValues(alpha: 0.95),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _InfoItem(label: 'Distance Next', value: '--- nm'),
            _InfoItem(label: 'ETE Dest', value: '---'),
            _InfoItem(label: 'Groundspeed', value: '--- kts'),
            _InfoItem(label: 'GPS Altitude', value: '---'),
            _InfoItem(label: 'Track', value: '---°'),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
