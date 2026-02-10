import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/document_providers.dart';
import 'document_tile.dart';

/// Reusable document list that can be embedded in other screens
class DocumentListView extends ConsumerWidget {
  final int? aircraftId;
  final int? folderId;

  const DocumentListView({
    super.key,
    this.aircraftId,
    this.folderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = DocumentQuery(
      folderId: folderId,
      aircraftId: aircraftId,
    );
    final docsAsync = ref.watch(documentListProvider(query));

    return docsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: AppColors.error)),
      ),
      data: (docs) {
        if (docs.isEmpty) {
          return const Center(
            child: Text('No documents',
                style: TextStyle(color: AppColors.textMuted)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, i) => DocumentTile(
            document: docs[i],
            onTap: () => context.push('/documents/${docs[i].id}/view'),
          ),
        );
      },
    );
  }
}
