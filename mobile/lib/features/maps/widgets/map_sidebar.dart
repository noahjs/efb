import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MapSidebar extends StatefulWidget {
  const MapSidebar({super.key});

  @override
  State<MapSidebar> createState() => _MapSidebarState();
}

class _MapSidebarState extends State<MapSidebar> {
  bool _isRecording = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      margin: const EdgeInsets.only(left: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Map orientation toggle
          _SidebarButton(
            icon: Icons.explore,
            onTap: () {},
          ),
          const SizedBox(height: 2),

          // Declutter control
          _SidebarButton(
            icon: Icons.tune,
            onTap: () {},
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

          // Edit / Pencil tool
          _SidebarButton(
            icon: Icons.edit,
            size: 18,
            onTap: () {},
          ),
          const SizedBox(height: 2),

          // Waypoint pin
          _SidebarButton(
            icon: Icons.location_on_outlined,
            onTap: () {},
          ),
          const SizedBox(height: 12),

          // REC button
          GestureDetector(
            onTap: () => setState(() => _isRecording = !_isRecording),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                color: _isRecording
                    ? AppColors.error.withValues(alpha: 0.8)
                    : AppColors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'REC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _isRecording ? '01:23' : '00:00',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
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
            onTap: () {},
          ),
          const SizedBox(height: 2),
          _SidebarButton(
            icon: Icons.remove,
            onTap: () {},
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

  const _SidebarButton({
    required this.icon,
    required this.onTap,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}
