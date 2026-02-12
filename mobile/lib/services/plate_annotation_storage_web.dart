import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const _storagePrefix = 'plate_annotation_';

Future<Map<String, dynamic>?> loadAnnotation(String key) async {
  final raw = html.window.localStorage['$_storagePrefix$key'];
  if (raw == null || raw.isEmpty) return null;
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Future<void> saveAnnotation(String key, String jsonString) async {
  html.window.localStorage['$_storagePrefix$key'] = jsonString;
}

Future<void> deleteAnnotation(String key) async {
  html.window.localStorage.remove('$_storagePrefix$key');
}
