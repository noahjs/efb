import 'dart:convert';
import '../models/scratchpad.dart';

import 'plate_annotation_storage_io.dart'
    if (dart.library.html) 'plate_annotation_storage_web.dart' as platform;

class PlateAnnotationStorage {
  static PlateAnnotationStorage? _instance;
  final Map<String, List<Stroke>> _cache = {};

  PlateAnnotationStorage._();

  static PlateAnnotationStorage get instance {
    _instance ??= PlateAnnotationStorage._();
    return _instance!;
  }

  String _key(String airportId, int procedureId) =>
      '${airportId}_$procedureId';

  Future<List<Stroke>> load(String airportId, int procedureId) async {
    final key = _key(airportId, procedureId);
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final data = await platform.loadAnnotation(key);
      if (data == null) return [];
      final strokes = (data['strokes'] as List?)
              ?.map((s) => Stroke.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];
      _cache[key] = strokes;
      return strokes;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(
      String airportId, int procedureId, List<Stroke> strokes) async {
    final key = _key(airportId, procedureId);
    _cache[key] = strokes;

    final json = {
      'strokes': strokes.map((s) => s.toJson()).toList(),
      'pageIndex': 0,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      await platform.saveAnnotation(key, jsonEncode(json));
    } catch (_) {}
  }

  Future<void> delete(String airportId, int procedureId) async {
    final key = _key(airportId, procedureId);
    _cache.remove(key);
    try {
      await platform.deleteAnnotation(key);
    } catch (_) {}
  }
}
