import 'package:flutter/material.dart';

enum CurrencyStatusEnum { valid, warning, expired, suspended, noData }

class CurrencyStatus {
  final CurrencyStatusEnum status;
  final DateTime? lastActivityDate;
  final DateTime? expiryDate;
  final DateTime? secondaryExpiryDate;
  final String? secondaryExpiryLabel;
  final int? daysUntilExpiry;
  final String label;
  final double? flightHours;
  final double? minFlightHours;

  const CurrencyStatus({
    required this.status,
    this.lastActivityDate,
    this.expiryDate,
    this.secondaryExpiryDate,
    this.secondaryExpiryLabel,
    this.daysUntilExpiry,
    required this.label,
    this.flightHours,
    this.minFlightHours,
  });

  bool get isValid => status == CurrencyStatusEnum.valid;
  bool get isWarning => status == CurrencyStatusEnum.warning;
  bool get isExpired => status == CurrencyStatusEnum.expired;
  bool get isSuspended => status == CurrencyStatusEnum.suspended;
  bool get hasData => status != CurrencyStatusEnum.noData;

  Color get color {
    switch (status) {
      case CurrencyStatusEnum.valid:
        return const Color(0xFF27AE60);
      case CurrencyStatusEnum.warning:
        return const Color(0xFFE67E22);
      case CurrencyStatusEnum.expired:
        return const Color(0xFFC0392B);
      case CurrencyStatusEnum.suspended:
        return const Color(0xFF8E44AD);
      case CurrencyStatusEnum.noData:
        return const Color(0xFF7F8C8D);
    }
  }

  IconData get icon {
    switch (status) {
      case CurrencyStatusEnum.valid:
        return Icons.check_circle;
      case CurrencyStatusEnum.warning:
        return Icons.warning_amber_rounded;
      case CurrencyStatusEnum.expired:
        return Icons.cancel;
      case CurrencyStatusEnum.suspended:
        return Icons.block;
      case CurrencyStatusEnum.noData:
        return Icons.help_outline;
    }
  }

  String get statusText {
    switch (status) {
      case CurrencyStatusEnum.valid:
        return 'GO';
      case CurrencyStatusEnum.warning:
        return 'IN SCADENZA';
      case CurrencyStatusEnum.expired:
        return 'NO GO';
      case CurrencyStatusEnum.suspended:
        return 'NO GO – PTA';
      case CurrencyStatusEnum.noData:
        return 'NESSUN DATO';
    }
  }
}

class PrivilegeCurrencyStatus {
  final int helicopterTypeId;
  final String helicopterCode;
  final int privilegeTypeId;
  final String privilegeName;
  final CurrencyStatus status;

  const PrivilegeCurrencyStatus({
    required this.helicopterTypeId,
    required this.helicopterCode,
    required this.privilegeTypeId,
    required this.privilegeName,
    required this.status,
  });
}

class CurrencyCriteria {
  final int? id;
  final String
  criteriaType; // 'MAINTENANCE', 'FLIGHT_T', 'TOB_BASE', 'TOB_CAPABILITY'
  final int? tobCapabilityId;
  final int periodDays;
  final int? periodDaysA; // period for fascia A (null = use periodDays)
  final int?
  periodDaysBC; // period for fascia B/C (null = not applicable for B/C)
  final double? minHours;
  final String? description;
  final String? tobCapabilityName;

  const CurrencyCriteria({
    this.id,
    required this.criteriaType,
    this.tobCapabilityId,
    required this.periodDays,
    this.periodDaysA,
    this.periodDaysBC,
    this.minHours,
    this.description,
    this.tobCapabilityName,
  });

  factory CurrencyCriteria.fromJson(Map<String, dynamic> j) => CurrencyCriteria(
    id: j['id'] as int?,
    criteriaType: j['criteria_type'] as String,
    tobCapabilityId: j['tob_capability_id'] as int?,
    periodDays: j['period_days'] as int,
    periodDaysA: j['period_days_a'] as int?,
    periodDaysBC: j['period_days_bc'] as int?,
    minHours: (j['min_hours'] as num?)?.toDouble(),
    description: j['description'] as String?,
    tobCapabilityName:
        (j['tob_capabilities'] as Map<String, dynamic>?)?['name'] as String?,
  );

  /// Returns the effective period for the given fascia.
  /// Returns null if this capability is not applicable for the given fascia.
  int? periodForFascia(String? fascia) {
    if (fascia == 'A') {
      return periodDaysA ?? periodDays;
    }
    if (fascia == 'B' || fascia == 'C') {
      return periodDaysBC; // null = not applicable
    }
    return periodDays; // unknown fascia → fallback
  }

  bool isNAForFascia(String? fascia) {
    if (fascia == 'B' || fascia == 'C') {
      return periodDaysBC == null &&
          (criteriaType == 'TOB_CAPABILITY' || criteriaType == 'TOB_BASE');
    }
    return false;
  }
}

class MaintenanceActivity {
  final int? id;
  final String userId;
  final int helicopterTypeId;
  final int? privilegeTypeId;
  final DateTime activityDate;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? description;
  final String? activityType;
  final String? matricolaMilitare;
  final String? numeroCorrozzella;
  final String? ordineLavoro;
  final bool isValidated;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? submittedBy;
  final DateTime? createdAt;

  // Joined
  final String helicopterCode;
  final String privilegeName;
  final String userFullName;
  final String userLicenza;

  const MaintenanceActivity({
    this.id,
    required this.userId,
    required this.helicopterTypeId,
    required this.privilegeTypeId,
    required this.activityDate,
    this.dateFrom,
    this.dateTo,
    this.description,
    this.activityType,
    this.matricolaMilitare,
    this.numeroCorrozzella,
    this.ordineLavoro,
    this.isValidated = false,
    this.validatedBy,
    this.validatedAt,
    this.submittedBy,
    this.createdAt,
    this.helicopterCode = '',
    this.privilegeName = '',
    this.userFullName = '',
    this.userLicenza = '',
  });

  factory MaintenanceActivity.fromJson(
    Map<String, dynamic> j,
  ) => MaintenanceActivity(
    id: j['id'] as int?,
    userId: j['user_id'] as String,
    helicopterTypeId: j['helicopter_type_id'] as int,
    privilegeTypeId: j['privilege_type_id'] as int?,
    activityDate: DateTime.parse(j['activity_date'] as String),
    dateFrom: j['date_from'] != null
        ? DateTime.parse(j['date_from'] as String)
        : null,
    dateTo: j['date_to'] != null
        ? DateTime.parse(j['date_to'] as String)
        : null,
    description: j['description'] as String?,
    activityType: j['activity_type'] as String?,
    matricolaMilitare: j['matricola_militare'] as String?,
    numeroCorrozzella: j['numero_corrozzella'] as String?,
    ordineLavoro: j['ordine_lavoro'] as String?,
    isValidated: j['is_validated'] as bool? ?? false,
    validatedBy: j['validated_by'] as String?,
    validatedAt: j['validated_at'] != null
        ? DateTime.parse(j['validated_at'] as String)
        : null,
    submittedBy: j['submitted_by'] as String?,
    createdAt: j['created_at'] != null
        ? DateTime.parse(j['created_at'] as String)
        : null,
    helicopterCode:
        (j['helicopter_types'] as Map<String, dynamic>?)?['code'] as String? ??
        '',
    privilegeName:
        (j['privilege_types'] as Map<String, dynamic>?)?['name'] as String? ??
        (j['privilege_type_id'] == null ? 'Tutti i privilegi' : ''),
    userFullName: () {
      final u = j['user_profiles'] as Map<String, dynamic>?;
      if (u == null) return '';
      return '${u['cognome'] ?? ''} ${u['nome'] ?? ''}'.trim();
    }(),
    userLicenza:
        (j['user_profiles'] as Map<String, dynamic>?)?['numero_licenza']
            as String? ??
        '',
  );

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'helicopter_type_id': helicopterTypeId,
    if (privilegeTypeId != null) 'privilege_type_id': privilegeTypeId,
    'activity_date': activityDate.toIso8601String().split('T').first,
    if (dateFrom != null)
      'date_from': dateFrom!.toIso8601String().split('T').first,
    if (dateTo != null) 'date_to': dateTo!.toIso8601String().split('T').first,
    'description': description,
    if (activityType != null) 'activity_type': activityType,
    if (matricolaMilitare != null) 'matricola_militare': matricolaMilitare,
    if (numeroCorrozzella != null) 'numero_corrozzella': numeroCorrozzella,
    if (ordineLavoro != null) 'ordine_lavoro': ordineLavoro,
    'submitted_by': submittedBy,
  };

  DateTime get effectiveDate => dateTo ?? activityDate;

  int get daysWorked {
    if (dateFrom != null && dateTo != null) {
      return dateTo!.difference(dateFrom!).inDays + 1;
    }
    return 1;
  }

  String get status => isValidated ? 'validated' : 'pending';
}

class FlightActivity {
  final int? id;
  final String userId;
  final int helicopterTypeId;
  final DateTime activityDate;
  final double flightHours;
  final String? description;
  final bool isValidated;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? submittedBy;
  final DateTime? createdAt;

  final String helicopterCode;
  final String userFullName;
  final String userLicenza;

  const FlightActivity({
    this.id,
    required this.userId,
    required this.helicopterTypeId,
    required this.activityDate,
    required this.flightHours,
    this.description,
    this.isValidated = false,
    this.validatedBy,
    this.validatedAt,
    this.submittedBy,
    this.createdAt,
    this.helicopterCode = '',
    this.userFullName = '',
    this.userLicenza = '',
  });

  factory FlightActivity.fromJson(Map<String, dynamic> j) => FlightActivity(
    id: j['id'] as int?,
    userId: j['user_id'] as String,
    helicopterTypeId: j['helicopter_type_id'] as int,
    activityDate: DateTime.parse(j['activity_date'] as String),
    flightHours: (j['flight_hours'] as num).toDouble(),
    description: j['description'] as String?,
    isValidated: j['is_validated'] as bool? ?? false,
    validatedBy: j['validated_by'] as String?,
    validatedAt: j['validated_at'] != null
        ? DateTime.parse(j['validated_at'] as String)
        : null,
    submittedBy: j['submitted_by'] as String?,
    createdAt: j['created_at'] != null
        ? DateTime.parse(j['created_at'] as String)
        : null,
    helicopterCode:
        (j['helicopter_types'] as Map<String, dynamic>?)?['code'] as String? ??
        '',
    userFullName: () {
      final u = j['user_profiles'] as Map<String, dynamic>?;
      if (u == null) return '';
      return '${u['cognome'] ?? ''} ${u['nome'] ?? ''}'.trim();
    }(),
    userLicenza:
        (j['user_profiles'] as Map<String, dynamic>?)?['numero_licenza']
            as String? ??
        '',
  );

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'helicopter_type_id': helicopterTypeId,
    'activity_date': activityDate.toIso8601String().split('T').first,
    'flight_hours': flightHours,
    'description': description,
    'submitted_by': submittedBy,
  };

  String get status => isValidated ? 'validated' : 'pending';
}

class TobActivity {
  final int? id;
  final String userId;
  final int helicopterTypeId;
  final int tobCapabilityId;
  final DateTime activityDate;
  final String? description;
  final bool isValidated;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? submittedBy;
  final DateTime? createdAt;

  final String helicopterCode;
  final String capabilityName;
  final String userFullName;
  final String userLicenza;

  const TobActivity({
    this.id,
    required this.userId,
    required this.helicopterTypeId,
    required this.tobCapabilityId,
    required this.activityDate,
    this.description,
    this.isValidated = false,
    this.validatedBy,
    this.validatedAt,
    this.submittedBy,
    this.createdAt,
    this.helicopterCode = '',
    this.capabilityName = '',
    this.userFullName = '',
    this.userLicenza = '',
  });

  factory TobActivity.fromJson(Map<String, dynamic> j) => TobActivity(
    id: j['id'] as int?,
    userId: j['user_id'] as String,
    helicopterTypeId: j['helicopter_type_id'] as int,
    tobCapabilityId: j['tob_capability_id'] as int,
    activityDate: DateTime.parse(j['activity_date'] as String),
    description: j['description'] as String?,
    isValidated: j['is_validated'] as bool? ?? false,
    validatedBy: j['validated_by'] as String?,
    validatedAt: j['validated_at'] != null
        ? DateTime.parse(j['validated_at'] as String)
        : null,
    submittedBy: j['submitted_by'] as String?,
    createdAt: j['created_at'] != null
        ? DateTime.parse(j['created_at'] as String)
        : null,
    helicopterCode:
        (j['helicopter_types'] as Map<String, dynamic>?)?['code'] as String? ??
        '',
    capabilityName:
        (j['tob_capabilities'] as Map<String, dynamic>?)?['name'] as String? ??
        '',
    userFullName: () {
      final u = j['user_profiles'] as Map<String, dynamic>?;
      if (u == null) return '';
      return '${u['cognome'] ?? ''} ${u['nome'] ?? ''}'.trim();
    }(),
    userLicenza:
        (j['user_profiles'] as Map<String, dynamic>?)?['numero_licenza']
            as String? ??
        '',
  );

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'helicopter_type_id': helicopterTypeId,
    'tob_capability_id': tobCapabilityId,
    'activity_date': activityDate.toIso8601String().split('T').first,
    'description': description,
    'submitted_by': submittedBy,
  };

  String get status => isValidated ? 'validated' : 'pending';
}

class SeminarActivity {
  final int? id;
  final String userId;
  final String seminarType;
  final DateTime seminarDate;
  final String? description;
  final bool isValidated;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? submittedBy;
  final DateTime? createdAt;

  final String userFullName;
  final String userLicenza;

  const SeminarActivity({
    this.id,
    required this.userId,
    required this.seminarType,
    required this.seminarDate,
    this.description,
    this.isValidated = false,
    this.validatedBy,
    this.validatedAt,
    this.submittedBy,
    this.createdAt,
    this.userFullName = '',
    this.userLicenza = '',
  });

  factory SeminarActivity.fromJson(Map<String, dynamic> j) => SeminarActivity(
    id: j['id'] as int?,
    userId: j['user_id'] as String,
    seminarType: j['seminar_type'] as String? ?? 'NAM_MHF',
    seminarDate: DateTime.parse(j['seminar_date'] as String),
    description: j['description'] as String?,
    isValidated: j['is_validated'] as bool? ?? false,
    validatedBy: j['validated_by'] as String?,
    validatedAt: j['validated_at'] != null
        ? DateTime.parse(j['validated_at'] as String)
        : null,
    submittedBy: j['submitted_by'] as String?,
    createdAt: j['created_at'] != null
        ? DateTime.parse(j['created_at'] as String)
        : null,
    userFullName: () {
      final u = j['user_profiles'] as Map<String, dynamic>?;
      if (u == null) return '';
      return '${u['cognome'] ?? ''} ${u['nome'] ?? ''}'.trim();
    }(),
    userLicenza:
        (j['user_profiles'] as Map<String, dynamic>?)?['numero_licenza']
            as String? ??
        '',
  );

  Map<String, dynamic> toInsertJson() => {
    'user_id': userId,
    'seminar_type': seminarType,
    'seminar_date': seminarDate.toIso8601String().split('T').first,
    'description': description,
    'submitted_by': submittedBy,
  };

  String get status => isValidated ? 'validated' : 'pending';
}

class NotificationModel {
  final int id;
  final String userId;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.metadata,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) =>
      NotificationModel(
        id: j['id'] as int,
        userId: j['user_id'] as String,
        type: j['type'] as String,
        message: j['message'] as String,
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        metadata: (j['metadata'] as Map?)?.cast<String, dynamic>(),
      );

  IconData get icon {
    if (type.contains('EXPIRED')) return Icons.cancel;
    if (type.contains('EXPIRING')) return Icons.warning_amber_rounded;
    if (type.contains('VALIDATED')) return Icons.check_circle;
    if (type.contains('APPROVED')) return Icons.verified_user;
    if (type.contains('PTA')) return Icons.block;
    return Icons.notifications;
  }
}

// ── PTA (Prescrizione Tecnica di Aeronavigabilità) ──────────────────────────

class PtaRecord {
  final int? id;
  final int helicopterTypeId;
  final String helicopterCode;
  final String number;
  final String title;
  final DateTime issueDate;
  final String createdBy;
  final DateTime createdAt;
  final bool isClosed;

  const PtaRecord({
    this.id,
    required this.helicopterTypeId,
    required this.helicopterCode,
    required this.number,
    required this.title,
    required this.issueDate,
    required this.createdBy,
    required this.createdAt,
    this.isClosed = false,
  });

  factory PtaRecord.fromJson(Map<String, dynamic> j) => PtaRecord(
    id: j['id'] as int?,
    helicopterTypeId: j['helicopter_type_id'] as int,
    helicopterCode: j['helicopter_code'] as String? ?? '',
    number: j['number'] as String,
    title: j['title'] as String,
    issueDate: DateTime.parse(j['issue_date'] as String),
    createdBy: j['created_by'] as String? ?? '',
    createdAt: DateTime.parse(j['created_at'] as String),
    isClosed: j['is_closed'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'helicopter_type_id': helicopterTypeId,
    'helicopter_code': helicopterCode,
    'number': number,
    'title': title,
    'issue_date': issueDate.toIso8601String().split('T').first,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'is_closed': isClosed,
  };
}

class PtaAcknowledgment {
  final int? id;
  final int ptaId;
  final String userId;
  final String userFullName;
  final String userLicenza;
  final DateTime acknowledgedAt;
  final bool isValidated;
  final String? validatedBy;
  final DateTime? validatedAt;

  const PtaAcknowledgment({
    this.id,
    required this.ptaId,
    required this.userId,
    this.userFullName = '',
    this.userLicenza = '',
    required this.acknowledgedAt,
    this.isValidated = false,
    this.validatedBy,
    this.validatedAt,
  });

  factory PtaAcknowledgment.fromJson(Map<String, dynamic> j) =>
      PtaAcknowledgment(
        id: j['id'] as int?,
        ptaId: j['pta_id'] as int,
        userId: j['user_id'] as String,
        userFullName: j['user_full_name'] as String? ?? '',
        userLicenza: j['user_licenza'] as String? ?? '',
        acknowledgedAt: DateTime.parse(j['acknowledged_at'] as String),
        isValidated: j['is_validated'] as bool? ?? false,
        validatedBy: j['validated_by'] as String?,
        validatedAt: j['validated_at'] != null
            ? DateTime.parse(j['validated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'pta_id': ptaId,
    'user_id': userId,
    'user_full_name': userFullName,
    'user_licenza': userLicenza,
    'acknowledged_at': acknowledgedAt.toIso8601String(),
    'is_validated': isValidated,
    if (validatedBy != null) 'validated_by': validatedBy,
    if (validatedAt != null) 'validated_at': validatedAt!.toIso8601String(),
  };
}
