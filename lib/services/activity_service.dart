import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_models.dart';

class ActivityService {
  final _db = Supabase.instance.client;

  // ─── MAINTENANCE ──────────────────────────────────────────────────────────

  Future<void> addMaintenanceActivity(MaintenanceActivity act) async {
    await _db.from('maintenance_activities').insert(act.toInsertJson());
  }

  Future<void> addMaintenanceActivityValidated(
    MaintenanceActivity act,
    String adminId,
  ) async {
    await _db.from('maintenance_activities').insert({
      ...act.toInsertJson(),
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> validateMaintenanceActivity(int id, String adminId) async {
    await _db
        .from('maintenance_activities')
        .update({
          'is_validated': true,
          'validated_by': adminId,
          'validated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> rejectMaintenanceActivity(int id) async {
    await _db.from('maintenance_activities').delete().eq('id', id);
  }

  Future<List<MaintenanceActivity>> getUserMaintenanceActivities(
    String userId,
  ) async {
    final data = await _db
        .from('maintenance_activities')
        .select(
          '*, helicopter_types(code), privilege_types(name,sort_order), user_profiles(nome,cognome,numero_licenza)',
        )
        .eq('user_id', userId)
        .order('activity_date', ascending: false);
    return (data as List).map((e) => MaintenanceActivity.fromJson(e)).toList();
  }

  Future<List<MaintenanceActivity>> getPendingMaintenanceActivities() async {
    final data = await _db
        .from('maintenance_activities')
        .select(
          '*, helicopter_types(code), privilege_types(name,sort_order), user_profiles(nome,cognome,numero_licenza)',
        )
        .eq('is_validated', false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => MaintenanceActivity.fromJson(e)).toList();
  }

  /// Ultima attività manutentiva validata dell'utente
  Future<MaintenanceActivity?> getLastValidatedMaintenance(
    String userId,
  ) async {
    final data = await _db
        .from('maintenance_activities')
        .select('*, helicopter_types(code), privilege_types(name,sort_order)')
        .eq('user_id', userId)
        .eq('is_validated', true)
        .order('activity_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return MaintenanceActivity.fromJson(data);
  }

  // ─── FLIGHT ───────────────────────────────────────────────────────────────

  Future<void> addFlightActivity(FlightActivity act) async {
    await _db.from('flight_activities').insert(act.toInsertJson());
  }

  Future<void> addFlightActivityValidated(
    FlightActivity act,
    String adminId,
  ) async {
    await _db.from('flight_activities').insert({
      ...act.toInsertJson(),
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> validateFlightActivity(int id, String adminId) async {
    await _db
        .from('flight_activities')
        .update({
          'is_validated': true,
          'validated_by': adminId,
          'validated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> rejectFlightActivity(int id) async {
    await _db.from('flight_activities').delete().eq('id', id);
  }

  Future<List<FlightActivity>> getUserFlightActivities(String userId) async {
    final data = await _db
        .from('flight_activities')
        .select(
          '*, helicopter_types(code), user_profiles(nome,cognome,numero_licenza)',
        )
        .eq('user_id', userId)
        .order('activity_date', ascending: false);
    return (data as List).map((e) => FlightActivity.fromJson(e)).toList();
  }

  Future<List<FlightActivity>> getPendingFlightActivities() async {
    final data = await _db
        .from('flight_activities')
        .select(
          '*, helicopter_types(code), user_profiles(nome,cognome,numero_licenza)',
        )
        .eq('is_validated', false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => FlightActivity.fromJson(e)).toList();
  }

  /// Ore di volo validate nel semestre corrente (ultimi 180 gg)
  Future<double> getFlightHoursInPeriod(String userId, int periodDays) async {
    final since = DateTime.now().subtract(Duration(days: periodDays));
    final data = await _db
        .from('flight_activities')
        .select('flight_hours')
        .eq('user_id', userId)
        .eq('is_validated', true)
        .gte('activity_date', since.toIso8601String().split('T').first);
    if ((data as List).isEmpty) return 0.0;
    return data.fold<double>(
      0.0,
      (sum, e) => sum + (e['flight_hours'] as num).toDouble(),
    );
  }

  // ─── TOB ──────────────────────────────────────────────────────────────────

  Future<void> addTobActivity(TobActivity act) async {
    await _db.from('tob_activities').insert(act.toInsertJson());
  }

  Future<void> addTobActivityValidated(TobActivity act, String adminId) async {
    await _db.from('tob_activities').insert({
      ...act.toInsertJson(),
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> validateTobActivity(int id, String adminId) async {
    await _db
        .from('tob_activities')
        .update({
          'is_validated': true,
          'validated_by': adminId,
          'validated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> rejectTobActivity(int id) async {
    await _db.from('tob_activities').delete().eq('id', id);
  }

  Future<List<TobActivity>> getUserTobActivities(String userId) async {
    final data = await _db
        .from('tob_activities')
        .select(
          '*, helicopter_types(code), tob_capabilities(name), user_profiles(nome,cognome,numero_licenza)',
        )
        .eq('user_id', userId)
        .order('activity_date', ascending: false);
    return (data as List).map((e) => TobActivity.fromJson(e)).toList();
  }

  Future<List<TobActivity>> getPendingTobActivities() async {
    final data = await _db
        .from('tob_activities')
        .select(
          '*, helicopter_types(code), tob_capabilities(name), user_profiles(nome,cognome,numero_licenza)',
        )
        .eq('is_validated', false)
        .order('created_at', ascending: false);
    return (data as List).map((e) => TobActivity.fromJson(e)).toList();
  }

  Future<TobActivity?> getLastValidatedTobActivity(
    String userId,
    int capabilityId,
  ) async {
    final data = await _db
        .from('tob_activities')
        .select('*, helicopter_types(code), tob_capabilities(name)')
        .eq('user_id', userId)
        .eq('tob_capability_id', capabilityId)
        .eq('is_validated', true)
        .order('activity_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return TobActivity.fromJson(data);
  }

  // ─── PENDING COUNT ────────────────────────────────────────────────────────

  Future<int> getPendingActivitiesCount() async {
    final m = await _db
        .from('maintenance_activities')
        .select()
        .eq('is_validated', false);
    final f = await _db
        .from('flight_activities')
        .select()
        .eq('is_validated', false);
    final t = await _db
        .from('tob_activities')
        .select()
        .eq('is_validated', false);
    return (m as List).length + (f as List).length + (t as List).length;
  }
}
