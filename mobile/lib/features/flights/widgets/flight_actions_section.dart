import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'flight_section_header.dart';

class FlightActionsSection extends StatelessWidget {
  final bool isNewFlight;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onAddNext;
  final VoidCallback? onLogToLogbook;

  const FlightActionsSection({
    super.key,
    required this.isNewFlight,
    required this.onCopy,
    required this.onDelete,
    required this.onAddNext,
    this.onLogToLogbook,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Actions'),
        _ActionTile(
          label: 'Pack',
          icon: Icons.inventory_2_outlined,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pack coming in a future update'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        _ActionTile(
          label: 'Add Next Flight',
          icon: Icons.add_circle_outline,
          onTap: onAddNext,
        ),
        if (!isNewFlight && onLogToLogbook != null)
          _ActionTile(
            label: 'Log to Logbook',
            icon: Icons.book_outlined,
            onTap: onLogToLogbook!,
          ),
        if (!isNewFlight) ...[
          _ActionTile(
            label: 'Copy Flight',
            icon: Icons.copy,
            onTap: onCopy,
          ),
          _ActionTile(
            label: 'Delete Flight',
            icon: Icons.delete_outline,
            color: AppColors.error,
            onTap: () => _confirmDelete(context),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Flight'),
        content: const Text('Are you sure you want to delete this flight?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, color: c)),
          ],
        ),
      ),
    );
  }
}
