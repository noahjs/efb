class DocumentFolder {
  final int? id;
  final String name;
  final int? aircraftId;
  final String? createdAt;
  final String? updatedAt;

  const DocumentFolder({
    this.id,
    this.name = '',
    this.aircraftId,
    this.createdAt,
    this.updatedAt,
  });

  factory DocumentFolder.fromJson(Map<String, dynamic> json) {
    return DocumentFolder(
      id: json['id'] as int?,
      name: (json['name'] as String?) ?? '',
      aircraftId: json['aircraft_id'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (aircraftId != null) 'aircraft_id': aircraftId,
    };
  }

  DocumentFolder copyWith({
    int? id,
    String? name,
    int? aircraftId,
    String? createdAt,
    String? updatedAt,
  }) {
    return DocumentFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      aircraftId: aircraftId ?? this.aircraftId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
