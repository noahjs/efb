import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/tab_item.dart';
import '../theme/app_theme.dart';
import '../../services/tab_order_provider.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context, List<TabItem> tabs) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < tabs.length; i++) {
      if (location.startsWith(tabs[i].route)) return i;
    }
    // Check if we're on /more
    if (location.startsWith('/more')) return tabs.length;
    return -1;
  }

  void _onTap(BuildContext context, int index, List<TabItem> tabs) {
    if (index < tabs.length) {
      context.go(tabs[index].route);
    } else {
      context.go('/more');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(bottomNavTabsProvider);

    final currentIdx = _currentIndex(context, tabs);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIdx >= 0 ? currentIdx : 0,
          onTap: (index) => _onTap(context, index, tabs),
          items: [
            ...tabs.map((t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                )),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu),
              activeIcon: Icon(Icons.menu),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
