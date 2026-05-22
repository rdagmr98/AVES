import '../models/reference_models.dart';
import '../models/user_models.dart';
import 'gh_db_service.dart';

class UserService {
  final _db = GhDbService();

  String _normalizeUsername(String value) => value.trim().toLowerCase();

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
    final ids = existing
        .map((item) => item['id'])
        .whereType<int>()
        .toSet();
    var candidate = DateTime.now().microsecondsSinceEpoch;
    while (ids.contains(candidate)) {
      candidate++;
    }
    return candidate;
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
    String role = 'user',
  }) async {
    final users = _db.users;
    final resolvedUsername = (username ?? numeroLicenza ?? '').trim();
    if (resolvedUsername.isNotEmpty) {
      final normalizedUsername = _normalizeUsername(resolvedUsername);
      if (users.any((item) => _userUsername(item) == normalizedUsername)) {
        throw Exception('Username già registrato');
      }
    }

    final normalizedLicense = numeroLicenza?.trim().toUpperCase();
    final normalizedStoredUsername = resolvedUsername.isEmpty
        ? null
        : (role == 'user'
              ? resolvedUsername.toUpperCase()
              : resolvedUsername.trim());

    final now = DateTime.now().toIso8601String();
    final newUser = <String, dynamic>{
      'id': id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'username': normalizedStoredUsername,
      'password_hash': '',
      'nome': nome,
      'cognome': cognome,
      'numero_licenza': normalizedLicense,
      'org_unit_id': null,
      'role': role,
      'is_approved': role != 'user',
      'is_active': true,
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

    users[index] = {
      ...users[index],
      ...profile.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveUsers(users);
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
      'updated_at': DateTime.now().toIso8601String(),
      'approved_by': adminId,
    };
    await _db.saveUsers(users);

    final notifications = _db.notifications;
    final now = DateTime.now().toIso8601String();
    notifications.add({
      'id': _nextId(notifications),
      'user_id': userId,
      'type': 'PROFILE_APPROVED',
      'message':
          'Il tuo profilo è stato approvato. Puoi ora accedere a tutte le funzionalità.',
      'is_read': false,
      'created_at': now,
    });
    await _db.saveNotifications(notifications);
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
    final items = _referenceList('helicopterTypes')
        .where((item) => item['active'] != false)
        .toList()
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
    final updated = existing.where((item) => item['user_id'] != userId).toList();
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
    final updated = existing.where((item) => item['user_id'] != userId).toList();
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
    final updated = existing.where((item) => item['user_id'] != userId).toList();
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
    final updated = existing.where((item) => item['user_id'] != userId).toList();
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
