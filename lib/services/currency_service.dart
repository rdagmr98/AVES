import '../models/activity_models.dart';
import '../models/user_models.dart';
import 'activity_service.dart';
import 'gh_db_service.dart';
import 'pta_service.dart';
import 'web_notification_service.dart';

class CurrencyService {
  final _db = GhDbService();
  final _activityService = ActivityService();
  final _ptaService = PtaService();

  static const int warningDays = 30;

  Map<String, dynamic>? _findCapability(int? id) {
    if (id == null) {
      return null;
    }
    final capabilities = List<Map<String, dynamic>>.from(
      (_db.referenceData['tobCapabilities'] as List<dynamic>? ?? const []),
    );
    for (final capability in capabilities) {
      if (capability['id'] == id) {
        return Map<String, dynamic>.from(capability);
      }
    }
    return null;
  }

  int _nextNotificationId(Iterable<Map<String, dynamic>> items) {
    final ids = items.map((item) => item['id']).whereType<int>().toSet();
    var candidate = DateTime.now().millisecondsSinceEpoch;
    while (ids.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  Future<List<CurrencyCriteria>> getAllCriteria() async {
    final items = _db.criteria.map((item) {
      final capability = _findCapability(item['tob_capability_id'] as int?);
      return CurrencyCriteria.fromJson({...item, 'tob_capabilities': capability});
    }).toList()
      ..sort(
        (a, b) => ('${a.criteriaType}|${a.id ?? 0}').compareTo(
          '${b.criteriaType}|${b.id ?? 0}',
        ),
      );
    return items;
  }

  Future<CurrencyCriteria?> getMaintenanceCriteria() async {
    for (final item in _db.criteria) {
      if (item['criteria_type'] == 'MAINTENANCE' &&
          item['tob_capability_id'] == null) {
        return CurrencyCriteria.fromJson(item);
      }
    }
    return null;
  }

  Future<CurrencyCriteria?> getFlightTCriteria() async {
    for (final item in _db.criteria) {
      if (item['criteria_type'] == 'FLIGHT_T' && item['tob_capability_id'] == null) {
        return CurrencyCriteria.fromJson(item);
      }
    }
    return null;
  }

  Future<CurrencyCriteria?> getTobCapabilityCriteria(int tobCapabilityId) async {
    for (final item in _db.criteria) {
      if (item['criteria_type'] == 'TOB_CAPABILITY' &&
          item['tob_capability_id'] == tobCapabilityId) {
        return CurrencyCriteria.fromJson({
          ...item,
          'tob_capabilities': _findCapability(tobCapabilityId),
        });
      }
    }
    return null;
  }

  Future<void> updateCriteria(CurrencyCriteria c, String updatedBy) async {
    final criteria = _db.criteria;
    final index = criteria.indexWhere((item) => item['id'] == c.id);
    if (index == -1) {
      throw Exception('Criterio non trovato');
    }

    criteria[index] = {
      ...criteria[index],
      'criteria_type': c.criteriaType,
      'tob_capability_id': c.tobCapabilityId,
      'period_days': c.periodDays,
      'min_hours': c.minHours,
      'description': c.description,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': updatedBy,
    };
    await _db.saveCriteria(criteria);
  }

  Future<void> updateCriteriaById(
    int id,
    int periodDays,
    double? minHours,
    String updatedBy,
  ) async {
    final criteria = await getAllCriteria();
    final match = criteria.firstWhere(
      (item) => item.id == id,
      orElse: () => throw Exception('Criterio non trovato'),
    );
    await updateCriteria(
      CurrencyCriteria(
        id: match.id,
        criteriaType: match.criteriaType,
        tobCapabilityId: match.tobCapabilityId,
        periodDays: periodDays,
        minHours: minHours,
        description: match.description,
        tobCapabilityName: match.tobCapabilityName,
      ),
      updatedBy,
    );
  }

  CurrencyStatus _computeStatus({
    required DateTime? lastDate,
    required int periodDays,
    required String label,
  }) {
    if (lastDate == null) {
      return CurrencyStatus(status: CurrencyStatusEnum.expired, label: label);
    }

    final expiry = lastDate.add(Duration(days: periodDays));
    final daysLeft = expiry.difference(DateTime.now()).inDays;

    late final CurrencyStatusEnum status;
    if (daysLeft < 0) {
      status = CurrencyStatusEnum.expired;
    } else if (daysLeft <= warningDays) {
      status = CurrencyStatusEnum.warning;
    } else {
      status = CurrencyStatusEnum.valid;
    }

    return CurrencyStatus(
      status: status,
      lastActivityDate: lastDate,
      expiryDate: expiry,
      daysUntilExpiry: daysLeft.clamp(-9999, 9999),
      label: label,
    );
  }

  Future<CurrencyStatus> getMaintenanceCurrency(String userId) async {
    // Check if any active PTA suspends this user's currency
    final blockingPtas = _ptaService.getBlockingPtaForUser(userId);
    if (blockingPtas.isNotEmpty) {
      final ptaNumbers = blockingPtas.map((p) => p.number).join(', ');
      return CurrencyStatus(
        status: CurrencyStatusEnum.suspended,
        label: 'Currency Manutentiva — SOSPESA (PTA: $ptaNumbers)',
      );
    }

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

    final hours = await _activityService.getFlightHoursInPeriod(userId, periodDays);
    final validatedFlightActs = _db.flightActs
        .where(
          (item) => item['user_id'] == userId && item['is_validated'] == true,
        )
        .toList()
      ..sort(
        (a, b) => DateTime.parse(b['activity_date'] as String).compareTo(
          DateTime.parse(a['activity_date'] as String),
        ),
      );
    final lastDate = validatedFlightActs.isEmpty
        ? null
        : DateTime.parse(validatedFlightActs.first['activity_date'] as String);

    final label =
        'Currency Volo (${hours.toStringAsFixed(1)}h / ${minHours.toStringAsFixed(1)}h)';

    if (hours < minHours) {
      return CurrencyStatus(
        status: lastDate == null
            ? CurrencyStatusEnum.expired
            : CurrencyStatusEnum.warning,
        lastActivityDate: lastDate,
        label: label,
      );
    }

    return _computeStatus(
      lastDate: lastDate,
      periodDays: periodDays,
      label: label,
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

  Future<Map<String, CurrencyStatus>> getFullCurrency(
    String userId,
    List<UserTobCapability> tobCaps,
  ) async {
    final result = <String, CurrencyStatus>{};
    result['maintenance'] = await getMaintenanceCurrency(userId);

    final crews = _db.crew.where(
      (item) => item['user_id'] == userId && item['active'] == true,
    );
    final crewTypes = crews.map((item) => item['crew_type'] as String).toSet();

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

  Future<void> checkAndNotify(
    String userId,
    List<UserTobCapability> tobCaps,
  ) async {
    final currency = await getFullCurrency(userId, tobCaps);
    for (final entry in currency.entries) {
      final status = entry.value;
      String? message;
      if (status.isSuspended) {
        message = await _upsertNotification(
          userId,
          'MAINTENANCE_SUSPENDED',
          status.label,
        );
      } else if (status.isExpired) {
        message = await _upsertNotification(
          userId,
          _notifType(entry.key, expired: true),
          status.label,
        );
      } else if (status.isWarning) {
        message = await _upsertNotification(
          userId,
          _notifType(entry.key, expired: false),
          status.label,
          daysLeft: status.daysUntilExpiry ?? 0,
        );
      }
      if (message != null) {
        WebNotificationService.showNotification('AVES CSL', message);
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

  Future<String?> _upsertNotification(
    String userId,
    String type,
    String label, {
    int? daysLeft,
  }) async {
    final notifications = _db.notifications;
    final exists = notifications.any(
      (item) =>
          item['user_id'] == userId &&
          item['type'] == type &&
          item['is_read'] == false,
    );
    if (exists) {
      return null;
    }

    final message = daysLeft != null
        ? '⚠️ $label in scadenza tra $daysLeft giorni!'
        : '🔴 $label SCADUTA! Eseguire attività di mantenimento.';

    notifications.add({
      'id': _nextNotificationId(notifications),
      'user_id': userId,
      'type': type,
      'message': message,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _db.saveNotifications(notifications);
    return message;
  }
}
