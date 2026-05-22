import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_models.dart';
import '../models/user_models.dart';
import 'activity_service.dart';

class CurrencyService {
  final _db = Supabase.instance.client;
  final _activityService = ActivityService();

  static const int warningDays = 30;

  // ─── CRITERI ──────────────────────────────────────────────────────────────

  Future<List<CurrencyCriteria>> getAllCriteria() async {
    final data = await _db
        .from('currency_criteria')
        .select('*, tob_capabilities(name)')
        .order('criteria_type')
        .order('id');
    return (data as List).map((e) => CurrencyCriteria.fromJson(e)).toList();
  }

  Future<CurrencyCriteria?> getMaintenanceCriteria() async {
    final data = await _db
        .from('currency_criteria')
        .select()
        .eq('criteria_type', 'MAINTENANCE')
        .isFilter('tob_capability_id', null)
        .maybeSingle();
    if (data == null) return null;
    return CurrencyCriteria.fromJson(data);
  }

  Future<CurrencyCriteria?> getFlightTCriteria() async {
    final data = await _db
        .from('currency_criteria')
        .select()
        .eq('criteria_type', 'FLIGHT_T')
        .isFilter('tob_capability_id', null)
        .maybeSingle();
    if (data == null) return null;
    return CurrencyCriteria.fromJson(data);
  }

  Future<CurrencyCriteria?> getTobCapabilityCriteria(
    int tobCapabilityId,
  ) async {
    final data = await _db
        .from('currency_criteria')
        .select('*, tob_capabilities(name)')
        .eq('criteria_type', 'TOB_CAPABILITY')
        .eq('tob_capability_id', tobCapabilityId)
        .maybeSingle();
    if (data == null) return null;
    return CurrencyCriteria.fromJson(data);
  }

  Future<void> updateCriteria(CurrencyCriteria c, String updatedBy) async {
    await _db
        .from('currency_criteria')
        .update({
          'period_days': c.periodDays,
          'min_hours': c.minHours,
          'updated_at': DateTime.now().toIso8601String(),
          'updated_by': updatedBy,
        })
        .eq('id', c.id!);
  }

  Future<void> updateCriteriaById(
    int id,
    int periodDays,
    double? minHours,
    String updatedBy,
  ) async {
    await _db
        .from('currency_criteria')
        .update({
          'period_days': periodDays,
          'min_hours': minHours,
          'updated_at': DateTime.now().toIso8601String(),
          'updated_by': updatedBy,
        })
        .eq('id', id);
  }

  // ─── CALCOLO CURRENCY ─────────────────────────────────────────────────────

  CurrencyStatus _computeStatus({
    required DateTime? lastDate,
    required int periodDays,
    required String label,
  }) {
    if (lastDate == null) {
      return CurrencyStatus(status: CurrencyStatusEnum.expired, label: label);
    }
    final expiry = lastDate.add(Duration(days: periodDays));
    final now = DateTime.now();
    final daysLeft = expiry.difference(now).inDays;

    late CurrencyStatusEnum st;
    if (daysLeft < 0) {
      st = CurrencyStatusEnum.expired;
    } else if (daysLeft <= warningDays) {
      st = CurrencyStatusEnum.warning;
    } else {
      st = CurrencyStatusEnum.valid;
    }

    return CurrencyStatus(
      status: st,
      lastActivityDate: lastDate,
      expiryDate: expiry,
      daysUntilExpiry: daysLeft.clamp(-9999, 9999),
      label: label,
    );
  }

  Future<CurrencyStatus> getMaintenanceCurrency(String userId) async {
    final criteria = await getMaintenanceCriteria();
    final periodDays = criteria?.periodDays ?? 180;
    final last = await _activityService.getLastValidatedMaintenance(userId);
    return _computeStatus(
      lastDate: last?.activityDate,
      periodDays: periodDays,
      label: 'Currency Manutentiva',
    );
  }

  Future<CurrencyStatus> getFlightCurrency(String userId) async {
    final criteria = await getFlightTCriteria();
    final periodDays = criteria?.periodDays ?? 180;
    final minHours = criteria?.minHours ?? 3.0;

    final hours = await _activityService.getFlightHoursInPeriod(
      userId,
      periodDays,
    );
    final hoursOk = hours >= minHours;

    // Anche calcoliamo la data dell'ultima attività validata
    final data = await _db
        .from('flight_activities')
        .select('activity_date')
        .eq('user_id', userId)
        .eq('is_validated', true)
        .order('activity_date', ascending: false)
        .limit(1)
        .maybeSingle();

    final DateTime? lastDate = data != null
        ? DateTime.parse(data['activity_date'] as String)
        : null;

    if (!hoursOk) {
      // Se le ore non sono sufficienti nel periodo, è scaduta o in warning
      return CurrencyStatus(
        status: lastDate == null
            ? CurrencyStatusEnum.expired
            : CurrencyStatusEnum.warning,
        lastActivityDate: lastDate,
        label:
            'Currency Volo (${hours.toStringAsFixed(1)}h / ${minHours.toStringAsFixed(1)}h)',
      );
    }

    return _computeStatus(
      lastDate: lastDate,
      periodDays: periodDays,
      label:
          'Currency Volo (${hours.toStringAsFixed(1)}h / ${minHours.toStringAsFixed(1)}h)',
    );
  }

  Future<CurrencyStatus> getTobCapabilityCurrencyStatus(
    String userId,
    int capabilityId,
    String capabilityName,
  ) async {
    final criteria = await getTobCapabilityCriteria(capabilityId);
    final periodDays = criteria?.periodDays ?? 90;

    final last = await _activityService.getLastValidatedTobActivity(
      userId,
      capabilityId,
    );
    return _computeStatus(
      lastDate: last?.activityDate,
      periodDays: periodDays,
      label: capabilityName,
    );
  }

  /// Mappa completa della currency per un utente
  Future<Map<String, CurrencyStatus>> getFullCurrency(
    String userId,
    List<UserTobCapability> tobCaps,
  ) async {
    final result = <String, CurrencyStatus>{};

    result['maintenance'] = await getMaintenanceCurrency(userId);

    // Cerca se ha equipaggi T
    final crews = await _db
        .from('user_crew_assignments')
        .select('crew_type')
        .eq('user_id', userId)
        .eq('active', true);
    final crewTypes = (crews as List)
        .map((c) => c['crew_type'] as String)
        .toSet();

    if (crewTypes.contains('T')) {
      result['flight_t'] = await getFlightCurrency(userId);
    }

    if (crewTypes.contains('TOB')) {
      for (final cap in tobCaps) {
        result['tob_${cap.tobCapabilityId}'] =
            await getTobCapabilityCurrencyStatus(
              userId,
              cap.tobCapabilityId,
              cap.capabilityName,
            );
      }
    }

    return result;
  }

  // ─── NOTIFICHE AUTOMATICHE ─────────────────────────────────────────────────

  Future<void> checkAndNotify(
    String userId,
    List<UserTobCapability> tobCaps,
  ) async {
    final currency = await getFullCurrency(userId, tobCaps);

    for (final entry in currency.entries) {
      final status = entry.value;
      if (status.isExpired) {
        final type = _notifType(entry.key, expired: true);
        await _upsertNotification(userId, type, status.label);
      } else if (status.isWarning) {
        final type = _notifType(entry.key, expired: false);
        await _upsertNotification(
          userId,
          type,
          status.label,
          daysLeft: status.daysUntilExpiry ?? 0,
        );
      }
    }
  }

  String _notifType(String key, {required bool expired}) {
    if (key == 'maintenance') {
      return expired ? 'MAINTENANCE_EXPIRED' : 'MAINTENANCE_EXPIRING';
    }
    if (key == 'flight_t') {
      return expired ? 'FLIGHT_EXPIRED' : 'FLIGHT_EXPIRING';
    }
    return expired ? 'TOB_EXPIRED' : 'TOB_EXPIRING';
  }

  Future<void> _upsertNotification(
    String userId,
    String type,
    String label, {
    int? daysLeft,
  }) async {
    // Evita duplicati: se esiste già una non letta dello stesso tipo, non inserire
    final existing = await _db
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('type', type)
        .eq('is_read', false)
        .limit(1)
        .maybeSingle();
    if (existing != null) return;

    final msg = daysLeft != null
        ? '⚠️ $label in scadenza tra $daysLeft giorni!'
        : '🔴 $label SCADUTA! Eseguire attività di mantenimento.';

    await _db.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'message': msg,
    });
  }
}
