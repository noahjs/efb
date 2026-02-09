class UserProfile {
  final String? id;
  final String? name;
  final String? email;
  final String? pilotName;
  final String? phoneNumber;
  final String? pilotCertificateNumber;
  final String? pilotCertificateType;
  final String? homeBase;
  final String? leidosUsername;

  const UserProfile({
    this.id,
    this.name,
    this.email,
    this.pilotName,
    this.phoneNumber,
    this.pilotCertificateNumber,
    this.pilotCertificateType,
    this.homeBase,
    this.leidosUsername,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      pilotName: json['pilot_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      pilotCertificateNumber: json['pilot_certificate_number'] as String?,
      pilotCertificateType: json['pilot_certificate_type'] as String?,
      homeBase: json['home_base'] as String?,
      leidosUsername: json['leidos_username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (pilotName != null) 'pilot_name': pilotName,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (pilotCertificateNumber != null)
        'pilot_certificate_number': pilotCertificateNumber,
      if (pilotCertificateType != null)
        'pilot_certificate_type': pilotCertificateType,
      if (homeBase != null) 'home_base': homeBase,
      if (leidosUsername != null) 'leidos_username': leidosUsername,
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? pilotName,
    String? phoneNumber,
    String? pilotCertificateNumber,
    String? pilotCertificateType,
    String? homeBase,
    String? leidosUsername,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      pilotName: pilotName ?? this.pilotName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      pilotCertificateNumber:
          pilotCertificateNumber ?? this.pilotCertificateNumber,
      pilotCertificateType: pilotCertificateType ?? this.pilotCertificateType,
      homeBase: homeBase ?? this.homeBase,
      leidosUsername: leidosUsername ?? this.leidosUsername,
    );
  }
}
