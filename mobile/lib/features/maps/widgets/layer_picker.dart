import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../layers/map_layer_def.dart';
import '../layers/map_layer_registry.dart';
import '../providers/map_layer_state_provider.dart';

class LayerPicker extends ConsumerWidget {
  final VoidCallback onClose;

  /// Called after a base layer is selected (so MapsScreen can dismiss the picker).
  final VoidCallback? onBaseLayerSelected;

  const LayerPicker({
    super.key,
    required this.onClose,
    this.onBaseLayerSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layerState = ref.watch(mapLayerStateProvider).value;
    if (layerState == null) return const SizedBox.shrink();

    final notifier = ref.read(mapLayerStateProvider.notifier);

    return GestureDetector(
      onTap: () {}, // absorb taps on the picker itself
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: left overlays + base layers
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  ...kLeftOverlays.map((def) {
                    final isActive = layerState.isActive(def.id);
                    return _LayerRow(
                      label: def.displayName,
                      isActive: isActive,
                      onTap: () => notifier.toggleOverlay(def.id),
                    );
                  }),
                  const Divider(color: AppColors.divider, height: 12),
                  ...kBaseLayers.map((def) {
                    final isSelected = layerState.baseLayer == def.id;
                    return _LayerRow(
                      label: def.displayName,
                      isActive: isSelected,
                      onTap: () {
                        notifier.setBaseLayer(def.id);
                        onBaseLayerSelected?.call();
                      },
                    );
                  }),
                ],
              ),
            ),
            Container(
              width: 0.5,
              color: AppColors.divider,
            ),
            // Right column: overlay layers
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: _rightColumnItems.length,
                itemBuilder: (context, index) {
                  final item = _rightColumnItems[index];
                  if (item == null) {
                    return const Divider(color: AppColors.divider, height: 12);
                  }
                  final isActive = layerState.isActive(item.id);
                  return _LayerRow(
                    label: item.displayName,
                    isActive: isActive,
                    onTap: () => notifier.toggleOverlay(item.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Right column items with dividers auto-inserted before exclusive groups.
  static final List<MapLayerDef?> _rightColumnItems = () {
    final items = <MapLayerDef?>[];
    String? lastExclusiveGroup;
    for (final def in kRightOverlays) {
      // Insert divider when entering an exclusive group
      if (def.exclusiveGroup != null && def.exclusiveGroup != lastExclusiveGroup) {
        items.add(null); // null = divider
      }
      items.add(def);
      lastExclusiveGroup = def.exclusiveGroup;
    }
    return items;
  }();
}

class _LayerRow extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LayerRow({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primary.withValues(alpha: 0.25) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.accent : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
