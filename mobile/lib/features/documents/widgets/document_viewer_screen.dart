import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/aircraft.dart';
import '../../../models/document.dart';
import '../../../models/document_folder.dart';
import '../../../services/api_client.dart';
import '../../../services/aircraft_providers.dart';
import '../../../services/document_providers.dart';
import 'folder_create_dialog.dart';
import 'move_to_folder_sheet.dart';
import 'pdf_viewer_native.dart' if (dart.library.html) 'pdf_viewer_stub.dart';

class DocumentViewerScreen extends ConsumerStatefulWidget {
  final int documentId;

  const DocumentViewerScreen({super.key, required this.documentId});

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  Document? _doc;
  Uint8List? _fileBytes;
  bool _loading = true;
  String? _error;
  bool _overlayActive = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      final api = ref.read(apiClientProvider);

      final meta = await api.getDocumentById(widget.documentId);
      final doc = Document.fromJson(meta);

      if (mounted) {
        setState(() => _doc = doc);
      }

      final bytes = await api.downloadDocumentBytes(widget.documentId);

      if (mounted) {
        setState(() {
          _fileBytes = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_doc?.originalName ?? 'Document'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load document:\n$_error',
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildMetadataBar(),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildMetadataBar() {
    final doc = _doc!;
    final aircraftAsync = ref.watch(aircraftListProvider(''));
    final foldersAsync = ref.watch(documentFoldersProvider(doc.aircraftId));

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document name (tappable to rename)
          GestureDetector(
            onTap: _renameDocument,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    doc.originalName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Aircraft and Folder selectors
          Row(
            children: [
              // Aircraft chip
              Expanded(
                child: aircraftAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (aircraftList) => _buildAircraftChip(
                    doc,
                    aircraftList,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Folder chip
              Expanded(
                child: foldersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (folders) => _buildFolderChip(doc, folders),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAircraftChip(Document doc, List<Aircraft> aircraftList) {
    final current = doc.aircraftId != null
        ? aircraftList
            .where((a) => a.id == doc.aircraftId)
            .firstOrNull
        : null;

    return GestureDetector(
      onTap: () => _selectAircraft(aircraftList),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.flight,
              size: 16,
              color: current != null
                  ? AppColors.accent
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                current?.tailNumber ?? 'No Aircraft',
                style: TextStyle(
                  color: current != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderChip(Document doc, List<DocumentFolder> folders) {
    final current = doc.folderId != null
        ? folders.where((f) => f.id == doc.folderId).firstOrNull
        : null;

    return GestureDetector(
      onTap: () => _selectFolder(folders),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 16,
              color: current != null
                  ? AppColors.accent
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                current?.name ?? 'No Folder',
                style: TextStyle(
                  color: current != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_fileBytes == null) {
      return const Center(
        child: Text('Unsupported file type',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    // Remove platform view from tree while overlays are shown,
    // otherwise the native UIView swallows all touch events.
    if (_overlayActive) {
      return Container(color: AppColors.background);
    }

    if (_doc?.isPdf == true) {
      return buildPdfViewer(_fileBytes!, widget.documentId);
    }

    if (_doc?.isImage == true) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.memory(_fileBytes!),
        ),
      );
    }

    return const Center(
      child: Text('Unsupported file type',
          style: TextStyle(color: AppColors.textMuted)),
    );
  }

  /// Remove platform views, wait a frame, run [fn], then restore.
  Future<T?> _withOverlay<T>(Future<T?> Function() fn) async {
    setState(() => _overlayActive = true);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return null;
    try {
      return await fn();
    } finally {
      if (mounted) setState(() => _overlayActive = false);
    }
  }

  // ── Actions ──

  Future<void> _renameDocument() async {
    final name = await _withOverlay(() => showDialog<String>(
          context: context,
          builder: (_) => FolderCreateDialog(
            title: 'Rename Document',
            initialName: _doc?.originalName,
          ),
        ));
    if (name == null || name == _doc?.originalName) return;

    try {
      final service = ref.read(documentServiceProvider);
      final updated =
          await service.update(widget.documentId, {'original_name': name});
      if (mounted) setState(() => _doc = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename: $e')),
        );
      }
    }
  }

  Future<void> _selectAircraft(List<Aircraft> aircraftList) async {
    final selected = await _withOverlay(() => showDialog<int>(
          context: context,
          builder: (dialogContext) => SimpleDialog(
            title: const Text('Attach to Aircraft'),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, -1),
                child: Row(
                  children: [
                    const Icon(Icons.close, color: AppColors.textMuted),
                    const SizedBox(width: 16),
                    Text(
                      'No Aircraft',
                      style: TextStyle(
                        color: _doc?.aircraftId == null
                            ? AppColors.accent
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              ...aircraftList.map(
                (a) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, a.id),
                  child: Row(
                    children: [
                      const Icon(Icons.flight, color: AppColors.accent),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.tailNumber,
                              style: TextStyle(
                                color: _doc?.aircraftId == a.id
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              a.aircraftType,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
    if (selected == null) return;

    try {
      final service = ref.read(documentServiceProvider);
      final updated = await service.update(widget.documentId, {
        'aircraft_id': selected == -1 ? null : selected,
      });
      if (mounted) setState(() => _doc = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _selectFolder(List<DocumentFolder> folders) async {
    final folderId = await _withOverlay(() => showModalBottomSheet<int>(
          context: context,
          builder: (_) => MoveToFolderSheet(
            folders: folders,
            currentFolderId: _doc?.folderId,
          ),
        ));
    if (folderId == null) return;

    try {
      final service = ref.read(documentServiceProvider);
      final updated = await service.update(widget.documentId, {
        'folder_id': folderId == -1 ? null : folderId,
      });
      if (mounted) setState(() => _doc = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}
