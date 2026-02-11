import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class FlightQuickActions extends StatelessWidget {
  final int? flightId;

  const FlightQuickActions({super.key, this.flightId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _ActionButton(
            label: 'Navlog',
            icon: Icons.list_alt,
            onTap: () => _showStub(context, 'Navlog'),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: 'Briefing',
            icon: Icons.description_outlined,
            onTap: flightId != null
                ? () => context.push('/flights/$flightId/briefing')
                : () => _showStub(context, 'Briefing'),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: 'Files',
            icon: Icons.folder_outlined,
            onTap: () => _showStub(context, 'Files'),
          ),
        ],
      ),
    );
  }

  void _showStub(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming in a future update'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}
