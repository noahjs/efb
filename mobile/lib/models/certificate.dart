class Certificate {
  final int? id;
  final String? certificateType;
  final String? certificateClass;
  final String? certificateNumber;
  final String? issueDate;
  final String? expirationDate;
  final String? ratings;
  final String? limitations;
  final String? comments;
  final String? createdAt;
  final String? updatedAt;

  const Certificate({
    this.id,
    this.certificateType,
    this.certificateClass,
    this.certificateNumber,
    this.issueDate,
    this.expirationDate,
    this.ratings,
    this.limitations,
    this.comments,
    this.createdAt,
    this.updatedAt,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      id: json['id'] as int?,
      certificateType: json['certificate_type'] as String?,
      certificateClass: json['certificate_class'] as String?,
      certificateNumber: json['certificate_number'] as String?,
      issueDate: json['issue_date'] as String?,
      expirationDate: json['expiration_date'] as String?,
      ratings: json['ratings'] as String?,
      limitations: json['limitations'] as String?,
      comments: json['comments'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'certificate_type': certificateType,
      'certificate_class': certificateClass,
      'certificate_number': certificateNumber,
      'issue_date': issueDate,
      'expiration_date': expirationDate,
      'ratings': ratings,
      'limitations': limitations,
      'comments': comments,
    };
  }

  Certificate copyWith({
    int? id,
    String? certificateType,
    String? certificateClass,
    String? certificateNumber,
    String? issueDate,
    String? expirationDate,
    String? ratings,
    String? limitations,
    String? comments,
    String? createdAt,
    String? updatedAt,
  }) {
    return Certificate(
      id: id ?? this.id,
      certificateType: certificateType ?? this.certificateType,
      certificateClass: certificateClass ?? this.certificateClass,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      issueDate: issueDate ?? this.issueDate,
      expirationDate: expirationDate ?? this.expirationDate,
      ratings: ratings ?? this.ratings,
      limitations: limitations ?? this.limitations,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
