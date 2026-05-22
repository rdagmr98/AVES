class UserProfile {
  final String id;
  final String nome;
  final String cognome;
  final String? username;
  final String? numeroLicenza;
  final int? orgUnitId;
  final String orgUnitName;
  final String role;
  final bool isApproved;
  final bool isActive;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.nome,
    required this.cognome,
    this.username,
    this.numeroLicenza,
    this.orgUnitId,
    this.orgUnitName = '',
    required this.role,
    this.isApproved = false,
    this.isActive = true,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$cognome $nome'.trim();
  bool get isAdminPriv => role == 'admin_priv';
  bool get isAdminCrew => role == 'admin_crew';
  bool get isAdmin => isAdminPriv || isAdminCrew;
  bool get isUser => role == 'user';

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] as String,
    nome: j['nome'] as String? ?? '',
    cognome: j['cognome'] as String? ?? '',
    username: j['username'] as String?,
    numeroLicenza: j['numero_licenza'] as String?,
    orgUnitId: j['org_unit_id'] as int?,
    orgUnitName:
        (j['org_units'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    role: j['role'] as String? ?? 'user',
    isApproved: j['is_approved'] as bool? ?? false,
    isActive: j['is_active'] as bool? ?? true,
    note: j['note'] as String?,
    createdAt: DateTime.parse(
      j['created_at'] as String? ?? DateTime.now().toIso8601String(),
    ),
    updatedAt: DateTime.parse(
      j['updated_at'] as String? ?? DateTime.now().toIso8601String(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'nome': nome,
    'cognome': cognome,
    'username': username,
    'numero_licenza': numeroLicenza,
    'org_unit_id': orgUnitId,
    'role': role,
    'is_approved': isApproved,
    'is_active': isActive,
    'note': note,
  };

  UserProfile copyWith({
    String? nome,
    String? cognome,
    String? username,
    String? numeroLicenza,
    int? orgUnitId,
    String? orgUnitName,
    String? role,
    bool? isApproved,
    bool? isActive,
    String? note,
  }) => UserProfile(
    id: id,
    nome: nome ?? this.nome,
    cognome: cognome ?? this.cognome,
    username: username ?? this.username,
    numeroLicenza: numeroLicenza ?? this.numeroLicenza,
    orgUnitId: orgUnitId ?? this.orgUnitId,
    orgUnitName: orgUnitName ?? this.orgUnitName,
    role: role ?? this.role,
    isApproved: isApproved ?? this.isApproved,
    isActive: isActive ?? this.isActive,
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
  final String crewType; // 'T' or 'TOB'
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
