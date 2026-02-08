import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/scratchpad.dart';

class ScratchPadStorage {
  static ScratchPadStorage? _instance;
  String? _basePath;

  ScratchPadStorage._();

  static ScratchPadStorage get instance {
    _instance ??= ScratchPadStorage._();
    return _instance!;
  }

  Future<String> get _path async {
    if (_basePath != null) return _basePath!;
    final dir = await getApplicationDocumentsDirectory();
    _basePath = '${dir.path}/scratchpads';
    await Directory(_basePath!).create(recursive: true);
    return _basePath!;
  }

  Future<List<ScratchPad>> loadAll() async {
    final base = await _path;
    final dir = Directory(base);
    if (!await dir.exists()) return [];

    final pads = <ScratchPad>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          pads.add(ScratchPad.fromJson(json));
        } catch (_) {
          // Skip corrupted files
        }
      }
    }

    pads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return pads;
  }

  Future<ScratchPad?> load(String id) async {
    final base = await _path;
    final file = File('$base/$id.json');
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ScratchPad.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ScratchPad pad) async {
    final base = await _path;
    final file = File('$base/${pad.id}.json');
    await file.writeAsString(jsonEncode(pad.toJson()));
  }

  Future<void> delete(String id) async {
    final base = await _path;
    final file = File('$base/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
