import '../models/activity_models.dart';
import 'gh_db_service.dart';

class ActivityService {
  final _db = GhDbService();

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
  }

  Future<void> validateMaintenanceActivity(int id, String adminId) async {
    final rows = _db.maintenanceActs;
    final index = rows.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      throw Exception('Attività manutentiva non trovata');
    }
    rows[index] = {
      ...rows[index],
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveMaintenanceActs(rows);
  }

  Future<void> rejectMaintenanceActivity(int id) async {
    final rows = _db.maintenanceActs.where((item) => item['id'] != id).toList();
    await _db.saveMaintenanceActs(rows);
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
  }

  Future<void> validateFlightActivity(int id, String adminId) async {
    final rows = _db.flightActs;
    final index = rows.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      throw Exception('Attività di volo non trovata');
    }
    rows[index] = {
      ...rows[index],
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveFlightActs(rows);
  }

  Future<void> rejectFlightActivity(int id) async {
    final rows = _db.flightActs.where((item) => item['id'] != id).toList();
    await _db.saveFlightActs(rows);
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
  }

  Future<void> validateTobActivity(int id, String adminId) async {
    final rows = _db.tobActs;
    final index = rows.indexWhere((item) => item['id'] == id);
    if (index == -1) {
      throw Exception('Attività TOB non trovata');
    }
    rows[index] = {
      ...rows[index],
      'is_validated': true,
      'validated_by': adminId,
      'validated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveTobActs(rows);
  }

  Future<void> rejectTobActivity(int id) async {
    final rows = _db.tobActs.where((item) => item['id'] != id).toList();
    await _db.saveTobActs(rows);
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

  Future<int> getPendingActivitiesCount() async {
    final maintenance = _db.maintenanceActs.where(
      (item) => item['is_validated'] != true,
    );
    final flight = _db.flightActs.where((item) => item['is_validated'] != true);
    final tob = _db.tobActs.where((item) => item['is_validated'] != true);
    return maintenance.length + flight.length + tob.length;
  }
}
