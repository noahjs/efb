import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/weight_balance.dart';

class FlightWBStationRow extends StatelessWidget {
  final WBStation station;
  final double weight;
  final String? occupantName;
  final bool isPerson;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<String?>? onOccupantNameChanged;
  final ValueChanged<bool>? onIsPersonChanged;
  final bool compact;

  const FlightWBStationRow({
    super.key,
    required this.station,
    required this.weight,
    this.occupantName,
    this.isPerson = false,
    required this.onWeightChanged,
    this.onOccupantNameChanged,
    this.onIsPersonChanged,
    this.compact = false,
  });

  bool get _isToggleable => station.category == 'other';
  bool get _isOn => weight > 0;
  bool get _isSeat => station.category == 'seat';

  IconData get _categoryIcon {
    if (_isSeat && !isPerson && weight > 0) return Icons.luggage;
    switch (station.category) {
      case 'seat':
        return Icons.airline_seat_recline_normal;
      case 'baggage':
        return Icons.luggage;
      case 'other':
        return Icons.build_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Color get _categoryColor {
    if (_isSeat) {
      return isPerson ? AppColors.info : AppColors.starred;
    }
    switch (station.category) {
      case 'baggage':
        return AppColors.starred;
      case 'other':
        return Colors.purple;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final hasWeight = weight > 0;
    return InkWell(
      onTap: _isToggleable ? null : () => _editWeight(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hasWeight
              ? _categoryColor.withValues(alpha: 0.10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasWeight
                ? _categoryColor.withValues(alpha: 0.3)
                : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_categoryIcon, size: 16, color: _categoryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    station.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: hasWeight
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (occupantName != null && occupantName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                occupantName!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            if (_isToggleable)
              SizedBox(
                height: 28,
                child: FittedBox(
                  child: Switch(
                    value: _isOn,
                    activeThumbColor: _categoryColor,
                    onChanged: (on) {
                      onWeightChanged(
                          on ? (station.defaultWeight ?? 0) : 0);
                    },
                  ),
                ),
              )
            else
              Text(
                hasWeight ? '${weight.toStringAsFixed(0)} lbs' : '-- lbs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: hasWeight ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              station.maxWeight != null
                  ? 'Max ${station.maxWeight!.toStringAsFixed(0)} lbs'
                  : '',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return InkWell(
      onTap: _isToggleable ? null : () => _editWeight(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Icon(_categoryIcon, size: 20, color: _categoryColor),
            const SizedBox(width: 12),

            // Station name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          station.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: weight > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (occupantName != null && occupantName!.isNotEmpty)
                        Text(
                          occupantName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Weight or toggle
            if (_isToggleable)
              Switch(
                value: _isOn,
                activeThumbColor: _categoryColor,
                onChanged: (on) {
                  onWeightChanged(
                      on ? (station.defaultWeight ?? 0) : 0);
                },
              )
            else ...[
              Text(
                weight > 0
                    ? '${weight.toStringAsFixed(0)} lbs'
                    : '--',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      weight > 0 ? AppColors.accent : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    final parts = <String>[];
    if (station.groupName != null && station.groupName!.isNotEmpty) {
      parts.add(station.groupName!);
    }
    parts.add('Arm ${station.arm.toStringAsFixed(1)} in');
    if (station.maxWeight != null) {
      parts.add('Max ${station.maxWeight!.toStringAsFixed(0)} lbs');
    }
    if (_isToggleable && station.defaultWeight != null) {
      parts.add('${station.defaultWeight!.toStringAsFixed(0)} lbs');
    }
    return parts.join(' | ');
  }

  Future<void> _editWeight(BuildContext context) async {
    final weightController = TextEditingController(
        text: weight > 0 ? weight.toStringAsFixed(0) : '');
    final nameController = TextEditingController(text: occupantName ?? '');
    var personFlag = isPerson;

    ({double weight, String? name, bool isPerson})? result;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => PopScope(
          onPopInvokedWithResult: (didPop, _) {
            result = (
              weight: double.tryParse(weightController.text) ?? 0,
              name: _isSeat ? nameController.text : null,
              isPerson: personFlag,
            );
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(station.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                    ),
                    TextButton(
                      onPressed: () {
                        weightController.clear();
                        nameController.clear();
                        personFlag = false;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done',
                          style: TextStyle(color: AppColors.accent)),
                    ),
                  ],
                ),
                if (station.maxWeight != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Max: ${station.maxWeight!.toStringAsFixed(0)} lbs',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                if (_isSeat) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => setModalState(() => personFlag = !personFlag),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            personFlag
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 22,
                            color: personFlag
                                ? AppColors.info
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Person',
                            style: TextStyle(
                              fontSize: 14,
                              color: personFlag
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            personFlag
                                ? Icons.person
                                : Icons.inventory_2_outlined,
                            size: 18,
                            color: personFlag
                                ? AppColors.info
                                : AppColors.starred,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            personFlag ? 'Occupant' : 'Cargo',
                            style: TextStyle(
                              fontSize: 12,
                              color: personFlag
                                  ? AppColors.info
                                  : AppColors.starred,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: weightController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Weight',
                    suffixText: 'lbs',
                  ),
                  onSubmitted: (_) {
                    if (!_isSeat || !personFlag) Navigator.pop(ctx);
                  },
                ),
                if (_isSeat && personFlag) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Name (optional)',
                    ),
                    onSubmitted: (_) => Navigator.pop(ctx),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      onWeightChanged(result!.weight);
      onIsPersonChanged?.call(result!.isPerson);
      if (_isSeat) {
        if (result!.isPerson) {
          onOccupantNameChanged?.call(
              result!.name!.isEmpty ? null : result!.name);
        } else {
          onOccupantNameChanged?.call(null);
        }
      }
    }
  }
}
