import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../adsb/models/traffic_target.dart';
import '../providers/traffic_alert_provider.dart';

/// Alert banner displayed at the top of the map when traffic is nearby.
/// Red for < 1 nm, amber for < 2 nm. Auto-dismisses when threat clears.
class TrafficAlertBanner extends StatelessWidget {
  final TrafficAlert alert;

  const TrafficAlertBanner({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final isRed = alert.threat == ThreatLevel.resolution;
    final bgColor = isRed
        ? const Color(0xFFD32F2F) // red
        : const Color(0xFFF57C00); // amber

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.scrim,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              alert.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
