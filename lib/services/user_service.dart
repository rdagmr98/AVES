import '../models/reference_models.dart';
import '../models/user_models.dart';
import 'gh_db_service.dart';
import 'notification_service.dart';

class UserService {
  final _db = GhDbService();
  final _notificationService = NotificationService();

  String _normalizeUsername(String value) => value.trim().toLowerCase();

  String? _normalizeMamlNumber(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim().toUpperCase();
    if (trimmed.isEmpty) {
      return null;
    }
    final match = RegExp(r'[A-Z]{2}\d{6}').firstMatch(trimmed);
    return match?.group(0) ?? trimmed;
  }

  String? _userUsername(Map<String, dynamic> user) {
    final username = user['username'] as String?;
    if (username != null && username.trim().isNotEmpty) {
      return _normalizeUsername(username);
    }

    final numeroLicenza = user['numero_licenza'] as String?;
    if (numeroLicenza != null && numeroLicenza.trim().isNotEmpty) {
      return _normalizeUsername(numeroLicenza);
    }

    return null;
  }

  List<Map<String, dynamic>> _referenceList(String key) =>
      List<Map<String, dynamic>>.from(
        (_db.referenceData[key] as List<dynamic>? ?? const []),
      );

  Map<String, dynamic>? _findReference(String key, int? id) {
    if (id == null) {
      return null;
    }
    final items = _referenceList(key);
    for (final item in items) {
      if (item['id'] == id) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  Map<String, dynamic> _withOrgUnit(Map<String, dynamic> user) => {
    ...user,
    'org_units': _findReference('orgUnits', user['org_unit_id'] as int?),
  };

  int _nextId(Iterable<Map<String, dynamic>> existing) {
    final ids = existing.map((item) => item['id']).whereType<int>().toSet();
    var candidate = DateTime.now().microsecondsSinceEpoch;
    while (ids.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  String _userFullNameFromMap(Map<String, dynamic> user) {
    final nome = user['nome'] as String? ?? '';
    final cognome = user['cognome'] as String? ?? '';
    final fullName = '$nome $cognome'.trim();
    return fullName.isNotEmpty ? fullName : (user['id'] as String? ?? 'Utente');
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    for (final user in _db.users) {
      if (user['id'] == userId) {
        return UserProfile.fromJson(_withOrgUnit(user));
      }
    }
    return null;
  }

  Future<UserProfile> createProfile({
    String? id,
    String? username,
    required String nome,
    required String cognome,
    String? numeroLicenza,
    String? email,
    String? profilePhotoBase64,
    String role = 'user',
  }) async {
    final users = _db.users;
    final resolvedUsername = (username ?? numeroLicenza ?? '').trim();
    final normalizedResolvedUsername = resolvedUsername.isEmpty
        ? null
        : _normalizeMamlNumber(resolvedUsername) ?? resolvedUsername;
    if (normalizedResolvedUsername != null) {
      final normalizedUsername = _normalizeUsername(normalizedResolvedUsername);
      if (users.any((item) => _userUsername(item) == normalizedUsername)) {
        throw Exception('Username già registrato');
      }
    }

    final normalizedLicense = _normalizeMamlNumber(numeroLicenza);
    final normalizedStoredUsername = resolvedUsername.isEmpty
        ? null
        : (role == 'user'
              ? (_normalizeMamlNumber(resolvedUsername) ??
                    resolvedUsername.toUpperCase())
              : resolvedUsername.trim());

    final now = DateTime.now().toIso8601String();
    final newUser = <String, dynamic>{
      'id': id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'username': normalizedStoredUsername,
      'password_hash': '',
      'nome': nome,
      'cognome': cognome,
      'numero_licenza': normalizedLicense,
      'email': email,
      'profile_photo_base64': profilePhotoBase64,
      'org_unit_id': null,
      'role': role,
      'is_approved': false,
      'is_approved_maint': false,
      'is_approved_crew': false,
      'is_active': true,
      'is_ti': false,
      'is_etp': false,
      'note': null,
      'created_at': now,
      'updated_at': now,
    };

    await _db.saveUsers([...users, newUser]);
    return UserProfile.fromJson(_withOrgUnit(newUser));
  }

  Future<void> updateProfile(UserProfile profile) async {
    final users = _db.users;
    final index = users.indexWhere((item) => item['id'] == profile.id);
    if (index == -1) {
      throw Exception('Utente non trovato');
    }

    final normalizedLicense = _normalizeMamlNumber(profile.numeroLicenza);
    final normalizedUsername = profile.username == null
        ? null
        : (profile.role == 'user'
              ? (_normalizeMamlNumber(profile.username) ??
                    profile.username!.trim().toUpperCase())
              : profile.username!.trim());

    users[index] = {
      ...users[index],
      ...profile.toJson(),
      'username': normalizedUsername,
      'numero_licenza': normalizedLicense,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveUsers(users);
  }

  Future<UserProfile> updateUserLicenseNumber({
    required String userId,
    required String newLicenseNumber,
    required String adminId,
  }) async {
    final users = _db.users;
    final admin = users.firstWhere(
      (item) => item['id'] == adminId,
      orElse: () => <String, dynamic>{},
    );
    if (admin.isEmpty) {
      throw Exception('Admin non trovato');
    }
    if ((admin['role'] as String? ?? '') != 'admin_priv') {
      throw Exception('Solo admincsl può modificare il numero licenza');
    }

    final index = users.indexWhere((item) => item['id'] == userId);
    if (index == -1) {
      throw Exception('Utente non trovato');
    }

    final targetRole = users[index]['role'] as String? ?? 'user';
    if (targetRole != 'user') {
      throw Exception(
        'Il numero licenza modificabile è solo per utenti standard',
      );
    }

    final normalizedLicense = _normalizeMamlNumber(newLicenseNumber);
    if (normalizedLicense == null) {
      throw Exception('Numero licenza non valido');
    }

    final normalizedUsername = _normalizeUsername(normalizedLicense);
    final duplicate = users.any(
      (item) =>
          (item['id'] as String?) != userId &&
          _userUsername(item) == normalizedUsername,
    );
    if (duplicate) {
      throw Exception('Numero licenza già in uso');
    }

    final previousLicense = users[index]['numero_licenza'] as String?;
    users[index] = {
      ...users[index],
      'numero_licenza': normalizedLicense,
      'username': normalizedLicense,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveUsers(users);

    final previousLabel = (previousLicense ?? '').trim();
    final previousText = previousLabel.isEmpty
        ? 'non impostato'
        : previousLabel;
    await _notificationService.createNotification(
      userId: userId,
      type: 'PROFILE_LICENSE_UPDATED',
      message:
          'Numero licenza aggiornato da $previousText a $normalizedLicense. Da ora usa questo numero per il login. La password resta invariata.',
    );

    return UserProfile.fromJson(_withOrgUnit(users[index]));
  }

  Future<void> approveUser(String userId, String adminId) async {
    final users = _db.users;
    final index = users.indexWhere((item) => item['id'] == userId);
    if (index == -1) {
      throw Exception('Utente non trovato');
    }

    users[index] = {
      ...users[index],
      'is_approved': true,
      'is_approved_maint': true,
      'is_approved_crew': true,
      'updated_at': DateTime.now().toIso8601String(),
      'approved_by': adminId,
    };
    await _db.saveUsers(users);
    await _notificationService.createNotification(
      userId: userId,
      type: 'PROFILE_APPROVED',
      message:
          'Il tuo profilo è stato approvato. Puoi ora accedere a tutte le funzionalità.',
    );
  }

  Future<void> approveMaint(String userId, String adminId) async {
    final users = _db.users;
    final index = users.indexWhere((item) => item['id'] == userId);
    if (index == -1) {
      throw Exception('Utente non trovato');
    }

    final isApprovedCrew = users[index]['is_approved_crew'] as bool? ?? false;
    users[index] = {
      ...users[index],
      'is_approved_maint': true,
      'is_approved': true,
      'updated_at': DateTime.now().toIso8601String(),
      'approved_by': adminId,
      'approved_maint_by': adminId,
    };
    await _db.saveUsers(users);

    if (!isApprovedCrew) {
      await _notificationService.createNotification(
        userId: userId,
        type: 'PROFILE_APPROVED',
        message: 'Il tuo profilo è stato approvato per la manutenzione.',
      );
    } else {
      await _notificationService.createNotification(
        userId: userId,
        type: 'PROFILE_APPROVED',
        message: 'Il tuo profilo è stato completamente approvato.',
      );
    }
  }

  Future<void> approveCrew(String userId, String adminId) async {
    final users = _db.users;
    final index = users.indexWhere((item) => item['id'] == userId);
    if (index == -1) {
      throw Exception('Utente non trovato');
    }

    final isApprovedMaint = users[index]['is_approved_maint'] as bool? ?? false;
    users[index] = {
      ...users[index],
      'is_approved_crew': true,
      'is_approved': true,
      'updated_at': DateTime.now().toIso8601String(),
      'approved_by': adminId,
      'approved_crew_by': adminId,
    };
    await _db.saveUsers(users);

    if (!isApprovedMaint) {
      await _notificationService.createNotification(
        userId: userId,
        type: 'PROFILE_APPROVED',
        message: 'Il tuo profilo è stato approvato per l\'equipaggio.',
      );
    } else {
      await _notificationService.createNotification(
        userId: userId,
        type: 'PROFILE_APPROVED',
        message: 'Il tuo profilo è stato completamente approvato.',
      );
    }
  }

  Future<void> bulkApproveMaint(List<String> userIds, String adminId) async {
    for (final userId in userIds) {
      await approveMaint(userId, adminId);
    }
  }

  Future<void> bulkApproveCrew(List<String> userIds, String adminId) async {
    for (final userId in userIds) {
      await approveCrew(userId, adminId);
    }
  }

  Future<List<AccountDeletionRequest>> getDeletionRequests({
    bool onlyPending = false,
  }) async {
    final rows =
        _db.accountDeletionRequests
            .where((item) => !onlyPending || item['status'] == 'pending')
            .map(AccountDeletionRequest.fromJson)
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return rows;
  }

  Future<AccountDeletionRequest?> getPendingDeletionRequestForUser(
    String userId,
  ) async {
    final rows = await getDeletionRequests(onlyPending: true);
    for (final request in rows) {
      if (request.userId == userId) {
        return request;
      }
    }
    return null;
  }

  Future<void> requestAccountDeletion(String userId, {String? reason}) async {
    final user = _db.users.firstWhere(
      (item) => item['id'] == userId,
      orElse: () => <String, dynamic>{},
    );
    if (user.isEmpty) {
      throw Exception('Utente non trovato');
    }
    if ((user['role'] as String? ?? '') != 'user') {
      throw Exception(
        'Solo gli utenti standard possono richiedere l\'eliminazione',
      );
    }
    if (_db.accountDeletionRequests.any(
      (item) => item['user_id'] == userId && item['status'] == 'pending',
    )) {
      throw Exception('Hai già una richiesta di eliminazione in attesa');
    }

    final requests = _db.accountDeletionRequests;
    requests.add(
      AccountDeletionRequest(
        id: _nextId(requests),
        userId: userId,
        userFullName: _userFullNameFromMap(user),
        userLicenza: user['numero_licenza'] as String? ?? '',
        reason: reason,
        requestedAt: DateTime.now(),
        status: 'pending',
      ).toJson(),
    );
    await _db.saveAccountDeletionRequests(requests);
    await _notificationService.notifyAllAdmins(
      type: 'ACCOUNT_DELETION_PENDING',
      message:
          'Richiesta eliminazione account: ${_userFullNameFromMap(user)} (${user['numero_licenza'] as String? ?? userId}).',
    );
  }

  Future<void> rejectDeletionRequest(int requestId, String adminId) async {
    final requests = _db.accountDeletionRequests;
    final index = requests.indexWhere((item) => item['id'] == requestId);
    if (index == -1) {
      throw Exception('Richiesta non trovata');
    }
    final request = AccountDeletionRequest.fromJson(requests[index]);
    requests[index] = {
      ...requests[index],
      'status': 'rejected',
      'handled_by': adminId,
      'handled_at': DateTime.now().toIso8601String(),
    };
    await _db.saveAccountDeletionRequests(requests);
    await _notificationService.createNotification(
      userId: request.userId,
      type: 'ACCOUNT_DELETION_REJECTED',
      message: 'La richiesta di eliminazione account non è stata approvata.',
    );
  }

  Future<void> approveDeletionRequest(int requestId, String adminId) async {
    final requests = _db.accountDeletionRequests;
    final index = requests.indexWhere((item) => item['id'] == requestId);
    if (index == -1) {
      throw Exception('Richiesta non trovata');
    }
    final request = AccountDeletionRequest.fromJson(requests[index]);
    requests[index] = {
      ...requests[index],
      'status': 'approved',
      'handled_by': adminId,
      'handled_at': DateTime.now().toIso8601String(),
    };
    await _db.saveAccountDeletionRequests(requests);
    await deleteUser(request.userId);
  }

  Future<void> deleteUser(String userId) async {
    final user = _db.users.firstWhere(
      (item) => item['id'] == userId,
      orElse: () => <String, dynamic>{},
    );
    if (user.isEmpty) {
      return;
    }
    if ((user['role'] as String? ?? '').startsWith('admin')) {
      throw Exception('Gli account admin non possono essere eliminati');
    }

    await _db.saveUsers(
      _db.users.where((item) => item['id'] != userId).toList(),
    );
    await _db.saveLicenses(
      _db.licenses.where((item) => item['user_id'] != userId).toList(),
    );
    await _db.savePrivileges(
      _db.privileges.where((item) => item['user_id'] != userId).toList(),
    );
    await _db.saveCrew(
      _db.crew.where((item) => item['user_id'] != userId).toList(),
    );
    await _db.saveTobUserCaps(
      _db.tobUserCaps.where((item) => item['user_id'] != userId).toList(),
    );
    await _db.saveMaintenanceActs(
      _db.maintenanceActs.where((item) => item['user_id'] != userId).toList(),
    );
    await _db.saveFlightActs(
      _db.flightActs.where((item) => item['user_id'] != userId).toList(),
    );
    await _db.saveTobActs(
      _db.tobActs.where((item) => item['user_id'] != userId).toList(),
    );
    await _db.saveNotifications(
      _db.notifications.where((item) => item['user_id'] != userId).toList(),
    );
    await _db.savePtaAcknowledgments(
      _db.ptaAcknowledgments
          .where((item) => item['user_id'] != userId)
          .toList(),
    );
    await _db.saveAccountDeletionRequests(
      _db.accountDeletionRequests
          .where((item) => item['user_id'] != userId)
          .toList(),
    );
  }

  Future<List<UserProfile>> getAllUsers() async {
    final users = _db.users
        .where((item) => item['role'] == 'user')
        .map((item) => UserProfile.fromJson(_withOrgUnit(item)))
        .toList();
    users.sort(
      (a, b) => ('${a.cognome}|${a.nome}').compareTo('${b.cognome}|${b.nome}'),
    );
    return users;
  }

  Future<List<UserProfile>> getPendingApprovalUsers() async {
    final users = _db.users
        .where((item) => item['role'] == 'user' && item['is_approved'] != true)
        .map((item) => UserProfile.fromJson(_withOrgUnit(item)))
        .toList();
    users.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return users;
  }

  Future<List<HelicopterType>> getHelicopterTypes() async {
    final items =
        _referenceList(
            'helicopterTypes',
          ).where((item) => item['active'] != false).toList()
          ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return items.map(HelicopterType.fromJson).toList();
  }

  Future<List<LicenseType>> getLicenseTypes() async {
    final items = _referenceList('licenseTypes')
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return items.map(LicenseType.fromJson).toList();
  }

  Future<List<PrivilegeType>> getPrivilegeTypes() async {
    final items = _referenceList('privilegeTypes')
      ..sort(
        (a, b) => (a['sort_order'] as int? ?? 0).compareTo(
          b['sort_order'] as int? ?? 0,
        ),
      );
    return items.map(PrivilegeType.fromJson).toList();
  }

  Future<List<TobCapability>> getTobCapabilities() async {
    final items = _referenceList('tobCapabilities')
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return items.map(TobCapability.fromJson).toList();
  }

  Future<List<OrgUnit>> getOrgUnits() async {
    final items = _referenceList('orgUnits')
      ..sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    return items.map(OrgUnit.fromJson).toList();
  }

  Future<List<UserLicense>> getUserLicenses(String userId) async {
    final rows = _db.licenses
        .where((item) => item['user_id'] == userId && item['active'] != false)
        .map(
          (item) => UserLicense.fromJson({
            ...item,
            'helicopter_types': _findReference(
              'helicopterTypes',
              item['helicopter_type_id'] as int?,
            ),
            'license_types': _findReference(
              'licenseTypes',
              item['license_type_id'] as int?,
            ),
          }),
        )
        .toList();
    rows.sort(
      (a, b) => ('${a.helicopterCode}|${a.licenseCode}').compareTo(
        '${b.helicopterCode}|${b.licenseCode}',
      ),
    );
    return rows;
  }

  Future<void> setUserLicenses(
    String userId,
    List<Map<String, dynamic>> licenses,
  ) async {
    final now = DateTime.now().toIso8601String();
    final existing = _db.licenses;
    final updated = existing
        .where((item) => item['user_id'] != userId)
        .toList();
    for (final item in licenses) {
      updated.add({
        'id': _nextId(updated),
        'user_id': userId,
        'helicopter_type_id': item['helicopter_type_id'],
        'license_type_id': item['license_type_id'],
        'license_number': item['license_number'],
        'expiry_date': item['expiry_date'],
        'active': true,
        'created_at': now,
        'updated_at': now,
      });
    }
    await _db.saveLicenses(updated);
  }

  Future<List<UserPrivilege>> getUserPrivileges(String userId) async {
    final rows = _db.privileges
        .where((item) => item['user_id'] == userId && item['active'] != false)
        .map(
          (item) => UserPrivilege.fromJson({
            ...item,
            'helicopter_types': _findReference(
              'helicopterTypes',
              item['helicopter_type_id'] as int?,
            ),
            'privilege_types': _findReference(
              'privilegeTypes',
              item['privilege_type_id'] as int?,
            ),
          }),
        )
        .toList();
    rows.sort(
      (a, b) => a.sortOrder != b.sortOrder
          ? a.sortOrder.compareTo(b.sortOrder)
          : a.helicopterCode.compareTo(b.helicopterCode),
    );
    return rows;
  }

  Future<void> setUserPrivileges(
    String userId,
    List<Map<String, dynamic>> privileges,
  ) async {
    final now = DateTime.now().toIso8601String();
    final existing = _db.privileges;
    final updated = existing
        .where((item) => item['user_id'] != userId)
        .toList();
    for (final item in privileges) {
      updated.add({
        'id': _nextId(updated),
        'user_id': userId,
        'helicopter_type_id': item['helicopter_type_id'],
        'privilege_type_id': item['privilege_type_id'],
        'expiry_date': item['expiry_date'],
        'active': true,
        'created_at': now,
        'updated_at': now,
      });
    }
    await _db.savePrivileges(updated);
  }

  Future<List<UserCrewAssignment>> getUserCrewAssignments(String userId) async {
    final rows = _db.crew
        .where((item) => item['user_id'] == userId && item['active'] != false)
        .map(
          (item) => UserCrewAssignment.fromJson({
            ...item,
            'helicopter_types': _findReference(
              'helicopterTypes',
              item['helicopter_type_id'] as int?,
            ),
          }),
        )
        .toList();
    rows.sort(
      (a, b) => ('${a.crewType}|${a.helicopterCode}').compareTo(
        '${b.crewType}|${b.helicopterCode}',
      ),
    );
    return rows;
  }

  Future<void> setUserCrewAssignments(
    String userId,
    List<Map<String, dynamic>> assignments,
  ) async {
    final now = DateTime.now().toIso8601String();
    final existing = _db.crew;
    final updated = existing
        .where((item) => item['user_id'] != userId)
        .toList();
    for (final item in assignments) {
      updated.add({
        'id': _nextId(updated),
        'user_id': userId,
        'helicopter_type_id': item['helicopter_type_id'],
        'crew_type': item['crew_type'],
        'tob_grade': item['tob_grade'],
        'active': true,
        'created_at': now,
        'updated_at': now,
      });
    }
    await _db.saveCrew(updated);
  }

  Future<List<UserTobCapability>> getUserTobCapabilities(String userId) async {
    final rows = _db.tobUserCaps
        .where((item) => item['user_id'] == userId && item['active'] != false)
        .map(
          (item) => UserTobCapability.fromJson({
            ...item,
            'helicopter_types': _findReference(
              'helicopterTypes',
              item['helicopter_type_id'] as int?,
            ),
            'tob_capabilities': _findReference(
              'tobCapabilities',
              item['tob_capability_id'] as int?,
            ),
          }),
        )
        .toList();
    rows.sort(
      (a, b) => ('${a.helicopterCode}|${a.capabilityCode}').compareTo(
        '${b.helicopterCode}|${b.capabilityCode}',
      ),
    );
    return rows;
  }

  Future<void> setUserTobCapabilities(
    String userId,
    List<Map<String, dynamic>> caps,
  ) async {
    final now = DateTime.now().toIso8601String();
    final existing = _db.tobUserCaps;
    final updated = existing
        .where((item) => item['user_id'] != userId)
        .toList();
    for (final item in caps) {
      updated.add({
        'id': _nextId(updated),
        'user_id': userId,
        'helicopter_type_id': item['helicopter_type_id'],
        'tob_capability_id': item['tob_capability_id'],
        'expiry_date': item['expiry_date'],
        'active': true,
        'created_at': now,
        'updated_at': now,
      });
    }
    await _db.saveTobUserCaps(updated);
  }

  Future<void> addUserLicense(UserLicense lic) async {
    final licenses = _db.licenses;
    final now = DateTime.now().toIso8601String();
    licenses.add({
      'id': _nextId(licenses),
      ...lic.toInsertJson(),
      'active': true,
      'created_at': now,
      'updated_at': now,
    });
    await _db.saveLicenses(licenses);
  }

  Future<void> deleteUserLicense(int id) async {
    final licenses = _db.licenses;
    final index = licenses.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      return;
    }
    licenses[index] = {
      ...licenses[index],
      'active': false,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveLicenses(licenses);
  }

  Future<void> addUserPrivilege(UserPrivilege priv) async {
    final privileges = _db.privileges;
    final now = DateTime.now().toIso8601String();
    privileges.add({
      'id': _nextId(privileges),
      ...priv.toInsertJson(),
      'active': true,
      'created_at': now,
      'updated_at': now,
    });
    await _db.savePrivileges(privileges);
  }

  Future<void> deleteUserPrivilege(int id) async {
    final privileges = _db.privileges;
    final index = privileges.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      return;
    }
    privileges[index] = {
      ...privileges[index],
      'active': false,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.savePrivileges(privileges);
  }

  Future<void> removePrivilege(
    String userId,
    int helicopterTypeId,
    int privilegeTypeId,
  ) async {
    final privileges = _db.privileges;
    var changed = false;
    for (var i = 0; i < privileges.length; i++) {
      final privilege = privileges[i];
      if (privilege['user_id'] == userId &&
          privilege['helicopter_type_id'] == helicopterTypeId &&
          privilege['privilege_type_id'] == privilegeTypeId &&
          privilege['active'] != false) {
        privileges[i] = {
          ...privilege,
          'active': false,
          'updated_at': DateTime.now().toIso8601String(),
        };
        changed = true;
      }
    }
    if (!changed) {
      return;
    }

    await _db.savePrivileges(privileges);
    final helicopter = _findReference('helicopterTypes', helicopterTypeId);
    final privilege = _findReference('privilegeTypes', privilegeTypeId);
    final helicopterLabel =
        helicopter?['code'] as String? ?? helicopter?['name'] as String? ?? '-';
    final privilegeLabel = privilege?['name'] as String? ?? 'privilegio';
    await _notificationService.createNotification(
      userId: userId,
      type: 'PRIVILEGE_REMOVED_BY_ADMIN',
      message:
          'Il privilegio $privilegeLabel su $helicopterLabel è stato rimosso dall\'amministratore.',
    );
  }

  Future<void> addUserCrewAssignment(UserCrewAssignment crew) async {
    final crews = _db.crew;
    final now = DateTime.now().toIso8601String();
    crews.add({
      'id': _nextId(crews),
      ...crew.toInsertJson(),
      'active': true,
      'created_at': now,
      'updated_at': now,
    });
    await _db.saveCrew(crews);
  }

  Future<void> deleteUserCrewAssignment(int id) async {
    final crews = _db.crew;
    final index = crews.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      return;
    }
    crews[index] = {
      ...crews[index],
      'active': false,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveCrew(crews);
  }

  Future<void> addUserTobCapability(UserTobCapability cap) async {
    final caps = _db.tobUserCaps;
    final now = DateTime.now().toIso8601String();
    caps.add({
      'id': _nextId(caps),
      ...cap.toInsertJson(),
      'active': true,
      'created_at': now,
      'updated_at': now,
    });
    await _db.saveTobUserCaps(caps);
  }

  Future<void> deleteUserTobCapability(int id) async {
    final caps = _db.tobUserCaps;
    final index = caps.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      return;
    }
    caps[index] = {
      ...caps[index],
      'active': false,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveTobUserCaps(caps);
  }
}
