import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/scratchpad.dart';
import '../../services/scratchpad_providers.dart';
import 'widgets/template_picker.dart';
import 'widgets/scratchpad_thumbnail.dart';

class ScratchPadsScreen extends ConsumerStatefulWidget {
  const ScratchPadsScreen({super.key});

  @override
  ConsumerState<ScratchPadsScreen> createState() => _ScratchPadsScreenState();
}

class _ScratchPadsScreenState extends ConsumerState<ScratchPadsScreen> {
  bool _editMode = false;

  Future<void> _createNew() async {
    final template = await TemplatePicker.show(context);
    if (template == null || !mounted) return;

    final pad =
        await ref.read(scratchPadListProvider.notifier).create(template);
    if (mounted) {
      context.push('/scratchpads/${pad.id}');
    }
  }

  Future<void> _deletePad(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete ScratchPad?'),
        content:
            const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(scratchPadListProvider.notifier).delete(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padsAsync = ref.watch(scratchPadListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => setState(() => _editMode = !_editMode),
          child: Text(
            _editMode ? 'Done' : 'Edit',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          ),
        ),
        title: const Text('ScratchPads'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 28),
            onPressed: _createNew,
          ),
        ],
      ),
      body: padsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (pads) => _buildGrid(pads),
      ),
    );
  }

  Widget _buildGrid(List<ScratchPad> pads) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: pads.length + 1, // +1 for "New" card
        itemBuilder: (context, index) {
          if (index == pads.length) {
            return NewScratchPadCard(onTap: _createNew);
          }

          final pad = pads[index];
          return ScratchPadThumbnail(
            pad: pad,
            editMode: _editMode,
            onTap: () => context.push('/scratchpads/${pad.id}'),
            onDelete: () => _deletePad(pad.id),
          );
        },
      ),
    );
  }
}
