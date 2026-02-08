import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scratchpad.dart';
import 'scratchpad_storage.dart';

final scratchPadStorageProvider = Provider<ScratchPadStorage>((ref) {
  return ScratchPadStorage.instance;
});

final scratchPadListProvider =
    AsyncNotifierProvider<ScratchPadListNotifier, List<ScratchPad>>(
  ScratchPadListNotifier.new,
);

class ScratchPadListNotifier extends AsyncNotifier<List<ScratchPad>> {
  @override
  Future<List<ScratchPad>> build() async {
    final storage = ref.read(scratchPadStorageProvider);
    return storage.loadAll();
  }

  Future<ScratchPad> create(ScratchPadTemplate template) async {
    final storage = ref.read(scratchPadStorageProvider);
    final now = DateTime.now();
    final pad = ScratchPad(
      id: _generateId(),
      template: template,
      createdAt: now,
      updatedAt: now,
    );
    await storage.save(pad);
    ref.invalidateSelf();
    return pad;
  }

  Future<void> save(ScratchPad pad) async {
    final storage = ref.read(scratchPadStorageProvider);
    await storage.save(pad);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final storage = ref.read(scratchPadStorageProvider);
    await storage.delete(id);
    ref.invalidateSelf();
  }

  String _generateId() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch}_${now.microsecond}';
  }
}

final scratchPadProvider =
    FutureProvider.family<ScratchPad?, String>((ref, id) async {
  final storage = ref.read(scratchPadStorageProvider);
  return storage.load(id);
});
