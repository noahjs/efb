import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/tab_item.dart';
import '../../core/theme/app_theme.dart';
import '../../services/tab_order_provider.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool _editing = false;
  List<String> _keys = [];

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Coming Soon'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.surfaceLight,
      ),
    );
  }

  void _startEditing() {
    final keys = ref.read(tabOrderProvider).value ?? defaultTabKeys;
    final all = allAvailableTabs.map((t) => t.key).toList();
    final ordered = List<String>.from(keys);
    for (final k in all) {
      if (!ordered.contains(k)) ordered.add(k);
    }
    setState(() {
      _keys = ordered;
      _editing = true;
    });
  }

  void _stopEditing() {
    ref.read(tabOrderProvider.notifier).setOrder(List.from(_keys));
    setState(() => _editing = false);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        children: [
          // Downloads & Settings row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.download,
                    label: 'Downloads',
                    onTap: () => _showComingSoon('Downloads'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () => _showComingSoon('Settings'),
                  ),
                ),
              ],
            ),
          ),

          // Views section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'VIEWS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1,
                  ),
                ),
                TextButton(
                  onPressed: _editing ? _stopEditing : _startEditing,
                  child: Text(
                    _editing ? 'Done' : 'Edit Tab Order',
                    style:
                        const TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Editing: reorderable tab items inline
          if (_editing) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Drag to reorder. The top $tabBarSlotCount items appear in the tab bar.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: _onReorder,
              itemCount: _keys.length,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: AppColors.surfaceLight,
                  elevation: 4,
                  shadowColor: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final key = _keys[index];
                final tab = tabItemByKey(key);
                if (tab == null) {
                  return const SizedBox.shrink(key: ValueKey(''));
                }

                final inTabBar = index < tabBarSlotCount;

                return Container(
                  key: ValueKey(key),
                  decoration: BoxDecoration(
                    color: inTabBar
                        ? AppColors.surface
                        : AppColors.surface.withValues(alpha: 0.6),
                    border: index == tabBarSlotCount
                        ? const Border(
                            top: BorderSide(
                                color: AppColors.divider, width: 0.5),
                          )
                        : null,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: tab.iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          Icon(tab.activeIcon, color: tab.iconColor, size: 18),
                    ),
                    title: Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight:
                            inTabBar ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: inTabBar
                        ? null
                        : const Text('More menu',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child:
                            Icon(Icons.drag_handle, color: AppColors.textMuted),
                      ),
                    ),
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -1),
                  ),
                );
              },
            ),
          ],

          // Normal: overflow items from tab order
          if (!_editing)
            for (final key in ref.watch(overflowTabKeysProvider))
              if (tabItemByKey(key) case final tab?)
                _MenuItem(
                  icon: tab.icon,
                  iconColor: tab.iconColor,
                  label: tab.label,
                  onTap: () => context.go(tab.route),
                ),

          const Divider(),

          // Additional items
          _MenuItem(
            icon: Icons.devices,
            iconColor: const Color(0xFF5C6BC0),
            label: 'Devices',
            onTap: () => _showComingSoon('Devices'),
          ),
          _MenuItem(
            icon: Icons.person_outline,
            iconColor: const Color(0xFF42A5F5),
            label: 'Pilot Profile',
            onTap: () => context.go('/more/profile'),
          ),
          _MenuItem(
            icon: Icons.help_outline,
            iconColor: const Color(0xFF66BB6A),
            label: 'Support',
            onTap: () => _showComingSoon('Support'),
          ),
          _MenuItem(
            icon: Icons.info_outline,
            iconColor: const Color(0xFF42A5F5),
            label: 'About',
            onTap: () => _showComingSoon('About'),
          ),

          const SizedBox(height: 16),

          // Timer widget
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '00:00',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Tap to Start',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing:
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
