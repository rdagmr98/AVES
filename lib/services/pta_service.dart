import '../models/activity_models.dart';
import 'gh_db_service.dart';
import 'web_notification_service.dart';

class PtaService {
  final _db = GhDbService();

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

  Future<void> closePta(int ptaId) async {
    final list = _db.pta;
    final idx = list.indexWhere((e) => e['id'] == ptaId);
    if (idx == -1) return;
    list[idx] = {...list[idx], 'is_closed': true};
    await _db.savePta(list);
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
  }

  /// Admin validates a user's acknowledgment.
  Future<void> validateAcknowledgment(
    int ackId,
    String validatedBy,
  ) async {
    final list = _db.ptaAcknowledgments;
    final idx = list.indexWhere((e) => e['id'] == ackId);
    if (idx == -1) throw Exception('Presa visione non trovata');
    list[idx] = {
      ...list[idx],
      'is_validated': true,
      'validated_by': validatedBy,
      'validated_at': DateTime.now().toIso8601String(),
    };
    await _db.savePtaAcknowledgments(list);
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
    // Find all approved users with licenses/privileges on this helicopter
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
    if (affectedUserIds.isEmpty) return;

    final notifications = _db.notifications;
    final now = DateTime.now().toIso8601String();
    final ids = notifications.map((e) => e['id']).whereType<int>().toSet();
    var candidate = DateTime.now().millisecondsSinceEpoch % 1000000000 + 1;

    for (final uid in affectedUserIds) {
      while (ids.contains(candidate)) {
        candidate++;
      }
      ids.add(candidate);
      notifications.add({
        'id': candidate,
        'user_id': uid,
        'type': 'PTA_ISSUED',
        'message':
            '🔴 Nuova PTA ${pta.number} su ${pta.helicopterCode}: "${pta.title}". Currency manutentiva SOSPESA fino a presa visione validata.',
        'is_read': false,
        'created_at': now,
      });
      candidate++;
    }

    await _db.saveNotifications(notifications);

    // Browser notification for current session if applicable
    WebNotificationService.showNotification(
      'AVES CSL – Nuova PTA',
      'PTA ${pta.number} su ${pta.helicopterCode}: currency sospesa.',
    );
  }
}
