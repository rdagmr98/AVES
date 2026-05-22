import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_models.dart';
import '../models/reference_models.dart';

class UserService {
  final _db = Supabase.instance.client;

  // Profilo utente
  Future<UserProfile?> getUserProfile(String userId) async {
    final data = await _db
        .from('user_profiles')
        .select('*, org_units(*)')
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> createProfile({
    required String id,
    required String nome,
    required String cognome,
    String? numeroLicenza,
  }) async {
    final data = await _db
        .from('user_profiles')
        .insert({
          'id': id,
          'nome': nome,
          'cognome': cognome,
          'numero_licenza': numeroLicenza,
          'role': 'user',
          'is_approved': false,
        })
        .select('*, org_units(*)')
        .single();
    return UserProfile.fromJson(data);
  }

  Future<void> updateProfile(UserProfile profile) async {
    await _db
        .from('user_profiles')
        .update(profile.toJson())
        .eq('id', profile.id);
  }

  Future<void> approveUser(String userId, String adminId) async {
    await _db
        .from('user_profiles')
        .update({'is_approved': true})
        .eq('id', userId);
    await _db.from('notifications').insert({
      'user_id': userId,
      'type': 'PROFILE_APPROVED',
      'message':
          'Il tuo profilo è stato approvato. Puoi ora accedere a tutte le funzionalità.',
    });
  }

  Future<List<UserProfile>> getAllUsers() async {
    final data = await _db
        .from('user_profiles')
        .select('*, org_units(*)')
        .eq('role', 'user')
        .order('cognome');
    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<List<UserProfile>> getPendingApprovalUsers() async {
    final data = await _db
        .from('user_profiles')
        .select('*, org_units(*)')
        .eq('role', 'user')
        .eq('is_approved', false)
        .order('created_at');
    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  // Referenze
  Future<List<HelicopterType>> getHelicopterTypes() async {
    final data = await _db
        .from('helicopter_types')
        .select()
        .eq('active', true)
        .order('id');
    return (data as List).map((e) => HelicopterType.fromJson(e)).toList();
  }

  Future<List<LicenseType>> getLicenseTypes() async {
    final data = await _db.from('license_types').select().order('id');
    return (data as List).map((e) => LicenseType.fromJson(e)).toList();
  }

  Future<List<PrivilegeType>> getPrivilegeTypes() async {
    final data = await _db.from('privilege_types').select().order('sort_order');
    return (data as List).map((e) => PrivilegeType.fromJson(e)).toList();
  }

  Future<List<TobCapability>> getTobCapabilities() async {
    final data = await _db.from('tob_capabilities').select().order('id');
    return (data as List).map((e) => TobCapability.fromJson(e)).toList();
  }

  Future<List<OrgUnit>> getOrgUnits() async {
    final data = await _db.from('org_units').select().order('id');
    return (data as List).map((e) => OrgUnit.fromJson(e)).toList();
  }

  // Licenze utente
  Future<List<UserLicense>> getUserLicenses(String userId) async {
    final data = await _db
        .from('user_licenses')
        .select('*, helicopter_types(*), license_types(*)')
        .eq('user_id', userId)
        .eq('active', true);
    return (data as List).map((e) => UserLicense.fromJson(e)).toList();
  }

  Future<void> setUserLicenses(
    String userId,
    List<Map<String, dynamic>> licenses,
  ) async {
    await _db.from('user_licenses').delete().eq('user_id', userId);
    if (licenses.isNotEmpty) {
      final rows = licenses
          .map(
            (l) => {
              'user_id': userId,
              'helicopter_type_id': l['helicopter_type_id'],
              'license_type_id': l['license_type_id'],
            },
          )
          .toList();
      await _db.from('user_licenses').insert(rows);
    }
  }

  // Privilegi utente
  Future<List<UserPrivilege>> getUserPrivileges(String userId) async {
    final data = await _db
        .from('user_privileges')
        .select('*, helicopter_types(*), privilege_types(*)')
        .eq('user_id', userId)
        .eq('active', true);
    return (data as List).map((e) => UserPrivilege.fromJson(e)).toList();
  }

  Future<void> setUserPrivileges(
    String userId,
    List<Map<String, dynamic>> privileges,
  ) async {
    await _db.from('user_privileges').delete().eq('user_id', userId);
    if (privileges.isNotEmpty) {
      final rows = privileges
          .map(
            (p) => {
              'user_id': userId,
              'helicopter_type_id': p['helicopter_type_id'],
              'privilege_type_id': p['privilege_type_id'],
            },
          )
          .toList();
      await _db.from('user_privileges').insert(rows);
    }
  }

  // Equipaggi fissi
  Future<List<UserCrewAssignment>> getUserCrewAssignments(String userId) async {
    final data = await _db
        .from('user_crew_assignments')
        .select('*, helicopter_types(*)')
        .eq('user_id', userId)
        .eq('active', true);
    return (data as List).map((e) => UserCrewAssignment.fromJson(e)).toList();
  }

  Future<void> setUserCrewAssignments(
    String userId,
    List<Map<String, dynamic>> assignments,
  ) async {
    await _db.from('user_crew_assignments').delete().eq('user_id', userId);
    if (assignments.isNotEmpty) {
      final rows = assignments
          .map(
            (a) => {
              'user_id': userId,
              'helicopter_type_id': a['helicopter_type_id'],
              'crew_type': a['crew_type'],
              'tob_grade': a['tob_grade'],
            },
          )
          .toList();
      await _db.from('user_crew_assignments').insert(rows);
    }
  }

  // Capacità TOB
  Future<List<UserTobCapability>> getUserTobCapabilities(String userId) async {
    final data = await _db
        .from('user_tob_capabilities')
        .select('*, helicopter_types(*), tob_capabilities(*)')
        .eq('user_id', userId)
        .eq('active', true);
    return (data as List).map((e) => UserTobCapability.fromJson(e)).toList();
  }

  Future<void> setUserTobCapabilities(
    String userId,
    List<Map<String, dynamic>> caps,
  ) async {
    await _db.from('user_tob_capabilities').delete().eq('user_id', userId);
    if (caps.isNotEmpty) {
      final rows = caps
          .map(
            (c) => {
              'user_id': userId,
              'helicopter_type_id': c['helicopter_type_id'],
              'tob_capability_id': c['tob_capability_id'],
            },
          )
          .toList();
      await _db.from('user_tob_capabilities').insert(rows);
    }
  }

  // ─── INDIVIDUAL CRUD ───────────────────────────────────────────────────────

  Future<void> addUserLicense(UserLicense lic) async {
    await _db.from('user_licenses').insert(lic.toInsertJson());
  }

  Future<void> deleteUserLicense(int id) async {
    await _db.from('user_licenses').delete().eq('id', id);
  }

  Future<void> addUserPrivilege(UserPrivilege priv) async {
    await _db.from('user_privileges').insert(priv.toInsertJson());
  }

  Future<void> deleteUserPrivilege(int id) async {
    await _db.from('user_privileges').delete().eq('id', id);
  }

  Future<void> addUserCrewAssignment(UserCrewAssignment crew) async {
    await _db.from('user_crew_assignments').insert(crew.toInsertJson());
  }

  Future<void> deleteUserCrewAssignment(int id) async {
    await _db.from('user_crew_assignments').delete().eq('id', id);
  }

  Future<void> addUserTobCapability(UserTobCapability cap) async {
    await _db.from('user_tob_capabilities').insert(cap.toInsertJson());
  }

  Future<void> deleteUserTobCapability(int id) async {
    await _db.from('user_tob_capabilities').delete().eq('id', id);
  }
}
