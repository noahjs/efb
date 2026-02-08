import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/scratchpad.dart';

class TemplatePicker extends StatelessWidget {
  final void Function(ScratchPadTemplate template) onSelected;

  const TemplatePicker({super.key, required this.onSelected});

  static Future<ScratchPadTemplate?> show(BuildContext context) {
    return showModalBottomSheet<ScratchPadTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => TemplatePicker(
        onSelected: (template) => Navigator.pop(context, template),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Choose A Template',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Template grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 16,
            children: [
              _TemplateOption(
                icon: Icons.edit,
                label: 'DRAW',
                onTap: () => onSelected(ScratchPadTemplate.draw),
              ),
              _TemplateOption(
                icon: Icons.text_fields,
                label: 'TYPE',
                onTap: () => onSelected(ScratchPadTemplate.type),
              ),
              _TemplateOption(
                icon: Icons.grid_on,
                label: 'GRID',
                onTap: () => onSelected(ScratchPadTemplate.grid),
              ),
              _TemplateOption(
                customIcon: _CraftIcon(),
                label: 'CRAFT',
                onTap: () => onSelected(ScratchPadTemplate.craft),
              ),
              _TemplateOption(
                icon: Icons.cloud_outlined,
                label: 'ATIS',
                onTap: () => onSelected(ScratchPadTemplate.atis),
              ),
              _TemplateOption(
                icon: Icons.chat_bubble_outline,
                label: 'PIREP',
                onTap: () => onSelected(ScratchPadTemplate.pirep),
              ),
              _TemplateOption(
                icon: Icons.flight_takeoff,
                label: 'TAKEOFF',
                onTap: () => onSelected(ScratchPadTemplate.takeoff),
              ),
              _TemplateOption(
                icon: Icons.flight_land,
                label: 'LANDING',
                onTap: () => onSelected(ScratchPadTemplate.landing),
              ),
              _TemplateOption(
                icon: Icons.sync,
                label: 'HOLDING',
                onTap: () => onSelected(ScratchPadTemplate.holding),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CraftIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textSecondary, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'CRAFT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TemplateOption extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final VoidCallback onTap;

  const _TemplateOption({
    this.icon,
    this.customIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (customIcon != null)
              SizedBox(height: 36, child: Center(child: customIcon!))
            else
              Icon(icon, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
