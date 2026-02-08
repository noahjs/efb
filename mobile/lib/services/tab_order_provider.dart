import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/tab_item.dart';

const _prefsKey = 'tab_order';

class TabOrderNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    if (saved != null && saved.length >= tabBarSlotCount) {
      // Validate that all keys still exist
      final valid = saved.where((k) => tabItemByKey(k) != null).toList();
      if (valid.length >= tabBarSlotCount) return valid;
    }
    return List<String>.from(defaultTabKeys);
  }

  /// Reorder the full list (tab bar slots + overflow).
  Future<void> setOrder(List<String> keys) async {
    state = AsyncData(keys);
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(_prefsKey, keys);
  }
}

final tabOrderProvider =
    AsyncNotifierProvider<TabOrderNotifier, List<String>>(
        TabOrderNotifier.new);

/// Convenience: the TabItems currently in the bottom nav bar (first 4).
final bottomNavTabsProvider = Provider<List<TabItem>>((ref) {
  final keys = ref.watch(tabOrderProvider).value ?? defaultTabKeys;
  return keys
      .take(tabBarSlotCount)
      .map((k) => tabItemByKey(k))
      .whereType<TabItem>()
      .toList();
});

/// Convenience: TabItem keys NOT in the bottom nav (overflow into More).
final overflowTabKeysProvider = Provider<List<String>>((ref) {
  final keys = ref.watch(tabOrderProvider).value ?? defaultTabKeys;
  if (keys.length <= tabBarSlotCount) return [];
  return keys.sublist(tabBarSlotCount);
});
