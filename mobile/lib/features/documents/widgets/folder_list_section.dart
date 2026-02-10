import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/document_folder.dart';

class FolderListSection extends StatelessWidget {
  final List<DocumentFolder> folders;
  final int? selectedFolderId;
  final ValueChanged<int?> onFolderSelected;
  final VoidCallback onCreateFolder;
  final void Function(DocumentFolder folder) onFolderLongPress;

  const FolderListSection({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.onFolderSelected,
    required this.onCreateFolder,
    required this.onFolderLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildChip(
            label: 'All',
            selected: selectedFolderId == null,
            onTap: () => onFolderSelected(null),
          ),
          ...folders.map((f) => _buildChip(
                label: f.name,
                selected: selectedFolderId == f.id,
                onTap: () => onFolderSelected(f.id),
                onLongPress: () => onFolderLongPress(f),
              )),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: AppColors.accent),
              label: const Text('New Folder',
                  style: TextStyle(color: AppColors.accent, fontSize: 13)),
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.divider),
              onPressed: onCreateFolder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: FilterChip(
          label: Text(label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
              )),
          selected: selected,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
          showCheckmark: false,
          onSelected: (_) => onTap(),
        ),
      ),
    );
  }
}
