import 'package:intl/intl.dart';

import '../models/activity_models.dart';
import 'gh_db_service.dart';
import 'notification_service.dart';

class ActivityService {
  final _db = GhDbService();
  final _notifications = NotificationService();

  Map<String, dynamic>? _findReference(String key, int? id) {
    if (id == null) {
      return null;
    }
    final values = List<Map<String, dynamic>>.from(
      (_db.referenceData[key] as List<dynamic>? ?? const []),
    );
    for (final value in values) {
      if (value['id'] == id) {
        return Map<String, dynamic>.from(value);
      }
    }
    return null;
  }

  Map<String, dynamic>? _findUser(String userId) {
    for (final user in _db.users) {
      if (user['id'] == userId) {
        return Map<String, dynamic>.from(user);
      }
    }
    return null;
  }

  DateTime _parseDate(Map<String, dynamic> item, String key) =>
      DateTime.parse(item[key] as String);

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  String _userName(String userId) {
    final user = _findUser(userId);
    final nome = user?['nome'] as String? ?? '';
    final cognome = user?['cognome'] as String? ?? '';
    final fullName = '$nome $cognome'.trim();
    return fullName.isNotEmpty ? fullName : userId;
  }

  String _helicopterLabel(int? helicopterTypeId) {
    final ref = _findReference('helicopterTypes', helicopterTypeId);
    return ref?['code'] as String? ??
        ref?['name'] as String? ??
        (helicopterTypeId?.toString() ?? 'elicottero');
  }

  String _privilegeLabel(int? privilegeTypeId) {
    final ref = _findReference('privilegeTypes', privilegeTypeId);
    return ref?['name'] as String? ?? 'privilegio';
  }

  String _tobCapabilityLabel(int? capabilityId) {
    final ref = _findReference('tobCapabilities', capabilityId);
    return ref?['name'] as String? ?? 'capacità TOB';
  }

  int _nextId(Iterable<Map<String, dynamic>> existing) {
    final ids = existing
        .map((item) => item['id'])
        .whereType<int>()
        .toSet();
    var candidate = DateTime.now().millisecondsSinceEpoch;
    while (ids.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  MaintenanceActivity _toMaintenance(Map<String, dynamic> item) =>
      MaintenanceActivity.fromJson({
        ...item,
        'helicopter_types': _findReference(
          'helicopterTypes',
          item['helicopter_type_id'] as int?,
        ),
        'privilege_types': _findReference(
          'privilegeTypes',
          item['privilege_type_id'] as int?,
        ),
        'user_profiles': _findUser(item['user_id'] as String),
      });

  FlightActivity _toFlight(Map<String, dynamic> item) => FlightActivity.fromJson({
    ...item,
    'helicopter_types': _findReference(
      'helicopterTypes',
      item['helicopter_type_id'] as int?,
    ),
    'user_profiles': _findUser(item['user_id'] as String),
  });

  TobActivity _toTob(Map<String, dynamic> item) => TobActivity.fromJson({
    ...item,
    'helicopter_types': _findReference(
      'helicopterTypes',
      item['helicopter_type_id'] as int?,
    ),
    'tob_capabilities': _findReference(
      'tobCapabilities',
      item['tob_capability_id'] as int?,
    ),
    'user_profiles': _findUser(item['user_id'] as String),
  });

  SeminarActivity _toSeminar(Map<String, dynamic> item) =>
      SeminarActivity.fromJson({
        ...item,
        'user_profiles': _findUser(item['user_id'] as String),
      });

  Future<void> addMaintenanceActivity(MaintenanceActivity act) async {
    final rows = _db.maintenanceActs;
    final now = DateTime.now().toIso8601String();
    rows.add({
      'id': _nextId(rows),
      ...act.toInsertJson(),
      'is_validated': false,
      'validated_by': null,
      'validated_at': null,
      'created_at': now,
    });
    await _db.saveMaintenanceActs(rows);
    await _notifications.notifyMaintenanceAdmins(
      type: 'MAINTENANCE_PENDING',
      message:
          'Richiesta da validare: ${_userName(act.userId)} · ${_helicopterLabel(act.helicopterTypeId)} · ${_privilegeLabel(act.privilegeTypeId)} · ${_formatDate(act.activityDate)}.',
    );
  }

  Future<void> addMaintenanceActivityValidated(
    MaintenanceActivity act,
    String adminId,
  ) async {
    final rows = _db.maintenanceActs;
    final now = DateTime.now().toIso8601String();
    rows.add({
      'id': _nextId(rows),
      ...act.toInsertJson(),
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': now,
      'created_at': now,
    });
    await _db.saveMaintenanceActs(rows);
    await _notifications.createNotification(
      userId: act.userId,
      type: 'MAINTENANCE_INSERTED_BY_ADMIN',
      message:
          'Attività manutentiva inserita e validata dall\'admin: ${_helicopterLabel(act.helicopterTypeId)} · ${_privilegeLabel(act.privilegeTypeId)} · ${_formatDate(act.activityDate)}.',
    );
  }

  Future<void> validateMaintenanceActivity(int id, String adminId) async {
    final rows = _db.maintenanceActs;
    final index = rows.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      throw Exception('Attività manutentiva non trovata');
    }
    final activity = _toMaintenance(rows[index]);
    rows[index] = {
      ...rows[index],
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveMaintenanceActs(rows);
    await _notifications.createNotification(
      userId: activity.userId,
      type: 'MAINTENANCE_VALIDATED',
      message:
          'Attività manutentiva approvata: ${_helicopterLabel(activity.helicopterTypeId)} · ${_privilegeLabel(activity.privilegeTypeId)} · ${_formatDate(activity.activityDate)}.',
    );
  }

  Future<void> rejectMaintenanceActivity(int id) async {
    final current = _db.maintenanceActs.firstWhere(
      (item) => item['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    final rows = _db.maintenanceActs.where((item) => item['id'] != id).toList();
    await _db.saveMaintenanceActs(rows);
    if (current.isNotEmpty) {
      final activity = _toMaintenance(current);
      await _notifications.createNotification(
        userId: activity.userId,
        type: 'MAINTENANCE_REJECTED',
        message:
            'Attività manutentiva non approvata: ${_helicopterLabel(activity.helicopterTypeId)} · ${_privilegeLabel(activity.privilegeTypeId)} · ${_formatDate(activity.activityDate)}.',
      );
    }
  }

  Future<List<MaintenanceActivity>> getUserMaintenanceActivities(
    String userId,
  ) async {
    final items = _db.maintenanceActs
        .where((item) => item['user_id'] == userId)
        .toList()
      ..sort(
        (a, b) => _parseDate(b, 'activity_date').compareTo(
          _parseDate(a, 'activity_date'),
        ),
      );
    return items.map(_toMaintenance).toList();
  }

  Future<List<MaintenanceActivity>> getPendingMaintenanceActivities() async {
    final items = _db.maintenanceActs
        .where((item) => item['is_validated'] != true)
        .toList()
      ..sort(
        (a, b) => DateTime.parse(
          b['created_at'] as String? ?? b['activity_date'] as String,
        ).compareTo(
          DateTime.parse(
            a['created_at'] as String? ?? a['activity_date'] as String,
          ),
        ),
      );
    return items.map(_toMaintenance).toList();
  }

  Future<MaintenanceActivity?> getLastValidatedMaintenance(String userId) async {
    final items = _db.maintenanceActs
        .where(
          (item) => item['user_id'] == userId && item['is_validated'] == true,
        )
        .toList()
      ..sort(
        (a, b) => _parseDate(b, 'activity_date').compareTo(
          _parseDate(a, 'activity_date'),
        ),
      );
    if (items.isEmpty) {
      return null;
    }
    return _toMaintenance(items.first);
  }

  Future<void> addFlightActivity(FlightActivity act) async {
    final rows = _db.flightActs;
    final now = DateTime.now().toIso8601String();
    rows.add({
      'id': _nextId(rows),
      ...act.toInsertJson(),
      'is_validated': false,
      'validated_by': null,
      'validated_at': null,
      'created_at': now,
    });
    await _db.saveFlightActs(rows);
    await _notifications.notifyCrewAdmins(
      type: 'FLIGHT_PENDING',
      message:
          'Richiesta volo da validare: ${_userName(act.userId)} · ${_helicopterLabel(act.helicopterTypeId)} · ${_formatDate(act.activityDate)}.',
    );
  }

  Future<void> addFlightActivityValidated(
    FlightActivity act,
    String adminId,
  ) async {
    final rows = _db.flightActs;
    final now = DateTime.now().toIso8601String();
    rows.add({
      'id': _nextId(rows),
      ...act.toInsertJson(),
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': now,
      'created_at': now,
    });
    await _db.saveFlightActs(rows);
    await _notifications.createNotification(
      userId: act.userId,
      type: 'FLIGHT_INSERTED_BY_ADMIN',
      message:
          'Attività di volo inserita e validata dall\'admin: ${_helicopterLabel(act.helicopterTypeId)} · ${_formatDate(act.activityDate)}.',
    );
  }

  Future<void> validateFlightActivity(int id, String adminId) async {
    final rows = _db.flightActs;
    final index = rows.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      throw Exception('Attività di volo non trovata');
    }
    final activity = _toFlight(rows[index]);
    rows[index] = {
      ...rows[index],
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveFlightActs(rows);
    await _notifications.createNotification(
      userId: activity.userId,
      type: 'FLIGHT_VALIDATED',
      message:
          'Attività di volo approvata: ${_helicopterLabel(activity.helicopterTypeId)} · ${_formatDate(activity.activityDate)}.',
    );
  }

  Future<void> rejectFlightActivity(int id) async {
    final current = _db.flightActs.firstWhere(
      (item) => item['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    final rows = _db.flightActs.where((item) => item['id'] != id).toList();
    await _db.saveFlightActs(rows);
    if (current.isNotEmpty) {
      final activity = _toFlight(current);
      await _notifications.createNotification(
        userId: activity.userId,
        type: 'FLIGHT_REJECTED',
        message:
            'Attività di volo non approvata: ${_helicopterLabel(activity.helicopterTypeId)} · ${_formatDate(activity.activityDate)}.',
      );
    }
  }

  Future<List<FlightActivity>> getUserFlightActivities(String userId) async {
    final items = _db.flightActs.where((item) => item['user_id'] == userId).toList()
      ..sort(
        (a, b) => _parseDate(b, 'activity_date').compareTo(
          _parseDate(a, 'activity_date'),
        ),
      );
    return items.map(_toFlight).toList();
  }

  Future<List<FlightActivity>> getPendingFlightActivities() async {
    final items = _db.flightActs
        .where((item) => item['is_validated'] != true)
        .toList()
      ..sort(
        (a, b) => DateTime.parse(
          b['created_at'] as String? ?? b['activity_date'] as String,
        ).compareTo(
          DateTime.parse(
            a['created_at'] as String? ?? a['activity_date'] as String,
          ),
        ),
      );
    return items.map(_toFlight).toList();
  }

  Future<double> getFlightHoursInPeriod(String userId, int periodDays) async {
    final since = DateTime.now().subtract(Duration(days: periodDays));
    return _db.flightActs
        .where(
          (item) =>
              item['user_id'] == userId &&
              item['is_validated'] == true &&
              !_parseDate(item, 'activity_date').isBefore(since),
        )
        .fold<double>(
          0.0,
          (sum, item) => sum + (item['flight_hours'] as num).toDouble(),
        );
  }

  Future<void> addTobActivity(TobActivity act) async {
    final rows = _db.tobActs;
    final now = DateTime.now().toIso8601String();
    rows.add({
      'id': _nextId(rows),
      ...act.toInsertJson(),
      'is_validated': false,
      'validated_by': null,
      'validated_at': null,
      'created_at': now,
    });
    await _db.saveTobActs(rows);
    await _notifications.notifyCrewAdmins(
      type: 'TOB_PENDING',
      message:
          'Richiesta TOB da validare: ${_userName(act.userId)} · ${_helicopterLabel(act.helicopterTypeId)} · ${_tobCapabilityLabel(act.tobCapabilityId)} · ${_formatDate(act.activityDate)}.',
    );
  }

  Future<void> addTobActivityValidated(TobActivity act, String adminId) async {
    final rows = _db.tobActs;
    final now = DateTime.now().toIso8601String();
    rows.add({
      'id': _nextId(rows),
      ...act.toInsertJson(),
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': now,
      'created_at': now,
    });
    await _db.saveTobActs(rows);
    await _notifications.createNotification(
      userId: act.userId,
      type: 'TOB_INSERTED_BY_ADMIN',
      message:
          'Attività TOB inserita e validata dall\'admin: ${_helicopterLabel(act.helicopterTypeId)} · ${_tobCapabilityLabel(act.tobCapabilityId)} · ${_formatDate(act.activityDate)}.',
    );
  }

  Future<void> validateTobActivity(int id, String adminId) async {
    final rows = _db.tobActs;
    final index = rows.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      throw Exception('Attività TOB non trovata');
    }
    final activity = _toTob(rows[index]);
    rows[index] = {
      ...rows[index],
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveTobActs(rows);
    await _notifications.createNotification(
      userId: activity.userId,
      type: 'TOB_VALIDATED',
      message:
          'Attività TOB approvata: ${_helicopterLabel(activity.helicopterTypeId)} · ${_tobCapabilityLabel(activity.tobCapabilityId)} · ${_formatDate(activity.activityDate)}.',
    );
  }

  Future<void> rejectTobActivity(int id) async {
    final current = _db.tobActs.firstWhere(
      (item) => item['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    final rows = _db.tobActs.where((item) => item['id'] != id).toList();
    await _db.saveTobActs(rows);
    if (current.isNotEmpty) {
      final activity = _toTob(current);
      await _notifications.createNotification(
        userId: activity.userId,
        type: 'TOB_REJECTED',
        message:
            'Attività TOB non approvata: ${_helicopterLabel(activity.helicopterTypeId)} · ${_tobCapabilityLabel(activity.tobCapabilityId)} · ${_formatDate(activity.activityDate)}.',
      );
    }
  }

  Future<List<TobActivity>> getUserTobActivities(String userId) async {
    final items = _db.tobActs.where((item) => item['user_id'] == userId).toList()
      ..sort(
        (a, b) => _parseDate(b, 'activity_date').compareTo(
          _parseDate(a, 'activity_date'),
        ),
      );
    return items.map(_toTob).toList();
  }

  Future<List<TobActivity>> getPendingTobActivities() async {
    final items = _db.tobActs
        .where((item) => item['is_validated'] != true)
        .toList()
      ..sort(
        (a, b) => DateTime.parse(
          b['created_at'] as String? ?? b['activity_date'] as String,
        ).compareTo(
          DateTime.parse(
            a['created_at'] as String? ?? a['activity_date'] as String,
          ),
        ),
      );
    return items.map(_toTob).toList();
  }

  Future<TobActivity?> getLastValidatedTobActivity(
    String userId,
    int capabilityId,
  ) async {
    final items = _db.tobActs
        .where(
          (item) =>
              item['user_id'] == userId &&
              item['tob_capability_id'] == capabilityId &&
              item['is_validated'] == true,
        )
        .toList()
      ..sort(
        (a, b) => _parseDate(b, 'activity_date').compareTo(
          _parseDate(a, 'activity_date'),
        ),
      );
    if (items.isEmpty) {
      return null;
    }
    return _toTob(items.first);
  }

  Future<void> addSeminarActivity(SeminarActivity act) async {
    final rows = _db.seminars;
    final now = DateTime.now().toIso8601String();
    rows.add({
      'id': _nextId(rows),
      ...act.toInsertJson(),
      'is_validated': false,
      'validated_by': null,
      'validated_at': null,
      'created_at': now,
    });
    await _db.saveSeminars(rows);
    await _notifications.notifyMaintenanceAdmins(
      type: 'SEMINAR_PENDING',
      message:
          'Seminario NAM/MHF da validare: ${_userName(act.userId)} · ${_formatDate(act.seminarDate)}.',
    );
  }

  Future<void> addSeminarActivityValidated(
    SeminarActivity act,
    String adminId,
  ) async {
    final rows = _db.seminars;
    final now = DateTime.now().toIso8601String();
    rows.add({
      'id': _nextId(rows),
      ...act.toInsertJson(),
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': now,
      'created_at': now,
    });
    await _db.saveSeminars(rows);
    await _notifications.createNotification(
      userId: act.userId,
      type: 'SEMINAR_INSERTED_BY_ADMIN',
      message:
          'Seminario NAM/MHF inserito e validato dall\'admin: ${_formatDate(act.seminarDate)}.',
    );
  }

  Future<void> validateSeminarActivity(int id, String adminId) async {
    final rows = _db.seminars;
    final index = rows.indexWhere((item) => item['id'] == id);
    if (index == -1) throw Exception('Seminario non trovato');
    final activity = _toSeminar(rows[index]);
    rows[index] = {
      ...rows[index],
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveSeminars(rows);
    await _notifications.createNotification(
      userId: activity.userId,
      type: 'SEMINAR_VALIDATED',
      message:
          'Seminario NAM/MHF approvato: ${_formatDate(activity.seminarDate)}.',
    );
  }

  Future<void> rejectSeminarActivity(int id) async {
    final current = _db.seminars.firstWhere(
      (item) => item['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    final rows = _db.seminars.where((item) => item['id'] != id).toList();
    await _db.saveSeminars(rows);
    if (current.isNotEmpty) {
      final activity = _toSeminar(current);
      await _notifications.createNotification(
        userId: activity.userId,
        type: 'SEMINAR_REJECTED',
        message:
            'Seminario NAM/MHF non approvato: ${_formatDate(activity.seminarDate)}.',
      );
    }
  }

  Future<List<SeminarActivity>> getUserSeminarActivities(String userId) async {
    final items = _db.seminars.where((item) => item['user_id'] == userId).toList()
      ..sort(
        (a, b) => _parseDate(b, 'seminar_date').compareTo(
          _parseDate(a, 'seminar_date'),
        ),
      );
    return items.map(_toSeminar).toList();
  }

  Future<List<SeminarActivity>> getPendingSeminarActivities() async {
    final items = _db.seminars
        .where((item) => item['is_validated'] != true)
        .toList()
      ..sort(
        (a, b) => DateTime.parse(
          b['created_at'] as String? ?? b['seminar_date'] as String,
        ).compareTo(
          DateTime.parse(
            a['created_at'] as String? ?? a['seminar_date'] as String,
          ),
        ),
      );
    return items.map(_toSeminar).toList();
  }

  Future<SeminarActivity?> getLastValidatedSeminar(String userId) async {
    final items = _db.seminars
        .where((item) => item['user_id'] == userId && item['is_validated'] == true)
        .toList()
      ..sort(
        (a, b) => _parseDate(b, 'seminar_date').compareTo(
          _parseDate(a, 'seminar_date'),
        ),
      );
    if (items.isEmpty) return null;
    return _toSeminar(items.first);
  }

  Future<List<SeminarActivity>> getAllSeminarActivities() async {
    final items = _db.seminars.toList()
      ..sort(
        (a, b) => DateTime.parse(
          b['created_at'] as String? ?? b['seminar_date'] as String,
        ).compareTo(
          DateTime.parse(
            a['created_at'] as String? ?? a['seminar_date'] as String,
          ),
        ),
      );
    return items.map(_toSeminar).toList();
  }

  Future<int> getPendingActivitiesCount() async {
    final maintenance = _db.maintenanceActs.where(
      (item) => item['is_validated'] != true,
    );
    final flight = _db.flightActs.where((item) => item['is_validated'] != true);
    final tob = _db.tobActs.where((item) => item['is_validated'] != true);
    final seminars = _db.seminars.where((item) => item['is_validated'] != true);
    return maintenance.length + flight.length + tob.length + seminars.length;
  }
}
