import 'document_folder.dart';

class Document {
  final int? id;
  final int? aircraftId;
  final int? folderId;
  final String originalName;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final DocumentFolder? folder;
  final String? createdAt;
  final String? updatedAt;

  const Document({
    this.id,
    this.aircraftId,
    this.folderId,
    this.originalName = '',
    this.filename = '',
    this.mimeType = '',
    this.sizeBytes = 0,
    this.folder,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage =>
      mimeType == 'image/jpeg' || mimeType == 'image/png';

  String get sizeDisplay {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as int?,
      aircraftId: json['aircraft_id'] as int?,
      folderId: json['folder_id'] as int?,
      originalName: (json['original_name'] as String?) ?? '',
      filename: (json['filename'] as String?) ?? '',
      mimeType: (json['mime_type'] as String?) ?? '',
      sizeBytes: (json['size_bytes'] as int?) ?? 0,
      folder: json['folder'] != null
          ? DocumentFolder.fromJson(json['folder'])
          : null,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (aircraftId != null) 'aircraft_id': aircraftId,
      if (folderId != null) 'folder_id': folderId,
      'original_name': originalName,
    };
  }

  Document copyWith({
    int? id,
    int? aircraftId,
    int? folderId,
    String? originalName,
    String? filename,
    String? mimeType,
    int? sizeBytes,
    DocumentFolder? folder,
    String? createdAt,
    String? updatedAt,
  }) {
    return Document(
      id: id ?? this.id,
      aircraftId: aircraftId ?? this.aircraftId,
      folderId: folderId ?? this.folderId,
      originalName: originalName ?? this.originalName,
      filename: filename ?? this.filename,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      folder: folder ?? this.folder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
