import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/connection_state.dart';
import '../providers/adsb_providers.dart';

/// Compact ADS-B connection status bar displayed on the map screen.
///
/// Shows receiver connection state, GPS fix quality, and traffic count.
/// Tap to navigate to the receiver settings screen.
/// Collapses to nothing when disconnected and no active scan.
class AdsbStatusBar extends ConsumerWidget {
  const AdsbStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(receiverStatusProvider);

    // Hide when fully disconnected (user hasn't initiated a connection)
    if (status.status == AdsbConnectionStatus.disconnected) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => context.push('/settings/receiver'),
      child: Container(
        decoration: BoxDecoration(
          color: _backgroundColor(status.status),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: AppColors.scrim,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusIcon(status.status),
            const SizedBox(width: 6),
            Text(
              _statusLabel(status),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (status.status == AdsbConnectionStatus.connected ||
                status.status == AdsbConnectionStatus.stale) ...[
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 14,
                color: AppColors.textMuted.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.gps_fixed,
                size: 14,
                color: status.gpsPositionValid
                    ? AppColors.success
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 14,
                color: AppColors.textMuted.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 10),
              Text(
                'TFC: ${status.trafficCount}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _backgroundColor(AdsbConnectionStatus status) {
    switch (status) {
      case AdsbConnectionStatus.connected:
        return AppColors.surface;
      case AdsbConnectionStatus.stale:
        return const Color(0xFF3D3520);
      case AdsbConnectionStatus.scanning:
      case AdsbConnectionStatus.connecting:
        return AppColors.surface;
      case AdsbConnectionStatus.disconnected:
        return AppColors.surface;
    }
  }

  Widget _statusIcon(AdsbConnectionStatus status) {
    switch (status) {
      case AdsbConnectionStatus.connected:
        return const Icon(Icons.sensors, size: 16, color: AppColors.success);
      case AdsbConnectionStatus.stale:
        return const Icon(Icons.sensors, size: 16, color: AppColors.warning);
      case AdsbConnectionStatus.scanning:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        );
      case AdsbConnectionStatus.connecting:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        );
      case AdsbConnectionStatus.disconnected:
        return const Icon(
            Icons.sensors_off, size: 16, color: AppColors.textMuted);
    }
  }

  String _statusLabel(AdsbStatus status) {
    switch (status.status) {
      case AdsbConnectionStatus.connected:
        return status.receiverName ?? 'ADS-B Connected';
      case AdsbConnectionStatus.stale:
        return 'Signal Lost';
      case AdsbConnectionStatus.scanning:
        return 'Scanning...';
      case AdsbConnectionStatus.connecting:
        return 'Connecting...';
      case AdsbConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }
}
