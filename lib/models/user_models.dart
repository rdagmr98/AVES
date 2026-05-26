class UserProfile {
  final String id;
  final String nome;
  final String cognome;
  final String? username;
  final String? numeroLicenza;
  final String? email;
  final String? profilePhotoBase64;
  final int? orgUnitId;
  final String orgUnitName;
  final String role;
  final bool isApproved;
  final bool isApprovedMaint;
  final bool isApprovedCrew;
  final bool isActive;
  final bool isTi;
  final bool isEtp;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.nome,
    required this.cognome,
    this.username,
    this.numeroLicenza,
    this.email,
    this.profilePhotoBase64,
    this.orgUnitId,
    this.orgUnitName = '',
    required this.role,
    this.isApproved = false,
    this.isApprovedMaint = false,
    this.isApprovedCrew = false,
    this.isActive = true,
    this.isTi = false,
    this.isEtp = false,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$cognome $nome'.trim();
  bool get hasInstitutionalEmail =>
      email != null &&
      email!.trim().toLowerCase().endsWith('@esercito.difesa.it');
  bool get hasProfilePhoto =>
      profilePhotoBase64 != null && profilePhotoBase64!.trim().isNotEmpty;
  bool get isAdminPriv => role == 'admin_priv';
  bool get isAdminCrew => role == 'admin_crew';
  bool get isAdmin => isAdminPriv || isAdminCrew;
  bool get isUser => role == 'user';

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final legacyApproved = j['is_approved'] as bool? ?? false;
    final isApprovedMaint = j['is_approved_maint'] as bool? ?? legacyApproved;
    final isApprovedCrew = j['is_approved_crew'] as bool? ?? false;
    final isApproved = legacyApproved || isApprovedMaint || isApprovedCrew;

    return UserProfile(
      id: j['id'] as String,
      nome: j['nome'] as String? ?? '',
      cognome: j['cognome'] as String? ?? '',
      username: j['username'] as String?,
      numeroLicenza: j['numero_licenza'] as String?,
      email: j['email'] as String?,
      profilePhotoBase64: j['profile_photo_base64'] as String?,
      orgUnitId: j['org_unit_id'] as int?,
      orgUnitName:
          (j['org_units'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      role: j['role'] as String? ?? 'user',
      isApproved: isApproved,
      isApprovedMaint: isApprovedMaint,
      isApprovedCrew: isApprovedCrew,
      isActive: j['is_active'] as bool? ?? true,
      isTi: j['is_ti'] as bool? ?? false,
      isEtp: j['is_etp'] as bool? ?? false,
      note: j['note'] as String?,
      createdAt: DateTime.parse(
        j['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        j['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'cognome': cognome,
    'username': username,
    'numero_licenza': numeroLicenza,
    'email': email,
    'profile_photo_base64': profilePhotoBase64,
    'org_unit_id': orgUnitId,
    'role': role,
    'is_approved': isApprovedMaint || isApprovedCrew,
    'is_approved_maint': isApprovedMaint,
    'is_approved_crew': isApprovedCrew,
    'is_active': isActive,
    'is_ti': isTi,
    'is_etp': isEtp,
    'note': note,
  };

  UserProfile copyWith({
    String? nome,
    String? cognome,
    String? username,
    String? numeroLicenza,
    String? email,
    String? profilePhotoBase64,
    int? orgUnitId,
    String? orgUnitName,
    String? role,
    bool? isApproved,
    bool? isApprovedMaint,
    bool? isApprovedCrew,
    bool? isActive,
    bool? isTi,
    bool? isEtp,
    String? note,
  }) => UserProfile(
    id: id,
    nome: nome ?? this.nome,
    cognome: cognome ?? this.cognome,
    username: username ?? this.username,
    numeroLicenza: numeroLicenza ?? this.numeroLicenza,
    email: email ?? this.email,
    profilePhotoBase64: profilePhotoBase64 ?? this.profilePhotoBase64,
    orgUnitId: orgUnitId ?? this.orgUnitId,
    orgUnitName: orgUnitName ?? this.orgUnitName,
    role: role ?? this.role,
    isApproved: isApproved ?? this.isApproved,
    isApprovedMaint: isApprovedMaint ?? this.isApprovedMaint,
    isApprovedCrew: isApprovedCrew ?? this.isApprovedCrew,
    isActive: isActive ?? this.isActive,
    isTi: isTi ?? this.isTi,
    isEtp: isEtp ?? this.isEtp,
    note: note ?? this.note,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

class UserLicense {
  final int? id;
  final String userId;
  final int helicopterTypeId;
  final int licenseTypeId;
  final String? licenseNumber;
  final DateTime? expiryDate;
  final bool active;

  // Joined
  final String helicopterCode;
  final String helicopterName;
  final String licenseCode;
  final String licenseName;

  const UserLicense({
    this.id,
    required this.userId,
    required this.helicopterTypeId,
    required this.licenseTypeId,
    this.licenseNumber,
    this.expiryDate,
    this.active = true,
    this.helicopterCode = '',
    this.helicopterName = '',
    this.licenseCode = '',
    this.licenseName = '',
  });

  String get licenseTypeName => licenseName;

  factory UserLicense.fromJson(Map<String, dynamic> j) => UserLicense(
    id: j['id'] as int?,
    userId: j['user_id'] as String,
    helicopterTypeId: j['helicopter_type_id'] as int,
    licenseTypeId: j['license_type_id'] as int,
    licenseNumber: j['license_number'] as String?,
    expiryDate: j['expiry_date'] != null
        ? DateTime.parse(j['expiry_date'] as String)
        : null,
    active: j['active'] as bool? ?? true,
    helicopterCode:
        (j['helicopter_types'] as Map<String, dynamic>?)?['code'] as String? ??
        '',
    helicopterName:
        (j['helicopter_types'] as Map<String, dynamic>?)?['name'] as String? ??
        '',
    licenseCode:
        (j['license_types'] as Map<String, dynamic>?)?['code'] as String? ?? '',
    licenseName:
        (j['license_types'] as Map<String, dynamic>?)?['name'] as String? ?? '',
  );

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'helicopter_type_id': helicopterTypeId,
    'license_type_id': licenseTypeId,
    if (licenseNumber != null) 'license_number': licenseNumber,
    if (expiryDate != null)
      'expiry_date': expiryDate!.toIso8601String().split('T').first,
  };
}

class UserPrivilege {
  final int? id;
  final String userId;
  final int helicopterTypeId;
  final int privilegeTypeId;
  final DateTime? expiryDate;
  final bool active;

  final String helicopterCode;
  final String helicopterName;
  final String privilegeCode;
  final String privilegeName;
  final int sortOrder;

  const UserPrivilege({
    this.id,
    required this.userId,
    required this.helicopterTypeId,
    required this.privilegeTypeId,
    this.expiryDate,
    this.active = true,
    this.helicopterCode = '',
    this.helicopterName = '',
    this.privilegeCode = '',
    this.privilegeName = '',
    this.sortOrder = 0,
  });

  factory UserPrivilege.fromJson(Map<String, dynamic> j) => UserPrivilege(
    id: j['id'] as int?,
    userId: j['user_id'] as String,
    helicopterTypeId: j['helicopter_type_id'] as int,
    privilegeTypeId: j['privilege_type_id'] as int,
    expiryDate: j['expiry_date'] != null
        ? DateTime.parse(j['expiry_date'] as String)
        : null,
    active: j['active'] as bool? ?? true,
    helicopterCode:
        (j['helicopter_types'] as Map<String, dynamic>?)?['code'] as String? ??
        '',
    helicopterName:
        (j['helicopter_types'] as Map<String, dynamic>?)?['name'] as String? ??
        '',
    privilegeCode:
        (j['privilege_types'] as Map<String, dynamic>?)?['code'] as String? ??
        '',
    privilegeName:
        (j['privilege_types'] as Map<String, dynamic>?)?['name'] as String? ??
        '',
    sortOrder:
        (j['privilege_types'] as Map<String, dynamic>?)?['sort_order']
            as int? ??
        0,
  );

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'helicopter_type_id': helicopterTypeId,
    'privilege_type_id': privilegeTypeId,
    if (expiryDate != null)
      'expiry_date': expiryDate!.toIso8601String().split('T').first,
  };
}

class UserCrewAssignment {
  final int? id;
  final String userId;
  final int helicopterTypeId;
  final String crewType; // 'T', 'TOB' or 'MDB'
  final String? fascia; // 'A', 'B', 'C'
  final bool active;

  final String helicopterCode;
  final String helicopterName;

  const UserCrewAssignment({
    this.id,
    required this.userId,
    required this.helicopterTypeId,
    required this.crewType,
    this.fascia,
    this.active = true,
    this.helicopterCode = '',
    this.helicopterName = '',
  });

  factory UserCrewAssignment.fromJson(
    Map<String, dynamic> j,
  ) => UserCrewAssignment(
    id: j['id'] as int?,
    userId: j['user_id'] as String,
    helicopterTypeId: j['helicopter_type_id'] as int,
    crewType: j['crew_type'] as String,
    fascia: j['tob_grade'] as String?,
    active: j['active'] as bool? ?? true,
    helicopterCode:
        (j['helicopter_types'] as Map<String, dynamic>?)?['code'] as String? ??
        '',
    helicopterName:
        (j['helicopter_types'] as Map<String, dynamic>?)?['name'] as String? ??
        '',
  );

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'helicopter_type_id': helicopterTypeId,
    'crew_type': crewType,
    if (fascia != null) 'tob_grade': fascia,
  };
}

class UserTobCapability {
  final int? id;
  final String userId;
  final int helicopterTypeId;
  final int tobCapabilityId;
  final DateTime? expiryDate;
  final bool active;

  final String helicopterCode;
  final String capabilityCode;
  final String capabilityName;

  const UserTobCapability({
    this.id,
    required this.userId,
    required this.helicopterTypeId,
    required this.tobCapabilityId,
    this.expiryDate,
    this.active = true,
    this.helicopterCode = '',
    this.capabilityCode = '',
    this.capabilityName = '',
  });

  factory UserTobCapability.fromJson(
    Map<String, dynamic> j,
  ) => UserTobCapability(
    id: j['id'] as int?,
    userId: j['user_id'] as String,
    helicopterTypeId: j['helicopter_type_id'] as int,
    tobCapabilityId: j['tob_capability_id'] as int,
    expiryDate: j['expiry_date'] != null
        ? DateTime.parse(j['expiry_date'] as String)
        : null,
    active: j['active'] as bool? ?? true,
    helicopterCode:
        (j['helicopter_types'] as Map<String, dynamic>?)?['code'] as String? ??
        '',
    capabilityCode:
        (j['tob_capabilities'] as Map<String, dynamic>?)?['code'] as String? ??
        '',
    capabilityName:
        (j['tob_capabilities'] as Map<String, dynamic>?)?['name'] as String? ??
        '',
  );

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'helicopter_type_id': helicopterTypeId,
    'tob_capability_id': tobCapabilityId,
    if (expiryDate != null)
      'expiry_date': expiryDate!.toIso8601String().split('T').first,
  };
}

class AccountDeletionRequest {
  final int? id;
  final String userId;
  final String userFullName;
  final String userLicenza;
  final String? reason;
  final DateTime requestedAt;
  final String status;
  final String? handledBy;
  final DateTime? handledAt;

  const AccountDeletionRequest({
    this.id,
    required this.userId,
    required this.userFullName,
    required this.userLicenza,
    this.reason,
    required this.requestedAt,
    required this.status,
    this.handledBy,
    this.handledAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> j) =>
      AccountDeletionRequest(
        id: j['id'] as int?,
        userId: j['user_id'] as String,
        userFullName: j['user_full_name'] as String? ?? '',
        userLicenza: j['user_licenza'] as String? ?? '',
        reason: j['reason'] as String?,
        requestedAt: DateTime.parse(j['requested_at'] as String),
        status: j['status'] as String? ?? 'pending',
        handledBy: j['handled_by'] as String?,
        handledAt: j['handled_at'] != null
            ? DateTime.parse(j['handled_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'user_full_name': userFullName,
    'user_licenza': userLicenza,
    if (reason != null && reason!.trim().isNotEmpty) 'reason': reason,
    'requested_at': requestedAt.toIso8601String(),
    'status': status,
    if (handledBy != null) 'handled_by': handledBy,
    if (handledAt != null) 'handled_at': handledAt!.toIso8601String(),
  };
}
