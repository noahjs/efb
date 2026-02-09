class Endorsement {
  final int? id;
  final String? date;
  final String? endorsementType;
  final String? farReference;
  final String? endorsementText;
  final String? cfiName;
  final String? cfiCertificateNumber;
  final String? cfiExpirationDate;
  final String? expirationDate;
  final String? comments;
  final String? createdAt;
  final String? updatedAt;

  const Endorsement({
    this.id,
    this.date,
    this.endorsementType,
    this.farReference,
    this.endorsementText,
    this.cfiName,
    this.cfiCertificateNumber,
    this.cfiExpirationDate,
    this.expirationDate,
    this.comments,
    this.createdAt,
    this.updatedAt,
  });

  factory Endorsement.fromJson(Map<String, dynamic> json) {
    return Endorsement(
      id: json['id'] as int?,
      date: json['date'] as String?,
      endorsementType: json['endorsement_type'] as String?,
      farReference: json['far_reference'] as String?,
      endorsementText: json['endorsement_text'] as String?,
      cfiName: json['cfi_name'] as String?,
      cfiCertificateNumber: json['cfi_certificate_number'] as String?,
      cfiExpirationDate: json['cfi_expiration_date'] as String?,
      expirationDate: json['expiration_date'] as String?,
      comments: json['comments'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'endorsement_type': endorsementType,
      'far_reference': farReference,
      'endorsement_text': endorsementText,
      'cfi_name': cfiName,
      'cfi_certificate_number': cfiCertificateNumber,
      'cfi_expiration_date': cfiExpirationDate,
      'expiration_date': expirationDate,
      'comments': comments,
    };
  }

  Endorsement copyWith({
    int? id,
    String? date,
    String? endorsementType,
    String? farReference,
    String? endorsementText,
    String? cfiName,
    String? cfiCertificateNumber,
    String? cfiExpirationDate,
    String? expirationDate,
    String? comments,
    String? createdAt,
    String? updatedAt,
  }) {
    return Endorsement(
      id: id ?? this.id,
      date: date ?? this.date,
      endorsementType: endorsementType ?? this.endorsementType,
      farReference: farReference ?? this.farReference,
      endorsementText: endorsementText ?? this.endorsementText,
      cfiName: cfiName ?? this.cfiName,
      cfiCertificateNumber: cfiCertificateNumber ?? this.cfiCertificateNumber,
      cfiExpirationDate: cfiExpirationDate ?? this.cfiExpirationDate,
      expirationDate: expirationDate ?? this.expirationDate,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
