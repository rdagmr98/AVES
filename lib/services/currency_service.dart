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
  static const String _adminPrivNotificationUserId = 'admin_priv_001';

  int _nextNotificationId(Iterable<Map<String, dynamic>> items) {
    final ids = items.map((item) => item['id']).whereType<int>().toSet();
    var candidate = DateTime.now().millisecondsSinceEpoch;
    while (ids.contains(candidate)) {
      candidate++;
    }
    return candidate;
  }

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

  Map<String, dynamic>? _findReference(String key, Object? id) {
    if (id == null) {
      return null;
    }
    final items = List<Map<String, dynamic>>.from(
      (_db.referenceData[key] as List<dynamic>? ?? const []),
    );
    for (final item in items) {
      if (item['id'] == id) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  String _userFullName(String userId) {
    for (final user in _db.users) {
      if (user['id'] != userId) {
        continue;
      }
      final nome = user['nome'] as String? ?? '';
      final cognome = user['cognome'] as String? ?? '';
      final fullName = '$nome $cognome'.trim();
      return fullName.isEmpty ? userId : fullName;
    }
    return userId;
  }

  int _compareByExpiry(CurrencyStatus a, CurrencyStatus b) {
    final aDate = a.expiryDate;
    final bDate = b.expiryDate;
    if (aDate == null && bDate == null) {
      return a.label.compareTo(b.label);
    }
    if (aDate == null) {
      return 1;
    }
    if (bDate == null) {
      return -1;
    }
    return aDate.compareTo(bDate);
  }

  CurrencyStatus _summarizeMaintenanceStatus(
    List<PrivilegeCurrencyStatus> perPrivilegeStatuses,
    CurrencyStatus fallback,
  ) {
    if (perPrivilegeStatuses.isEmpty) {
      return fallback;
    }

    final expired =
        perPrivilegeStatuses.where((item) => item.status.isExpired).toList()
          ..sort((a, b) => _compareByExpiry(a.status, b.status));
    if (expired.isNotEmpty) {
      final target = expired.first;
      return CurrencyStatus(
        status: CurrencyStatusEnum.expired,
        lastActivityDate: target.status.lastActivityDate,
        expiryDate: target.status.expiryDate,
        daysUntilExpiry: target.status.daysUntilExpiry,
        label:
            'Currency Manutentiva — ${target.helicopterCode} · ${target.privilegeName} scaduto',
      );
    }

    final warning =
        perPrivilegeStatuses.where((item) => item.status.isWarning).toList()
          ..sort((a, b) => _compareByExpiry(a.status, b.status));
    if (warning.isNotEmpty) {
      final target = warning.first;
      return CurrencyStatus(
        status: CurrencyStatusEnum.warning,
        lastActivityDate: target.status.lastActivityDate,
        expiryDate: target.status.expiryDate,
        daysUntilExpiry: target.status.daysUntilExpiry,
        label:
            'Currency Manutentiva — ${target.helicopterCode} · ${target.privilegeName} in scadenza',
      );
    }

    final valid = perPrivilegeStatuses.map((item) => item.status).toList()
      ..sort(_compareByExpiry);
    final nearest = valid.isEmpty ? fallback : valid.first;
    return CurrencyStatus(
      status: CurrencyStatusEnum.valid,
      lastActivityDate: nearest.lastActivityDate,
      expiryDate: nearest.expiryDate,
      daysUntilExpiry: nearest.daysUntilExpiry,
      label: 'Currency Manutentiva',
    );
  }

  Future<List<CurrencyCriteria>> getAllCriteria() async {
    final items =
        _db.criteria.map((item) {
          final capability = _findCapability(item['tob_capability_id'] as int?);
          return CurrencyCriteria.fromJson({
            ...item,
            'tob_capabilities': capability,
          });
        }).toList()..sort(
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
      if (item['criteria_type'] == 'FLIGHT_T' &&
          item['tob_capability_id'] == null) {
        return CurrencyCriteria.fromJson(item);
      }
    }
    return null;
  }

  Future<CurrencyCriteria?> getTobCapabilityCriteria(
    int tobCapabilityId,
  ) async {
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
      'period_days_a': c.periodDaysA,
      'period_days_bc': c.periodDaysBC,
      'min_hours': c.minHours,
      'min_count': c.minCount,
      'description': c.description,
      'updated_at': DateTime.now().toIso8601String(),
      'updated_by': updatedBy,
    };
    await _db.saveCriteria(criteria);
  }

  Future<CurrencyCriteria?> updateCriteriaById(
    int id,
    int periodDays,
    int? periodDaysA,
    int? periodDaysBC,
    double? minHours,
    String updatedBy,
  ) async {
    final criteria = await getAllCriteria();
    final match = criteria.firstWhere(
      (item) => item.id == id,
      orElse: () => throw Exception('Criterio non trovato'),
    );
    final updated = CurrencyCriteria(
      id: match.id,
      criteriaType: match.criteriaType,
      tobCapabilityId: match.tobCapabilityId,
      periodDays: periodDays,
      periodDaysA: periodDaysA,
      periodDaysBC: periodDaysBC,
      minHours: minHours,
      minCount: match.minCount,
      description: match.description,
      tobCapabilityName: match.tobCapabilityName,
    );
    await updateCriteria(updated, updatedBy);
    return updated;
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
    final hasMaintenanceQualification =
        _db.licenses.any((item) => item['user_id'] == userId) ||
        _db.privileges.any((item) => item['user_id'] == userId);
    if (!hasMaintenanceQualification) {
      return const CurrencyStatus(
        status: CurrencyStatusEnum.noData,
        label: 'Nessun privilegio manutentivo assegnato',
      );
    }

    final blockingPtas = _ptaService.getBlockingPtaForUser(userId);
    if (blockingPtas.isNotEmpty) {
      final ptaNumbers = blockingPtas.map((p) => p.number).join(', ');
      return CurrencyStatus(
        status: CurrencyStatusEnum.suspended,
        label: 'Currency Manutentiva — SOSPESA (PTA: $ptaNumbers)',
      );
    }

    const seminarPeriodDays = 730;
    final lastSeminar = await _activityService.getLastValidatedSeminar(userId);
    if (lastSeminar == null) {
      return const CurrencyStatus(
        status: CurrencyStatusEnum.expired,
        label:
            'Currency Manutentiva – NO GO (nessun seminario NAM/MHF registrato)',
      );
    }

    final seminarExpiry = lastSeminar.seminarDate.add(
      const Duration(days: seminarPeriodDays),
    );
    final seminarDaysLeft = seminarExpiry.difference(DateTime.now()).inDays;
    if (seminarDaysLeft < 0) {
      return CurrencyStatus(
        status: CurrencyStatusEnum.expired,
        label: 'Currency Manutentiva – seminario NAM/MHF scaduto',
        lastActivityDate: lastSeminar.seminarDate,
        expiryDate: seminarExpiry,
        daysUntilExpiry: seminarDaysLeft.clamp(-9999, 9999),
      );
    }

    final criteria = await getMaintenanceCriteria();
    final periodDays = criteria?.periodDays ?? 180;
    final last = await _activityService.getLastValidatedMaintenance(userId);
    final fallbackStatus = _computeStatus(
      lastDate: last?.effectiveDate,
      periodDays: periodDays,
      label: 'Currency Manutentiva',
    );
    final perPrivilegeStatuses = await getPerPrivilegeCurrency(userId);
    final taskStatus = _summarizeMaintenanceStatus(
      perPrivilegeStatuses,
      fallbackStatus,
    );

    if (taskStatus.isExpired) {
      return CurrencyStatus(
        status: taskStatus.status,
        lastActivityDate: taskStatus.lastActivityDate,
        expiryDate: taskStatus.expiryDate,
        secondaryExpiryDate: seminarExpiry,
        secondaryExpiryLabel: 'Sem. scad.',
        daysUntilExpiry: taskStatus.daysUntilExpiry,
        label: taskStatus.label,
      );
    }

    if (seminarDaysLeft <= warningDays) {
      final seminarWarning = CurrencyStatus(
        status: CurrencyStatusEnum.warning,
        lastActivityDate: lastSeminar.seminarDate,
        expiryDate: taskStatus.expiryDate,
        secondaryExpiryDate: seminarExpiry,
        secondaryExpiryLabel: 'Sem. scad.',
        daysUntilExpiry: seminarDaysLeft,
        label: 'Currency Manutentiva – seminario NAM/MHF in scadenza',
      );
      if (taskStatus.isValid) {
        return seminarWarning;
      }
      final taskExpiry = taskStatus.expiryDate;
      if (taskExpiry == null || seminarExpiry.isBefore(taskExpiry)) {
        return seminarWarning;
      }
    }

    return CurrencyStatus(
      status: taskStatus.status,
      lastActivityDate: taskStatus.lastActivityDate,
      expiryDate: taskStatus.expiryDate,
      secondaryExpiryDate: seminarExpiry,
      secondaryExpiryLabel: 'Sem. scad.',
      daysUntilExpiry: taskStatus.daysUntilExpiry,
      label: taskStatus.label,
    );
  }

  Future<List<PrivilegeCurrencyStatus>> getPerPrivilegeCurrency(
    String userId,
  ) async {
    final result = <PrivilegeCurrencyStatus>[];
    final userPrivileges = _db.privileges
        .where((p) => p['user_id'] == userId && p['active'] != false)
        .toList();

    final criteria = await getMaintenanceCriteria();
    final periodDays = criteria?.periodDays ?? 180;

    for (final priv in userPrivileges) {
      final helicopterTypeId = priv['helicopter_type_id'] as int?;
      final privilegeTypeId = priv['privilege_type_id'] as int?;
      if (helicopterTypeId == null || privilegeTypeId == null) {
        continue;
      }

      final heli =
          _findReference('helicopterTypes', helicopterTypeId) ??
          const {'code': '?', 'name': '?'};
      final privType =
          _findReference('privilegeTypes', privilegeTypeId) ??
          const {'name': '?'};

      final acts =
          _db.maintenanceActs
              .where(
                (a) =>
                    a['user_id'] == userId &&
                    a['is_validated'] == true &&
                    a['helicopter_type_id'] == helicopterTypeId &&
                    ((a['privilege_type_id'] as int?) == privilegeTypeId ||
                        a['privilege_type_id'] == null),
              )
              .toList()
            ..sort((a, b) {
              final aEffective = a['date_to'] != null
                  ? DateTime.parse(a['date_to'] as String)
                  : DateTime.parse(a['activity_date'] as String);
              final bEffective = b['date_to'] != null
                  ? DateTime.parse(b['date_to'] as String)
                  : DateTime.parse(b['activity_date'] as String);
              return bEffective.compareTo(aEffective);
            });

      final lastDate = acts.isEmpty
          ? null
          : (acts.first['date_to'] != null
                ? DateTime.parse(acts.first['date_to'] as String)
                : DateTime.parse(acts.first['activity_date'] as String));

      result.add(
        PrivilegeCurrencyStatus(
          helicopterTypeId: helicopterTypeId,
          helicopterCode: heli['code'] as String? ?? '?',
          privilegeTypeId: privilegeTypeId,
          privilegeName: privType['name'] as String? ?? '?',
          status: _computeStatus(
            lastDate: lastDate,
            periodDays: periodDays,
            label: '${heli['code']} · ${privType['name']}',
          ),
        ),
      );
    }

    result.sort(
      (a, b) => ('${a.helicopterCode}|${a.privilegeName}').compareTo(
        '${b.helicopterCode}|${b.privilegeName}',
      ),
    );
    return result;
  }

  Future<CurrencyStatus> getFlightCurrency(String userId) async {
    final criteria = await getFlightTCriteria();
    final periodDays = criteria?.periodDays ?? 180;
    final minHours = criteria?.minHours ?? 3.0;

    final hours = await _activityService.getFlightHoursInPeriod(
      userId,
      periodDays,
    );
    final validatedFlightActs =
        _db.flightActs
            .where(
              (item) =>
                  item['user_id'] == userId && item['is_validated'] == true,
            )
            .toList()
          ..sort(
            (a, b) => DateTime.parse(
              b['activity_date'] as String,
            ).compareTo(DateTime.parse(a['activity_date'] as String)),
          );
    final lastDate = validatedFlightActs.isEmpty
        ? null
        : DateTime.parse(validatedFlightActs.first['activity_date'] as String);

    final label =
        'Currency Volo (${hours.toStringAsFixed(1)}h / ${minHours.toStringAsFixed(1)}h)';

    final expiryDate = lastDate?.add(Duration(days: periodDays));
    final daysLeft = expiryDate?.difference(DateTime.now()).inDays;

    if (hours < minHours) {
      return CurrencyStatus(
        status: lastDate == null
            ? CurrencyStatusEnum.expired
            : CurrencyStatusEnum.warning,
        lastActivityDate: lastDate,
        expiryDate: expiryDate,
        daysUntilExpiry: daysLeft?.clamp(-9999, 9999),
        label: label,
        flightHours: hours,
        minFlightHours: minHours,
      );
    }

    final status = _computeStatus(
      lastDate: lastDate,
      periodDays: periodDays,
      label: label,
    );
    return CurrencyStatus(
      status: status.status,
      lastActivityDate: status.lastActivityDate,
      expiryDate: status.expiryDate,
      daysUntilExpiry: status.daysUntilExpiry,
      label: status.label,
      flightHours: hours,
      minFlightHours: minHours,
    );
  }

  Future<CurrencyCriteria?> getTobBaseCriteria() async {
    for (final item in _db.criteria) {
      if (item['criteria_type'] == 'TOB_BASE') {
        return CurrencyCriteria.fromJson(item);
      }
    }
    return null;
  }

  Future<CurrencyCriteria?> getMdbFlightCriteria() async {
    for (final item in _db.criteria) {
      if (item['criteria_type'] == 'MDB_FLIGHT') {
        return CurrencyCriteria.fromJson(item);
      }
    }
    return null;
  }

  Future<CurrencyCriteria?> getMdbPoligonoCriteria() async {
    for (final item in _db.criteria) {
      if (item['criteria_type'] == 'MDB_POLIGONO') {
        return CurrencyCriteria.fromJson(item);
      }
    }
    return null;
  }

  Future<CurrencyStatus> getTobBaseCurrency(
    String userId,
    String? fascia,
  ) async {
    final criteria = await getTobBaseCriteria();
    final periodDays =
        criteria?.periodForFascia(fascia) ?? (fascia == 'A' ? 90 : 120);

    // TOB base uses any validated flight activity
    final validatedFlights =
        _db.flightActs
            .where(
              (item) =>
                  item['user_id'] == userId && item['is_validated'] == true,
            )
            .toList()
          ..sort(
            (a, b) => DateTime.parse(
              b['activity_date'] as String,
            ).compareTo(DateTime.parse(a['activity_date'] as String)),
          );
    final lastDate = validatedFlights.isEmpty
        ? null
        : DateTime.parse(validatedFlights.first['activity_date'] as String);

    return _computeStatus(
      lastDate: lastDate,
      periodDays: periodDays,
      label: 'Currency Base TOB (fascia ${fascia ?? '-'})',
    );
  }

  Future<CurrencyStatus> getTobCapabilityCurrencyStatus(
    String userId,
    int helicopterTypeId,
    int capabilityId,
    String capabilityName, {
    String? fascia,
  }) async {
    final criteria = await getTobCapabilityCriteria(capabilityId);

    // If capability is N/A for this fascia, return noData
    if (fascia != null && (criteria?.isNAForFascia(fascia) ?? false)) {
      return CurrencyStatus(
        status: CurrencyStatusEnum.noData,
        label: '$capabilityName (N/A fascia $fascia)',
      );
    }

    final periodDays =
        criteria?.periodForFascia(fascia) ?? criteria?.periodDays ?? 90;
    final last = await _activityService.getLastValidatedTobActivity(
      userId,
      capabilityId,
      helicopterTypeId: helicopterTypeId,
    );

    return _computeStatus(
      lastDate: last?.activityDate,
      periodDays: periodDays,
      label: capabilityName,
    );
  }

  Future<CurrencyStatus> getMdbCurrency(
    String userId,
    List<UserCrewAssignment> crewAssignments,
  ) async {
    if (!crewAssignments.any((item) => item.crewType == 'MDB')) {
      return const CurrencyStatus(
        status: CurrencyStatusEnum.noData,
        label: 'Nessuna assegnazione Mitragliere di Bordo',
      );
    }

    final flightCriteria = await getMdbFlightCriteria();
    final poligonoCriteria = await getMdbPoligonoCriteria();
    final flightPeriodDays = flightCriteria?.periodDays ?? 180;
    final minHours = flightCriteria?.minHours ?? 3.0;
    final poligonoPeriodDays = poligonoCriteria?.periodDays ?? 365;
    final minPoligonoCount = poligonoCriteria?.minCount ?? 1;

    final flightHours = await _activityService.getFlightHoursInPeriod(
      userId,
      flightPeriodDays,
    );
    final validatedFlights =
        _db.flightActs
            .where(
              (item) =>
                  item['user_id'] == userId && item['is_validated'] == true,
            )
            .toList()
          ..sort(
            (a, b) => DateTime.parse(
              b['activity_date'] as String,
            ).compareTo(DateTime.parse(a['activity_date'] as String)),
          );
    final lastFlightDate = validatedFlights.isEmpty
        ? null
        : DateTime.parse(validatedFlights.first['activity_date'] as String);

    final flightLabel =
        'Mitragliere di Bordo (${flightHours.toStringAsFixed(1)}h / ${minHours.toStringAsFixed(1)}h)';
    final flightExpiry = lastFlightDate?.add(Duration(days: flightPeriodDays));
    final flightDaysLeft = flightExpiry?.difference(DateTime.now()).inDays;
    final flightStatus = flightHours < minHours
        ? CurrencyStatus(
            status: lastFlightDate == null
                ? CurrencyStatusEnum.expired
                : CurrencyStatusEnum.warning,
            lastActivityDate: lastFlightDate,
            expiryDate: flightExpiry,
            daysUntilExpiry: flightDaysLeft?.clamp(-9999, 9999),
            label: flightLabel,
            flightHours: flightHours,
            minFlightHours: minHours,
          )
        : CurrencyStatus(
            status: _computeStatus(
              lastDate: lastFlightDate,
              periodDays: flightPeriodDays,
              label: flightLabel,
            ).status,
            lastActivityDate: lastFlightDate,
            expiryDate: flightExpiry,
            daysUntilExpiry: flightDaysLeft?.clamp(-9999, 9999),
            label: flightLabel,
            flightHours: flightHours,
            minFlightHours: minHours,
          );

    final poligonoSince = DateTime.now().subtract(
      Duration(days: poligonoPeriodDays),
    );
    final poligonoActs =
        _db.flightActs
            .where(
              (item) =>
                  item['user_id'] == userId &&
                  item['is_validated'] == true &&
                  item['is_poligono'] == true,
            )
            .toList()
          ..sort(
            (a, b) => DateTime.parse(
              b['activity_date'] as String,
            ).compareTo(DateTime.parse(a['activity_date'] as String)),
          );
    final recentPoligonoActs = poligonoActs.where(
      (item) => !DateTime.parse(
        item['activity_date'] as String,
      ).isBefore(poligonoSince),
    );
    final poligonoCount = recentPoligonoActs.length;
    final lastPoligonoDate = poligonoActs.isEmpty
        ? null
        : DateTime.parse(poligonoActs.first['activity_date'] as String);
    final poligonoBaseStatus = _computeStatus(
      lastDate: lastPoligonoDate,
      periodDays: poligonoPeriodDays,
      label: 'Poligono MDB',
    );
    final poligonoStatus = poligonoCount < minPoligonoCount
        ? CurrencyStatus(
            status: poligonoBaseStatus.lastActivityDate == null
                ? CurrencyStatusEnum.expired
                : poligonoBaseStatus.status,
            lastActivityDate: poligonoBaseStatus.lastActivityDate,
            expiryDate: poligonoBaseStatus.expiryDate,
            daysUntilExpiry: poligonoBaseStatus.daysUntilExpiry,
            label:
                'Poligono MDB ($poligonoCount/$minPoligonoCount)${poligonoCount < minPoligonoCount ? ' · Poligono mancante' : ''}',
          )
        : CurrencyStatus(
            status: poligonoBaseStatus.status,
            lastActivityDate: poligonoBaseStatus.lastActivityDate,
            expiryDate: poligonoBaseStatus.expiryDate,
            daysUntilExpiry: poligonoBaseStatus.daysUntilExpiry,
            label: 'Poligono MDB ($poligonoCount/$minPoligonoCount)',
          );

    final statuses = [flightStatus, poligonoStatus];
    CurrencyStatusEnum overallStatus = CurrencyStatusEnum.valid;
    if (statuses.any((item) => item.status == CurrencyStatusEnum.expired)) {
      overallStatus = CurrencyStatusEnum.expired;
    } else if (statuses.any(
      (item) => item.status == CurrencyStatusEnum.warning,
    )) {
      overallStatus = CurrencyStatusEnum.warning;
    }

    final reasons = <String>[];
    if (flightHours < minHours) {
      reasons.add('Ore insufficienti');
    }
    if (poligonoCount < minPoligonoCount) {
      reasons.add('Poligono mancante');
    }
    if (poligonoStatus.status == CurrencyStatusEnum.expired &&
        !reasons.contains('Poligono scaduto')) {
      reasons.add('Poligono scaduto');
    }

    final labelSuffix = reasons.isEmpty ? 'OK' : reasons.join(' · ');
    final daysCandidates = [
      flightStatus.daysUntilExpiry,
      poligonoStatus.daysUntilExpiry,
    ].whereType<int>().toList();
    daysCandidates.sort();

    return CurrencyStatus(
      status: overallStatus,
      lastActivityDate: [lastFlightDate, lastPoligonoDate]
          .whereType<DateTime>()
          .fold<DateTime?>(null, (latest, value) {
            if (latest == null || value.isAfter(latest)) {
              return value;
            }
            return latest;
          }),
      expiryDate: flightStatus.expiryDate,
      secondaryExpiryDate: poligonoStatus.expiryDate,
      secondaryExpiryLabel: 'Poligono',
      daysUntilExpiry: daysCandidates.isEmpty ? null : daysCandidates.first,
      label:
          'Mitragliere di Bordo · ${flightHours.toStringAsFixed(1)}h/${minHours.toStringAsFixed(1)}h · Poligono $poligonoCount/$minPoligonoCount · $labelSuffix',
      flightHours: flightHours,
      minFlightHours: minHours,
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
      // Get the user's TOB fascia (use the first active TOB assignment's fascia)
      final tobAssignment = _db.crew.firstWhere(
        (item) =>
            item['user_id'] == userId &&
            item['crew_type'] == 'TOB' &&
            item['active'] == true,
        orElse: () => {},
      );
      final fascia = tobAssignment['tob_grade'] as String?;

      // TOB base currency (any flight as crew member)
      result['tob_base'] = await getTobBaseCurrency(userId, fascia);

      // TOB capability-specific currencies
      for (final cap in tobCaps) {
        result['tob_${cap.helicopterTypeId}_${cap.tobCapabilityId}'] =
            await getTobCapabilityCurrencyStatus(
              userId,
              cap.helicopterTypeId,
              cap.tobCapabilityId,
              cap.capabilityName,
              fascia: fascia,
            );
      }
    }

    if (crewTypes.contains('MDB')) {
      result['mdb'] = await getMdbCurrency(
        userId,
        _db.crew
            .where(
              (item) => item['user_id'] == userId && item['active'] == true,
            )
            .map(UserCrewAssignment.fromJson)
            .toList(growable: false),
      );
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
        WebNotificationService.showNotification('AVES Tecnici', message);
      }
    }

    final userFullName = _userFullName(userId);
    final perPrivilegeStatuses = await getPerPrivilegeCurrency(userId);
    for (final privilege in perPrivilegeStatuses) {
      if (!privilege.status.isExpired && !privilege.status.isWarning) {
        continue;
      }

      final isExpired = privilege.status.isExpired;
      final userMessage = isExpired
          ? 'Il privilegio ${privilege.privilegeName} su ${privilege.helicopterCode} è scaduto.'
          : 'Il privilegio ${privilege.privilegeName} su ${privilege.helicopterCode} è in scadenza.';
      final adminMessage = isExpired
          ? 'Utente $userFullName: privilegio ${privilege.privilegeName} su ${privilege.helicopterCode} scaduto.'
          : 'Utente $userFullName: privilegio ${privilege.privilegeName} su ${privilege.helicopterCode} in scadenza.';
      final metadata = {
        'userId': userId,
        'privilegeTypeId': privilege.privilegeTypeId,
        'helicopterTypeId': privilege.helicopterTypeId,
      };

      final privilegeNotification = await _upsertNotification(
        userId,
        isExpired ? 'PRIVILEGE_EXPIRED' : 'PRIVILEGE_EXPIRING',
        '${privilege.helicopterCode} · ${privilege.privilegeName} · ${isExpired ? 'scaduto' : 'in scadenza'}',
        message: userMessage,
        metadata: metadata,
      );
      if (privilegeNotification != null) {
        WebNotificationService.showNotification(
          'AVES Tecnici',
          privilegeNotification,
        );
      }

      await _upsertNotification(
        _adminPrivNotificationUserId,
        'PRIVILEGE_EXPIRED_ADMIN',
        '${userId}_${privilege.helicopterTypeId}_${privilege.privilegeTypeId}_${isExpired ? 'expired' : 'warning'}',
        message: adminMessage,
        metadata: metadata,
      );
    }
  }

  String _notifType(String key, {required bool expired}) {
    if (key == 'maintenance') {
      return expired ? 'MAINTENANCE_EXPIRED' : 'MAINTENANCE_EXPIRING';
    }
    if (key == 'flight_t') {
      return expired ? 'FLIGHT_EXPIRED' : 'FLIGHT_EXPIRING';
    }
    if (key == 'tob_base') {
      return expired ? 'TOB_BASE_EXPIRED' : 'TOB_BASE_EXPIRING';
    }
    if (key == 'mdb') {
      return expired ? 'MDB_EXPIRED' : 'MDB_EXPIRING';
    }
    return expired ? 'TOB_EXPIRED' : 'TOB_EXPIRING';
  }

  Future<String?> _upsertNotification(
    String userId,
    String type,
    String label, {
    int? daysLeft,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    final notifications = _db.notifications;
    final resolvedMessage =
        message ??
        (daysLeft != null
            ? '⚠️ $label in scadenza tra $daysLeft giorni!'
            : '🔴 $label – NO GO. Eseguire attività di mantenimento.');
    final exists = notifications.any(
      (item) =>
          item['user_id'] == userId &&
          item['type'] == type &&
          item['is_read'] == false &&
          ((item['label'] as String?) == label ||
              item['message'] == resolvedMessage),
    );
    if (exists) {
      return null;
    }

    notifications.add({
      'id': _nextNotificationId(notifications),
      'user_id': userId,
      'type': type,
      'label': label,
      'message': resolvedMessage,
      'metadata': metadata,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _db.saveNotifications(notifications);
    return resolvedMessage;
  }
}
