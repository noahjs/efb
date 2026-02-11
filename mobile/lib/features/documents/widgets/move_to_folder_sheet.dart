import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/document_folder.dart';
import '../../../services/document_providers.dart';
import 'folder_create_dialog.dart';

class MoveToFolderSheet extends ConsumerStatefulWidget {
  final List<DocumentFolder> folders;
  final int? currentFolderId;
  final int? aircraftId;

  const MoveToFolderSheet({
    super.key,
    required this.folders,
    this.currentFolderId,
    this.aircraftId,
  });

  @override
  ConsumerState<MoveToFolderSheet> createState() => _MoveToFolderSheetState();
}

class _MoveToFolderSheetState extends ConsumerState<MoveToFolderSheet> {
  late List<DocumentFolder> _folders;

  @override
  void initState() {
    super.initState();
    _folders = List.of(widget.folders);
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const FolderCreateDialog(),
    );
    if (name == null || !mounted) return;

    try {
      final service = ref.read(documentServiceProvider);
      final folder = await service.createFolder({
        'name': name,
        if (widget.aircraftId != null) 'aircraft_id': widget.aircraftId,
      });
      ref.invalidate(documentFoldersProvider(widget.aircraftId));
      if (mounted) Navigator.pop(context, folder.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create folder: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Move to Folder',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // New Folder row
          _buildRow(
            icon: Icons.create_new_folder_outlined,
            iconColor: AppColors.accent,
            label: 'New Folder',
            labelColor: AppColors.accent,
            onTap: _createFolder,
          ),
          // No Folder row
          _buildRow(
            icon: Icons.folder_off_outlined,
            iconColor: AppColors.textMuted,
            label: 'No Folder',
            labelColor: AppColors.textPrimary,
            selected: widget.currentFolderId == null,
            onTap: () => Navigator.pop(context, -1),
          ),
          // Folder rows
          ..._folders.map(
            (f) => _buildRow(
              icon: Icons.folder_outlined,
              iconColor: AppColors.accent,
              label: f.name,
              labelColor: AppColors.textPrimary,
              selected: widget.currentFolderId == f.id,
              onTap: () => Navigator.pop(context, f.id),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color labelColor,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 15,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
