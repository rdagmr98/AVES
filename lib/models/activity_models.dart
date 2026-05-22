import 'package:flutter/material.dart';

enum CurrencyStatusEnum { valid, warning, expired, noData }

class CurrencyStatus {
  final CurrencyStatusEnum status;
  final DateTime? lastActivityDate;
  final DateTime? expiryDate;
  final int? daysUntilExpiry;
  final String label;

  const CurrencyStatus({
    required this.status,
    this.lastActivityDate,
    this.expiryDate,
    this.daysUntilExpiry,
    required this.label,
  });

  bool get isValid => status == CurrencyStatusEnum.valid;
  bool get isWarning => status == CurrencyStatusEnum.warning;
  bool get isExpired => status == CurrencyStatusEnum.expired;
  bool get hasData => status != CurrencyStatusEnum.noData;

  Color get color {
    switch (status) {
      case CurrencyStatusEnum.valid:
        return const Color(0xFF27AE60);
      case CurrencyStatusEnum.warning:
        return const Color(0xFFE67E22);
      case CurrencyStatusEnum.expired:
        return const Color(0xFFC0392B);
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
      case CurrencyStatusEnum.noData:
        return Icons.help_outline;
    }
  }

  String get statusText {
    switch (status) {
      case CurrencyStatusEnum.valid:
        return 'VALIDA';
      case CurrencyStatusEnum.warning:
        return 'IN SCADENZA';
      case CurrencyStatusEnum.expired:
        return 'SCADUTA';
      case CurrencyStatusEnum.noData:
        return 'NESSUN DATO';
    }
  }
}

class CurrencyCriteria {
  final int? id;
  final String criteriaType; // 'MAINTENANCE', 'FLIGHT_T', 'TOB_CAPABILITY'
  final int? tobCapabilityId;
  final int periodDays;
  final double? minHours;
  final String? description;
  final String? tobCapabilityName;

  const CurrencyCriteria({
    this.id,
    required this.criteriaType,
    this.tobCapabilityId,
    required this.periodDays,
    this.minHours,
    this.description,
    this.tobCapabilityName,
  });

  factory CurrencyCriteria.fromJson(Map<String, dynamic> j) => CurrencyCriteria(
    id: j['id'] as int?,
    criteriaType: j['criteria_type'] as String,
    tobCapabilityId: j['tob_capability_id'] as int?,
    periodDays: j['period_days'] as int,
    minHours: (j['min_hours'] as num?)?.toDouble(),
    description: j['description'] as String?,
    tobCapabilityName:
        (j['tob_capabilities'] as Map<String, dynamic>?)?['name'] as String?,
  );
}

class MaintenanceActivity {
  final int? id;
  final String userId;
  final int helicopterTypeId;
  final int privilegeTypeId;
  final DateTime activityDate;
  final String? description;
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
    this.description,
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
    privilegeTypeId: j['privilege_type_id'] as int,
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
    privilegeName:
        (j['privilege_types'] as Map<String, dynamic>?)?['name'] as String? ??
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
    'privilege_type_id': privilegeTypeId,
    'activity_date': activityDate.toIso8601String().split('T').first,
    'description': description,
    'submitted_by': submittedBy,
  };

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

class NotificationModel {
  final int id;
  final String userId;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) =>
      NotificationModel(
        id: j['id'] as int,
        userId: j['user_id'] as String,
        type: j['type'] as String,
        message: j['message'] as String,
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  IconData get icon {
    if (type.contains('EXPIRED')) return Icons.cancel;
    if (type.contains('EXPIRING')) return Icons.warning_amber_rounded;
    if (type.contains('VALIDATED')) return Icons.check_circle;
    if (type.contains('APPROVED')) return Icons.verified_user;
    return Icons.notifications;
  }
}
