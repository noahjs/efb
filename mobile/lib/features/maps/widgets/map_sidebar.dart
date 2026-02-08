import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MapSidebar extends StatefulWidget {
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onAeroSettingsTap;

  const MapSidebar({
    super.key,
    this.onZoomIn,
    this.onZoomOut,
    this.onAeroSettingsTap,
  });

  @override
  State<MapSidebar> createState() => _MapSidebarState();
}

class _MapSidebarState extends State<MapSidebar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      margin: const EdgeInsets.only(left: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aeronautical settings gear
          _SidebarButton(
            icon: Icons.settings,
            size: 18,
            onTap: () => widget.onAeroSettingsTap?.call(),
          ),
          const SizedBox(height: 12),

          // VFR label
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'VFR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Blue dot indicator
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 12),

          // Distance measurement
          _SidebarButton(
            icon: Icons.straighten,
            size: 18,
            onTap: () {},
          ),
          const SizedBox(height: 12),

          // Zoom controls
          _SidebarButton(
            icon: Icons.add,
            onTap: () => widget.onZoomIn?.call(),
          ),
          const SizedBox(height: 2),
          _SidebarButton(
            icon: Icons.remove,
            onTap: () => widget.onZoomOut?.call(),
          ),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool active;

  const _SidebarButton({
    required this.icon,
    required this.onTap,
    this.size = 20,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.accent.withValues(alpha: 0.85)
          : AppColors.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon,
              color: active ? Colors.white : Colors.white70, size: size),
        ),
      ),
    );
  }
}
