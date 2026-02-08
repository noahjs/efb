import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MapToolbar extends StatelessWidget {
  final VoidCallback onLayersTap;
  final VoidCallback onSettingsTap;
  final VoidCallback? onFplTap;
  final bool isFplOpen;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchTap;
  final VoidCallback? onSearchClear;
  final bool isSearching;

  const MapToolbar({
    super.key,
    required this.onLayersTap,
    required this.onSettingsTap,
    this.onFplTap,
    this.isFplOpen = false,
    this.searchController,
    this.searchFocusNode,
    this.onSearchChanged,
    this.onSearchTap,
    this.onSearchClear,
    this.isSearching = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.toolbarBackground.withValues(alpha: 0.95),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topPadding),

          // Icon row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _ToolbarButton(
                  icon: Icons.layers,
                  onTap: onLayersTap,
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onFplTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isFplOpen ? AppColors.accent : AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FPL',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _ToolbarButton(
                  icon: Icons.settings,
                  onTap: onSettingsTap,
                  badgeColor: AppColors.error,
                ),
                const SizedBox(width: 4),
                _ToolbarButton(
                  icon: Icons.bar_chart,
                  onTap: () {},
                ),
                const Spacer(),
                _ToolbarButton(
                  icon: Icons.public,
                  onTap: () {},
                ),
                const SizedBox(width: 4),
                _ToolbarButton(
                  icon: Icons.star_border,
                  onTap: () {},
                ),
                const SizedBox(width: 4),
                _ToolbarButton(
                  icon: Icons.my_location,
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      onChanged: onSearchChanged,
                      onTap: onSearchTap,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search airports',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        filled: false,
                      ),
                    ),
                  ),
                  if (isSearching)
                    GestureDetector(
                      onTap: onSearchClear,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.close,
                            color: AppColors.textMuted, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? badgeColor;

  const _ToolbarButton({
    required this.icon,
    required this.onTap,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: AppColors.textPrimary, size: 22),
            ),
          ),
        ),
        if (badgeColor != null)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
