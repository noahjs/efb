import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

String? _basePath;

Future<String> _getPath() async {
  if (_basePath != null) return _basePath!;
  final dir = await getApplicationDocumentsDirectory();
  _basePath = '${dir.path}/plate_annotations';
  await Directory(_basePath!).create(recursive: true);
  return _basePath!;
}

Future<Map<String, dynamic>?> loadAnnotation(String key) async {
  final base = await _getPath();
  final file = File('$base/$key.json');
  if (!await file.exists()) return null;
  try {
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

Future<void> saveAnnotation(String key, String jsonString) async {
  final base = await _getPath();
  final file = File('$base/$key.json');
  await file.writeAsString(jsonString);
}

Future<void> deleteAnnotation(String key) async {
  final base = await _getPath();
  final file = File('$base/$key.json');
  if (await file.exists()) {
    await file.delete();
  }
}
