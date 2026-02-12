import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/follow_mode_provider.dart';

class MapSidebar extends StatefulWidget {
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onAeroSettingsTap;
  final VoidCallback? onTrafficSettingsTap;
  final bool isTrafficActive;
  final bool isTrafficLoading;
  final VoidCallback? onApproachTap;
  final bool isApproachActive;
  final FollowMode followMode;
  final ValueChanged<FollowMode>? onFollowModeChanged;

  const MapSidebar({
    super.key,
    this.onZoomIn,
    this.onZoomOut,
    this.onAeroSettingsTap,
    this.onTrafficSettingsTap,
    this.isTrafficActive = false,
    this.isTrafficLoading = false,
    this.onApproachTap,
    this.isApproachActive = false,
    this.followMode = FollowMode.off,
    this.onFollowModeChanged,
  });

  @override
  State<MapSidebar> createState() => _MapSidebarState();
}

class _MapSidebarState extends State<MapSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isTrafficLoading) _spinController.repeat();
  }

  @override
  void didUpdateWidget(MapSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTrafficLoading && !_spinController.isAnimating) {
      _spinController.repeat();
    } else if (!widget.isTrafficLoading && _spinController.isAnimating) {
      _spinController.stop();
      _spinController.reset();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _cycleFollowMode() {
    final next = switch (widget.followMode) {
      FollowMode.off => FollowMode.northUp,
      FollowMode.northUp => FollowMode.trackUp,
      FollowMode.trackUp => FollowMode.off,
    };
    widget.onFollowModeChanged?.call(next);
  }

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

          // Traffic settings
          _SidebarButton(
            icon: Icons.flight,
            size: 18,
            active: widget.isTrafficActive,
            onTap: () => widget.onTrafficSettingsTap?.call(),
            spinController:
                widget.isTrafficLoading ? _spinController : null,
          ),
          const SizedBox(height: 12),

          // Approach plate overlay
          _SidebarButton(
            icon: Icons.flight_land,
            size: 18,
            active: widget.isApproachActive,
            onTap: () => widget.onApproachTap?.call(),
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
          const SizedBox(height: 12),

          // Follow mode / center on me
          _SidebarButton(
            icon: widget.followMode == FollowMode.trackUp
                ? Icons.navigation
                : Icons.my_location,
            size: 18,
            active: widget.followMode != FollowMode.off,
            onTap: _cycleFollowMode,
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
  final AnimationController? spinController;

  const _SidebarButton({
    required this.icon,
    required this.onTap,
    this.size = 20,
    this.active = false,
    this.spinController,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(
      icon,
      color: active ? Colors.white : Colors.white70,
      size: size,
    );

    if (spinController != null) {
      iconWidget = RotationTransition(
        turns: spinController!,
        child: iconWidget,
      );
    }

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
          child: iconWidget,
        ),
      ),
    );
  }
}
