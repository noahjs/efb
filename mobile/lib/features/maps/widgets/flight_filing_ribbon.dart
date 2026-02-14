import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import '../../../services/api_client.dart';
import '../../../services/map_flight_provider.dart';

class FlightFilingRibbon extends ConsumerStatefulWidget {
  const FlightFilingRibbon({super.key});

  @override
  ConsumerState<FlightFilingRibbon> createState() =>
      _FlightFilingRibbonState();
}

class _FlightFilingRibbonState extends ConsumerState<FlightFilingRibbon> {
  bool _loading = false;

  Flight? get _flight => ref.watch(activeFlightProvider);
  String get _status => _flight?.filingStatus ?? 'not_filed';

  Color get _statusColor {
    switch (_status) {
      case 'filed':
        return AppColors.info;
      case 'accepted':
        return AppColors.success;
      case 'closed':
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'filed':
        return 'FILED';
      case 'accepted':
        return 'ACCEPTED';
      case 'closed':
        return 'CLOSED';
      default:
        return '';
    }
  }

  String? get _filedTimeZ {
    final filedAt = _flight?.filedAt;
    if (filedAt == null) return null;
    try {
      final dt = DateTime.parse(filedAt).toUtc();
      return '${dt.hour.toString().padLeft(2, '0')}'
          '${dt.minute.toString().padLeft(2, '0')}Z';
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshFlight() async {
    final id = _flight?.id;
    if (id == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final json = await api.getFlight(id);
      if (mounted) {
        ref.read(activeFlightProvider.notifier).set(Flight.fromJson(json));
      }
    } catch (_) {}
  }

  Future<void> _amendFlight() async {
    final confirmed = await _showConfirmDialog(
      'Amend Flight Plan',
      'Submit an amended flight plan to Leidos Flight Service?',
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.amendFlight(_flight!.id!);
      if (mounted) {
        final success = result['success'] as bool? ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Flight plan amended'
                  : result['message'] ?? 'Amendment failed',
            ),
          ),
        );
        await _refreshFlight();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Amendment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelFiling() async {
    final confirmed = await _showConfirmDialog(
      'Cancel Flight Plan',
      'Cancel the filed flight plan? This will notify ATC.',
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.cancelFiling(_flight!.id!);
      if (mounted) {
        final success = result['success'] as bool? ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Flight plan cancelled'
                  : result['message'] ?? 'Cancellation failed',
            ),
          ),
        );
        await _refreshFlight();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancellation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeFiling() async {
    final confirmed = await _showConfirmDialog(
      'Close Flight Plan',
      'Close/deactivate the flight plan after landing?',
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.closeFiling(_flight!.id!);
      if (mounted) {
        final success = result['success'] as bool? ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Flight plan closed'
                  : result['message'] ?? 'Close failed',
            ),
          ),
        );
        await _refreshFlight();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Close failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flight = _flight;
    if (flight == null ||
        flight.id == null ||
        _status == 'not_filed') {
      return const SizedBox.shrink();
    }

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: _statusColor, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: _loading
          ? const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Row(
              children: [
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Flight rules
                Text(
                  flight.flightRules,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                // Route summary
                Flexible(
                  child: Text(
                    '${flight.departureIdentifier ?? ''}'
                    ' \u2192 '
                    '${flight.destinationIdentifier ?? ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Filed time
                if (_filedTimeZ != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _filedTimeZ!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const Spacer(),
                // Action buttons
                ..._buildActions(),
              ],
            ),
    );
  }

  List<Widget> _buildActions() {
    switch (_status) {
      case 'filed':
        return [
          _RibbonButton(label: 'Amend', onTap: _amendFlight),
          const SizedBox(width: 6),
          _RibbonButton(
            label: 'Cancel',
            onTap: _cancelFiling,
            color: AppColors.warning,
          ),
        ];
      case 'accepted':
        return [
          _RibbonButton(
            label: 'Cancel',
            onTap: _cancelFiling,
            color: AppColors.warning,
          ),
          const SizedBox(width: 6),
          _RibbonButton(label: 'Close', onTap: _closeFiling),
        ];
      default:
        return [];
    }
  }
}

class _RibbonButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _RibbonButton({
    required this.label,
    required this.onTap,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
