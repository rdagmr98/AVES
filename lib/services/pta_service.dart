import '../models/activity_models.dart';
import 'gh_db_service.dart';
import 'notification_service.dart';

class PtaService {
  final _db = GhDbService();
  final _notifications = NotificationService();

  Map<String, dynamic> get referenceData => _db.referenceData;

  // ── helpers ─────────────────────────────────────────────────────────────

  int _nextId(Iterable<Map<String, dynamic>> items) {
    final ids = items.map((e) => e['id']).whereType<int>().toSet();
    var candidate = DateTime.now().millisecondsSinceEpoch % 1000000000 + 1;
    while (ids.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

  String _helicopterCode(int helicopterTypeId) {
    final types = List<Map<String, dynamic>>.from(
      (_db.referenceData['helicopterTypes'] as List<dynamic>? ?? const []),
    );
    final match = types.firstWhere(
      (t) => t['id'] == helicopterTypeId,
      orElse: () => <String, dynamic>{},
    );
    return match['code'] as String? ?? helicopterTypeId.toString();
  }

  // ── PTA CRUD ─────────────────────────────────────────────────────────────

  List<PtaRecord> getAllPta() {
    return _db.pta.map((j) => PtaRecord.fromJson(j)).toList()
      ..sort((a, b) => b.issueDate.compareTo(a.issueDate));
  }

  List<PtaRecord> getActivePta() =>
      getAllPta().where((p) => !p.isClosed).toList();

  Future<PtaRecord> createPta({
    required int helicopterTypeId,
    required String number,
    required String title,
    required DateTime issueDate,
    required String createdBy,
  }) async {
    final existing = _db.pta;
    final id = _nextId(existing);
    final now = DateTime.now();
    final record = PtaRecord(
      id: id,
      helicopterTypeId: helicopterTypeId,
      helicopterCode: _helicopterCode(helicopterTypeId),
      number: number,
      title: title,
      issueDate: issueDate,
      createdBy: createdBy,
      createdAt: now,
    );
    await _db.savePta([...existing, record.toJson()]);

    // Notify all users with privileges/licenses on this helicopter
    await _notifyAffectedUsers(record);

    return record;
  }

  Future<void> updatePta(PtaRecord record) async {
    final list = _db.pta;
    final index = list.indexWhere((item) => item['id'] == record.id);
    if (index == -1) {
      throw Exception('PTA non trovata');
    }
    list[index] = {
      ...list[index],
      ...record.toJson(),
      'helicopter_code': _helicopterCode(record.helicopterTypeId),
    };
    await _db.savePta(list);
  }

  Future<void> closePta(int ptaId) async {
    final list = _db.pta;
    final idx = list.indexWhere((e) => e['id'] == ptaId);
    if (idx == -1) return;
    final record = PtaRecord.fromJson(list[idx]);
    list[idx] = {...list[idx], 'is_closed': true};
    await _db.savePta(list);
    await _notifications.createNotifications(
      _affectedMaintenanceUserIds(record).map(
        (userId) => (
          userId: userId,
          type: 'PTA_CLOSED',
          message:
              'PTA ${record.number} su ${record.helicopterCode} chiusa. La sospensione manutentiva non è più attiva.',
        ),
      ),
    );
  }

  Future<void> deletePta(int ptaId) async {
    final list = _db.pta;
    final record = list.firstWhere(
      (item) => item['id'] == ptaId,
      orElse: () => <String, dynamic>{},
    );
    if (record.isEmpty) {
      return;
    }
    await _db.savePta(list.where((item) => item['id'] != ptaId).toList());
    await _db.savePtaAcknowledgments(
      _db.ptaAcknowledgments.where((item) => item['pta_id'] != ptaId).toList(),
    );
  }

  // ── Acknowledgments ───────────────────────────────────────────────────────

  List<PtaAcknowledgment> getAcknowledgmentsForPta(int ptaId) {
    return _db.ptaAcknowledgments
        .where((e) => e['pta_id'] == ptaId)
        .map((e) => PtaAcknowledgment.fromJson(e))
        .toList();
  }

  List<PtaAcknowledgment> getPendingAcknowledgments() {
    return _db.ptaAcknowledgments
        .where((e) => e['is_validated'] != true)
        .map((e) => PtaAcknowledgment.fromJson(e))
        .toList();
  }

  /// Returns true if user has a validated acknowledgment for this PTA.
  bool hasValidatedAck(String userId, int ptaId) {
    return _db.ptaAcknowledgments.any(
      (e) =>
          e['pta_id'] == ptaId &&
          e['user_id'] == userId &&
          e['is_validated'] == true,
    );
  }

  /// Returns true if user already submitted any acknowledgment (pending or validated).
  bool hasAck(String userId, int ptaId) {
    return _db.ptaAcknowledgments.any(
      (e) => e['pta_id'] == ptaId && e['user_id'] == userId,
    );
  }

  /// User takes acknowledgment ("preso visione").
  Future<void> acknowledgepta(
    int ptaId,
    String userId,
    String userFullName,
    String userLicenza,
  ) async {
    if (hasAck(userId, ptaId)) return; // already submitted
    final existing = _db.ptaAcknowledgments;
    final id = _nextId(existing);
    final ack = PtaAcknowledgment(
      id: id,
      ptaId: ptaId,
      userId: userId,
      userFullName: userFullName,
      userLicenza: userLicenza,
      acknowledgedAt: DateTime.now(),
    );
    await _db.savePtaAcknowledgments([...existing, ack.toJson()]);
    final pta = getAllPta().firstWhere(
      (item) => item.id == ptaId,
      orElse: () => PtaRecord(
        id: ptaId,
        helicopterTypeId: 0,
        helicopterCode: '?',
        number: 'PTA',
        title: '',
        issueDate: DateTime.now(),
        createdBy: '',
        createdAt: DateTime.now(),
      ),
    );
    await _notifications.notifyMaintenanceAdmins(
      type: 'PTA_ACK_PENDING',
      message:
          'Presa visione PTA da validare: $userFullName (${userLicenza.isNotEmpty ? userLicenza : userId}) · ${pta.number} · ${pta.helicopterCode}.',
    );
  }

  /// Admin validates a user's acknowledgment.
  Future<void> validateAcknowledgment(
    int ackId,
    String validatedBy,
  ) async {
    final list = _db.ptaAcknowledgments;
    final idx = list.indexWhere((e) => e['id'] == ackId);
    if (idx == -1) throw Exception('Presa visione non trovata');
    final acknowledgment = PtaAcknowledgment.fromJson(list[idx]);
    list[idx] = {
      ...list[idx],
      'is_validated': true,
      'validated_by': validatedBy,
      'validated_at': DateTime.now().toIso8601String(),
    };
    await _db.savePtaAcknowledgments(list);
    final pta = getAllPta().firstWhere(
      (item) => item.id == acknowledgment.ptaId,
      orElse: () => PtaRecord(
        id: acknowledgment.ptaId,
        helicopterTypeId: 0,
        helicopterCode: '?',
        number: 'PTA',
        title: '',
        issueDate: DateTime.now(),
        createdBy: '',
        createdAt: DateTime.now(),
      ),
    );
    await _notifications.createNotification(
      userId: acknowledgment.userId,
      type: 'PTA_ACK_VALIDATED',
      message:
          'Presa visione PTA validata: ${pta.number} · ${pta.helicopterCode}. I privilegi manutentivi tornano utilizzabili.',
    );
  }

  /// Returns active PTAs for which the user has license/privilege but no
  /// validated acknowledgment yet → currency is suspended.
  List<PtaRecord> getBlockingPtaForUser(String userId) {
    final activePtas = getActivePta();
    if (activePtas.isEmpty) return [];

    // Collect helicopter IDs the user is authorized on
    final userHeli = <int>{};
    for (final lic in _db.licenses) {
      if (lic['user_id'] == userId) {
        userHeli.add(lic['helicopter_type_id'] as int);
      }
    }
    for (final priv in _db.privileges) {
      if (priv['user_id'] == userId) {
        userHeli.add(priv['helicopter_type_id'] as int);
      }
    }
    if (userHeli.isEmpty) return [];

    return activePtas.where((pta) {
      if (!userHeli.contains(pta.helicopterTypeId)) return false;
      return !hasValidatedAck(userId, pta.id!);
    }).toList();
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> _notifyAffectedUsers(PtaRecord pta) async {
    final affectedUserIds = _affectedMaintenanceUserIds(pta);
    if (affectedUserIds.isEmpty) return;
    await _notifications.createNotifications(
      affectedUserIds.map(
        (uid) => (
          userId: uid,
          type: 'PTA_ISSUED',
          message:
              'Nuova PTA ${pta.number} su ${pta.helicopterCode}: "${pta.title}". Currency manutentiva sospesa fino a presa visione validata.',
        ),
      ),
    );
  }

  Set<String> _affectedMaintenanceUserIds(PtaRecord pta) {
    final affectedUserIds = <String>{};
    for (final lic in _db.licenses) {
      if (lic['helicopter_type_id'] == pta.helicopterTypeId) {
        affectedUserIds.add(lic['user_id'] as String);
      }
    }
    for (final priv in _db.privileges) {
      if (priv['helicopter_type_id'] == pta.helicopterTypeId) {
        affectedUserIds.add(priv['user_id'] as String);
      }
    }
    return affectedUserIds;
  }
}
