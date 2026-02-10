import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/document_folder.dart';

class MoveToFolderSheet extends StatelessWidget {
  final List<DocumentFolder> folders;
  final int? currentFolderId;

  const MoveToFolderSheet({
    super.key,
    required this.folders,
    this.currentFolderId,
  });

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
          ListTile(
            leading: const Icon(Icons.folder_off_outlined,
                color: AppColors.textMuted),
            title: const Text('No Folder'),
            selected: currentFolderId == null,
            onTap: () => Navigator.pop(context, -1),
          ),
          ...folders.map(
            (f) => ListTile(
              leading:
                  const Icon(Icons.folder_outlined, color: AppColors.accent),
              title: Text(f.name),
              selected: currentFolderId == f.id,
              onTap: () => Navigator.pop(context, f.id),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
