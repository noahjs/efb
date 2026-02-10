import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document.dart';
import '../models/document_folder.dart';
import 'api_client.dart';

/// Query parameters for document list filtering
class DocumentQuery {
  final int? folderId;
  final int? aircraftId;

  const DocumentQuery({this.folderId, this.aircraftId});

  @override
  bool operator ==(Object other) =>
      other is DocumentQuery &&
      other.folderId == folderId &&
      other.aircraftId == aircraftId;

  @override
  int get hashCode => Object.hash(folderId, aircraftId);
}

/// Provider for document list, filterable by folder and aircraft
final documentListProvider =
    FutureProvider.family<List<Document>, DocumentQuery>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final items = await api.getDocuments(
    folderId: query.folderId,
    aircraftId: query.aircraftId,
  );
  return items
      .map((json) => Document.fromJson(json as Map<String, dynamic>))
      .toList();
});

/// Provider for document folders, optionally filtered by aircraft
final documentFoldersProvider =
    FutureProvider.family<List<DocumentFolder>, int?>((ref, aircraftId) async {
  final api = ref.watch(apiClientProvider);
  final items = await api.getDocumentFolders(aircraftId: aircraftId);
  return items
      .map((json) => DocumentFolder.fromJson(json as Map<String, dynamic>))
      .toList();
});

/// Provider for a presigned download URL
final documentDownloadUrlProvider =
    FutureProvider.family<String, int>((ref, docId) async {
  final api = ref.watch(apiClientProvider);
  final result = await api.getDocumentDownloadUrl(docId);
  return result['url'] as String;
});

/// Service class for document mutations
class DocumentService {
  final ApiClient _api;

  DocumentService(this._api);

  Future<Document> upload({
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    int? aircraftId,
    int? folderId,
  }) async {
    final json = await _api.uploadDocument(
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
      aircraftId: aircraftId,
      folderId: folderId,
    );
    return Document.fromJson(json);
  }

  Future<Document> update(int id, Map<String, dynamic> data) async {
    final json = await _api.updateDocument(id, data);
    return Document.fromJson(json);
  }

  Future<void> delete(int id) async {
    await _api.deleteDocument(id);
  }

  Future<DocumentFolder> createFolder(Map<String, dynamic> data) async {
    final json = await _api.createDocumentFolder(data);
    return DocumentFolder.fromJson(json);
  }

  Future<DocumentFolder> updateFolder(
      int id, Map<String, dynamic> data) async {
    final json = await _api.updateDocumentFolder(id, data);
    return DocumentFolder.fromJson(json);
  }

  Future<void> deleteFolder(int id) async {
    await _api.deleteDocumentFolder(id);
  }
}

final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService(ref.watch(apiClientProvider));
});
