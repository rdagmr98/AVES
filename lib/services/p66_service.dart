import '../models/user_models.dart';
import 'gh_db_service.dart';
import 'user_service.dart';

enum P66Status { go, warning, noGo }

class P66UserData {
  const P66UserData({
    required this.user,
    required this.licenseTypes,
    required this.licenseNumber,
    required this.monthCount,
    required this.status,
    required this.coveredMonths,
    this.lastActivityDate,
  });

  final UserProfile user;
  final String licenseTypes;
  final String licenseNumber;
  final int monthCount;
  final P66Status status;
  final List<String> coveredMonths;
  final DateTime? lastActivityDate;

  String get statusText => switch (status) {
    P66Status.go => 'GO',
    P66Status.warning => 'WARNING',
    P66Status.noGo => 'NO GO',
  };
}

class P66Service {
  final _db = GhDbService();
  final _userService = UserService();

  DateTime _effectiveDate(Map<String, dynamic> activity) => DateTime.parse(
    (activity['date_to'] ?? activity['activity_date']) as String,
  );

  Set<String> _monthsFromActivity(
    Map<String, dynamic> activity,
    DateTime cutoff,
  ) {
    final months = <String>{};
    final dateTo = _effectiveDate(activity);
    final dateFromRaw = activity['date_from'] as String?;
    final dateFrom = dateFromRaw != null
        ? DateTime.tryParse(dateFromRaw)
        : null;
    var cursor = DateTime(
      (dateFrom ?? dateTo).year,
      (dateFrom ?? dateTo).month,
    );
    final lastMonth = DateTime(dateTo.year, dateTo.month);

    while (!cursor.isAfter(lastMonth)) {
      final monthAnchor = DateTime(cursor.year, cursor.month, 1);
      if (!monthAnchor.isBefore(DateTime(cutoff.year, cutoff.month, 1))) {
        months.add('${cursor.year}-${cursor.month.toString().padLeft(2, '0')}');
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return months;
  }

  int countMonthsInLast24(String userId) => monthsInLast24(userId).length;

  List<String> monthsInLast24(String userId) {
    final cutoff = DateTime.now().subtract(const Duration(days: 730));
    final months = <String>{};

    for (final activity in _db.maintenanceActs.where(
      (item) => item['user_id'] == userId && item['is_validated'] == true,
    )) {
      final effectiveDate = _effectiveDate(activity);
      if (effectiveDate.isBefore(cutoff)) {
        continue;
      }
      months.addAll(_monthsFromActivity(activity, cutoff));
    }

    final ordered = months.toList()..sort();
    return ordered;
  }

  DateTime? lastActivityDate(String userId) {
    final acts = _db.maintenanceActs
        .where(
          (item) => item['user_id'] == userId && item['is_validated'] == true,
        )
        .toList(growable: false);
    if (acts.isEmpty) {
      return null;
    }
    acts.sort((a, b) => _effectiveDate(b).compareTo(_effectiveDate(a)));
    return _effectiveDate(acts.first);
  }

  P66Status getP66Status(int monthCount) {
    if (monthCount >= 6) return P66Status.go;
    if (monthCount >= 4) return P66Status.warning;
    return P66Status.noGo;
  }

  Future<List<P66UserData>> getAllP66Data() async {
    final rows = <P66UserData>[];
    final users = await _userService.getAllUsers();

    for (final user in users.where((item) => item.isApprovedMaint)) {
      final licenses = await _userService.getUserLicenses(user.id);
      final privileges = await _userService.getUserPrivileges(user.id);
      if (licenses.isEmpty && privileges.isEmpty) {
        continue;
      }

      final licenseTypes =
          licenses.map((item) => item.licenseName).toSet().toList()..sort();
      final coveredMonths = monthsInLast24(user.id);
      final monthCount = coveredMonths.length;

      rows.add(
        P66UserData(
          user: user,
          licenseTypes: licenseTypes.isEmpty ? '-' : licenseTypes.join(', '),
          licenseNumber: user.numeroLicenza ?? '-',
          monthCount: monthCount,
          status: getP66Status(monthCount),
          coveredMonths: coveredMonths,
          lastActivityDate: lastActivityDate(user.id),
        ),
      );
    }

    rows.sort((a, b) => a.user.fullName.compareTo(b.user.fullName));
    return rows;
  }
}
