import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

String? _basePath;

Future<String> _getPath() async {
  if (_basePath != null) return _basePath!;
  final dir = await getApplicationDocumentsDirectory();
  _basePath = '${dir.path}/scratchpads';
  await Directory(_basePath!).create(recursive: true);
  return _basePath!;
}

Future<List<Map<String, dynamic>>> loadAllFromDisk() async {
  final base = await _getPath();
  final dir = Directory(base);
  if (!await dir.exists()) return [];

  final results = <Map<String, dynamic>>[];
  await for (final entity in dir.list()) {
    if (entity is File && entity.path.endsWith('.json')) {
      try {
        final content = await entity.readAsString();
        results.add(jsonDecode(content) as Map<String, dynamic>);
      } catch (_) {}
    }
  }
  return results;
}

Future<void> saveToDisk(String id, String jsonString) async {
  final base = await _getPath();
  final file = File('$base/$id.json');
  await file.writeAsString(jsonString);
}

Future<void> deleteFromDisk(String id) async {
  final base = await _getPath();
  final file = File('$base/$id.json');
  if (await file.exists()) {
    await file.delete();
  }
}
