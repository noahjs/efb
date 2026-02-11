import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/document.dart';
import '../../models/document_folder.dart';
import '../../services/document_providers.dart';
import 'widgets/document_tile.dart';
import 'widgets/folder_list_section.dart';
import 'widgets/folder_create_dialog.dart';
import 'widgets/move_to_folder_sheet.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  final int? aircraftId;

  const DocumentsScreen({super.key, this.aircraftId});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  int? _selectedFolderId;
  bool _uploading = false;

  DocumentQuery get _query => DocumentQuery(
        folderId: _selectedFolderId,
        aircraftId: widget.aircraftId,
      );

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentListProvider(_query));
    final foldersAsync =
        ref.watch(documentFoldersProvider(widget.aircraftId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.aircraftId != null ? 'Aircraft Documents' : 'Documents'),
        centerTitle: true,
        automaticallyImplyLeading: widget.aircraftId != null,
      ),
      body: Column(
        children: [
          // Folder chips
          foldersAsync.when(
            loading: () => const SizedBox(height: 40),
            error: (_, _) => const SizedBox(height: 40),
            data: (folders) => FolderListSection(
              folders: folders,
              selectedFolderId: _selectedFolderId,
              onFolderSelected: (id) =>
                  setState(() => _selectedFolderId = id),
              onCreateFolder: () => _createFolder(context),
              onFolderLongPress: (folder) =>
                  _showFolderActions(context, folder),
            ),
          ),
          const SizedBox(height: 4),

          // Document list
          Expanded(
            child: docsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: AppColors.error)),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open,
                            size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        const Text(
                          'No documents yet',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap + to upload a PDF or image',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) => DocumentTile(
                    document: docs[i],
                    onTap: () =>
                        context.push('/documents/${docs[i].id}/view'),
                    onLongPress: () =>
                        _showDocumentActions(context, docs[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : () => _pickAndUpload(context),
        backgroundColor: AppColors.primary,
        child: _uploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    String mimeType = 'application/octet-stream';
    final ext = file.extension?.toLowerCase();
    if (ext == 'pdf') mimeType = 'application/pdf';
    if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';
    if (ext == 'png') mimeType = 'image/png';

    setState(() => _uploading = true);
    try {
      final service = ref.read(documentServiceProvider);
      await service.upload(
        fileBytes: file.bytes!,
        fileName: file.name,
        mimeType: mimeType,
        aircraftId: widget.aircraftId,
        folderId: _selectedFolderId,
      );
      ref.invalidate(documentListProvider(_query));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _createFolder(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const FolderCreateDialog(),
    );
    if (name == null) return;

    try {
      final service = ref.read(documentServiceProvider);
      await service.createFolder({
        'name': name,
        if (widget.aircraftId != null) 'aircraft_id': widget.aircraftId,
      });
      ref.invalidate(documentFoldersProvider(widget.aircraftId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create folder: $e')),
        );
      }
    }
  }

  void _showFolderActions(BuildContext context, DocumentFolder folder) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _renameFolder(context, folder);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteFolder(context, folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameFolder(
      BuildContext context, DocumentFolder folder) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => FolderCreateDialog(
        title: 'Rename Folder',
        initialName: folder.name,
      ),
    );
    if (name == null) return;

    try {
      final service = ref.read(documentServiceProvider);
      await service.updateFolder(folder.id!, {'name': name});
      ref.invalidate(documentFoldersProvider(widget.aircraftId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteFolder(
      BuildContext context, DocumentFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text(
            'Delete "${folder.name}"? Documents in this folder will be kept but moved out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final service = ref.read(documentServiceProvider);
      await service.deleteFolder(folder.id!);
      if (_selectedFolderId == folder.id) {
        setState(() => _selectedFolderId = null);
      }
      ref.invalidate(documentFoldersProvider(widget.aircraftId));
      ref.invalidate(documentListProvider(_query));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  void _showDocumentActions(BuildContext context, Document doc) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _renameDocument(context, doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Move to Folder'),
              onTap: () {
                Navigator.pop(context);
                _moveToFolder(context, doc);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _deleteDocument(context, doc);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameDocument(BuildContext context, Document doc) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => FolderCreateDialog(
        title: 'Rename Document',
        initialName: doc.originalName,
      ),
    );
    if (name == null) return;

    try {
      final service = ref.read(documentServiceProvider);
      await service.update(doc.id!, {'original_name': name});
      ref.invalidate(documentListProvider(_query));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _moveToFolder(BuildContext context, Document doc) async {
    final folders =
        ref.read(documentFoldersProvider(widget.aircraftId)).value ?? [];
    final folderId = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => MoveToFolderSheet(
        folders: folders,
        currentFolderId: doc.folderId,
        aircraftId: widget.aircraftId,
      ),
    );
    if (folderId == null) return;

    try {
      final service = ref.read(documentServiceProvider);
      await service.update(doc.id!, {
        'folder_id': folderId == -1 ? null : folderId,
      });
      ref.invalidate(documentListProvider(_query));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteDocument(BuildContext context, Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Delete "${doc.originalName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final service = ref.read(documentServiceProvider);
      await service.delete(doc.id!);
      ref.invalidate(documentListProvider(_query));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}
