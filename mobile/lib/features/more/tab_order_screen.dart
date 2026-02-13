import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/tab_item.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tab_order_provider.dart';

class TabOrderScreen extends ConsumerStatefulWidget {
  const TabOrderScreen({super.key});

  @override
  ConsumerState<TabOrderScreen> createState() => _TabOrderScreenState();
}

class _TabOrderScreenState extends ConsumerState<TabOrderScreen> {
  late List<String> _keys;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final keys = await ref.read(tabOrderProvider.future);
    // Ensure every available tab is in the list
    final all = allAvailableTabs.map((t) => t.key).toList();
    final ordered = List<String>.from(keys);
    for (final k in all) {
      if (!ordered.contains(k)) ordered.add(k);
    }
    setState(() {
      _keys = ordered;
      _loaded = true;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _keys.removeAt(oldIndex);
      _keys.insert(newIndex, item);
    });
    ref.read(tabOrderProvider.notifier).setOrder(List.from(_keys));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Tab Order')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Tab Order'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Drag to reorder. The top $tabBarSlotCount items appear in the tab bar.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              onReorder: _onReorder,
              itemCount: _keys.length,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: AppColors.surfaceLight,
                  elevation: 4,
                  shadowColor: AppColors.scrim,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final key = _keys[index];
                final tab = tabItemByKey(key);
                if (tab == null) return const SizedBox.shrink(key: ValueKey(''));

                final inTabBar = index < tabBarSlotCount;

                // Insert a divider header before the first overflow item
                Widget? header;
                if (index == 0) {
                  header = _SectionLabel(label: 'TAB BAR');
                } else if (index == tabBarSlotCount) {
                  header = _SectionLabel(label: 'MORE MENU');
                }

                return Column(
                  key: ValueKey(key),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?header,
                    Container(
                      color: inTabBar
                          ? AppColors.surface
                          : AppColors.surface.withValues(alpha: 0.6),
                      child: ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: tab.iconColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(tab.activeIcon,
                              color: tab.iconColor, size: 20),
                        ),
                        title: Text(
                          tab.label,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight:
                                inTabBar ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle,
                                color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
