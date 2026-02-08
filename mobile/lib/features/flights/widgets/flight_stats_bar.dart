import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import '../../../services/api_client.dart';

class FlightStatsBar extends StatelessWidget {
  final Flight flight;
  final VoidCallback? onRecalculate;
  final ApiClient? apiClient;

  const FlightStatsBar({
    super.key,
    required this.flight,
    this.onRecalculate,
    this.apiClient,
  });

  String _formatDistance(double? nm) {
    if (nm == null) return '--';
    return '${nm.toStringAsFixed(0)} nm';
  }

  String _formatEte(int? minutes) {
    if (minutes == null) return '--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}m';
  }

  String _formatEta(String? eta) {
    if (eta == null) return '--';
    try {
      final dt = DateTime.parse(eta).toLocal();
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'pm' : 'am';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour12:$m$period';
    } catch (_) {
      return eta;
    }
  }

  String _formatFuel(double? gallons) {
    if (gallons == null) return '--';
    return '${gallons.toStringAsFixed(1)}g';
  }

  String _formatWind(double? kts) {
    if (kts == null) return '--';
    return '${kts.toStringAsFixed(0)}kts';
  }

  String _formatCalculatedAt(String? iso) {
    if (iso == null) return '--';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'pm' : 'am';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour12:$m$period';
    } catch (_) {
      return '--';
    }
  }

  void _showDebug(BuildContext context) {
    final flightId = flight.id;
    if (flightId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the flight first')),
      );
      return;
    }
    showCalculationDebugSheet(context, flightId, apiClient ?? ApiClient());
  }

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
              _StatItem(
                  label: 'Distance',
                  value: _formatDistance(flight.distanceNm)),
              _StatItem(label: 'ETE', value: _formatEte(flight.eteMinutes)),
              _StatItem(label: 'ETA', value: _formatEta(flight.eta)),
              _StatItem(
                  label: 'Flt Fuel',
                  value: _formatFuel(flight.flightFuelGallons)),
              _StatItem(
                  label: 'Wind', value: _formatWind(flight.windComponent)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Calculated ${_formatCalculatedAt(flight.calculatedAt)}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              if (onRecalculate != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRecalculate,
                  child: const Icon(Icons.refresh,
                      size: 14, color: AppColors.textMuted),
                ),
              ],
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showDebug(context),
                child: const Icon(Icons.bug_report,
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

/// Show the calculation debug bottom sheet for a given flight.
void showCalculationDebugSheet(
    BuildContext context, int flightId, ApiClient apiClient) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => _CalculationDebugSheet(
      flightId: flightId,
      apiClient: apiClient,
    ),
  );
}

class _CalculationDebugSheet extends StatefulWidget {
  final int flightId;
  final ApiClient apiClient;

  const _CalculationDebugSheet({
    required this.flightId,
    required this.apiClient,
  });

  @override
  State<_CalculationDebugSheet> createState() => _CalculationDebugSheetState();
}

class _CalculationDebugSheetState extends State<_CalculationDebugSheet> {
  List<Map<String, String>>? _steps;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await widget.apiClient.getFlightCalculationDebug(widget.flightId);
      final rawSteps = data['steps'] as List<dynamic>? ?? [];
      setState(() {
        _steps = rawSteps
            .map((s) => {
                  'label': (s['label'] ?? '') as String,
                  'value': (s['value'] ?? '') as String,
                })
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.bug_report,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Calculation Debug',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close,
                      size: 20, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.divider),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $_error',
                      style: const TextStyle(color: AppColors.error)),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _steps?.length ?? 0,
                itemBuilder: (ctx, i) {
                  final step = _steps![i];
                  final label = step['label'] ?? '';
                  final value = step['value'] ?? '';
                  final isIndented = label.startsWith('  ');
                  final isNotFound = value == 'NOT FOUND';
                  final isResult = label.startsWith('Total') ||
                      label.contains('Calculation') ||
                      label.startsWith('Fuel Calculation');

                  return Padding(
                    padding: EdgeInsets.only(
                      left: isIndented ? 16 : 0,
                      bottom: 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            label.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isResult
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isIndented
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: isResult
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isNotFound
                                  ? AppColors.error
                                  : isResult
                                      ? AppColors.accent
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
