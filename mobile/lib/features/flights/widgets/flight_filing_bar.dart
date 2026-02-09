import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import '../../../services/api_client.dart';
import 'filing_validation_sheet.dart';

class FlightFilingBar extends StatefulWidget {
  final Flight flight;
  final ApiClient api;
  final VoidCallback onFlightUpdated;

  const FlightFilingBar({
    super.key,
    required this.flight,
    required this.api,
    required this.onFlightUpdated,
  });

  @override
  State<FlightFilingBar> createState() => _FlightFilingBarState();
}

class _FlightFilingBarState extends State<FlightFilingBar> {
  bool _loading = false;

  String get _status => widget.flight.filingStatus;

  Future<void> _showValidationSheet() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api.validateFiling(widget.flight.id!);
      final checks = (result['checks'] as List)
          .map((c) => ValidationCheck.fromJson(c as Map<String, dynamic>))
          .toList();
      final ready = result['ready'] as bool;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _FilingSheetWrapper(
          checks: checks,
          ready: ready,
          api: widget.api,
          flightId: widget.flight.id!,
          onFlightUpdated: widget.onFlightUpdated,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Validation failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _amendFlight() async {
    final confirmed = await _showConfirmDialog(
      'Amend Flight Plan',
      'Submit an amended flight plan to Leidos Flight Service?',
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final result = await widget.api.amendFlight(widget.flight.id!);
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
        widget.onFlightUpdated();
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
      final result = await widget.api.cancelFiling(widget.flight.id!);
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
        widget.onFlightUpdated();
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
      final result = await widget.api.closeFiling(widget.flight.id!);
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
        widget.onFlightUpdated();
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
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    switch (_status) {
      case 'filed':
        return _buildFiledBar();
      case 'accepted':
        return _buildAcceptedBar();
      case 'closed':
        return _buildClosedBar();
      default:
        return _buildNotFiledBar();
    }
  }

  Widget _buildNotFiledBar() {
    return Row(
      children: [
        const _StatusBadge(label: 'Not Filed', color: AppColors.textMuted),
        const Spacer(),
        ElevatedButton(
          onPressed: _showValidationSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('File Flight Plan',
              style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildFiledBar() {
    return Row(
      children: [
        const _StatusBadge(label: 'Filed', color: AppColors.info),
        if (widget.flight.filingReference != null) ...[
          const SizedBox(width: 8),
          Text(
            widget.flight.filingReference!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const Spacer(),
        _SmallButton(label: 'Amend', onTap: _amendFlight),
        const SizedBox(width: 8),
        _SmallButton(
          label: 'Cancel',
          onTap: _cancelFiling,
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildAcceptedBar() {
    return Row(
      children: [
        const _StatusBadge(label: 'Accepted', color: AppColors.success),
        if (widget.flight.filingReference != null) ...[
          const SizedBox(width: 8),
          Text(
            widget.flight.filingReference!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const Spacer(),
        _SmallButton(
          label: 'Cancel',
          onTap: _cancelFiling,
          color: AppColors.warning,
        ),
        const SizedBox(width: 8),
        _SmallButton(label: 'Close', onTap: _closeFiling),
      ],
    );
  }

  Widget _buildClosedBar() {
    return const Row(
      children: [
        _StatusBadge(label: 'Closed', color: AppColors.textMuted),
        Spacer(),
        Text(
          'Flight plan closed',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _SmallButton({
    required this.label,
    required this.onTap,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// Stateful wrapper for the bottom sheet to handle filing action
class _FilingSheetWrapper extends StatefulWidget {
  final List<ValidationCheck> checks;
  final bool ready;
  final ApiClient api;
  final int flightId;
  final VoidCallback onFlightUpdated;

  const _FilingSheetWrapper({
    required this.checks,
    required this.ready,
    required this.api,
    required this.flightId,
    required this.onFlightUpdated,
  });

  @override
  State<_FilingSheetWrapper> createState() => _FilingSheetWrapperState();
}

class _FilingSheetWrapperState extends State<_FilingSheetWrapper> {
  bool _filing = false;

  Future<void> _file() async {
    setState(() => _filing = true);
    try {
      final result = await widget.api.fileFlight(widget.flightId);
      final success = result['success'] as bool? ?? false;
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Flight plan filed: ${result['filingReference'] ?? ''}'
                  : result['message'] ?? 'Filing failed',
            ),
          ),
        );
        widget.onFlightUpdated();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _filing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Filing failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilingValidationSheet(
      checks: widget.checks,
      ready: widget.ready,
      onFile: _file,
      filing: _filing,
    );
  }
}
