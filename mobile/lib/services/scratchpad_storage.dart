import 'dart:convert';
import '../models/scratchpad.dart';

// Conditional import for file I/O (native only)
import 'scratchpad_storage_io.dart'
    if (dart.library.html) 'scratchpad_storage_web.dart' as platform;

class ScratchPadStorage {
  static ScratchPadStorage? _instance;
  final Map<String, ScratchPad> _cache = {};
  bool _initialized = false;

  ScratchPadStorage._();

  static ScratchPadStorage get instance {
    _instance ??= ScratchPadStorage._();
    return _instance!;
  }

  Future<void> _ensureLoaded() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final data = await platform.loadAllFromDisk();
      for (final json in data) {
        try {
          final pad = ScratchPad.fromJson(json);
          _cache[pad.id] = pad;
        } catch (_) {}
      }
    } catch (_) {
      // File I/O not available (web) — start with empty cache
    }
  }

  Future<List<ScratchPad>> loadAll() async {
    await _ensureLoaded();
    final pads = _cache.values.toList();
    pads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return pads;
  }

  Future<ScratchPad?> load(String id) async {
    await _ensureLoaded();
    return _cache[id];
  }

  Future<void> save(ScratchPad pad) async {
    _cache[pad.id] = pad;
    try {
      await platform.saveToDisk(pad.id, jsonEncode(pad.toJson()));
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    _cache.remove(id);
    try {
      await platform.deleteFromDisk(id);
    } catch (_) {}
  }
}
