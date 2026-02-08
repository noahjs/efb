import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const _storageKey = 'scratchpads';

Future<List<Map<String, dynamic>>> loadAllFromDisk() async {
  final raw = html.window.localStorage[_storageKey];
  if (raw == null || raw.isEmpty) return [];

  try {
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

Future<void> saveToDisk(String id, String jsonString) async {
  // Load existing, upsert, save back
  final all = await loadAllFromDisk();
  final map = jsonDecode(jsonString) as Map<String, dynamic>;
  final idx = all.indexWhere((e) => e['id'] == id);
  if (idx >= 0) {
    all[idx] = map;
  } else {
    all.add(map);
  }
  html.window.localStorage[_storageKey] = jsonEncode(all);
}

Future<void> deleteFromDisk(String id) async {
  final all = await loadAllFromDisk();
  all.removeWhere((e) => e['id'] == id);
  html.window.localStorage[_storageKey] = jsonEncode(all);
}
