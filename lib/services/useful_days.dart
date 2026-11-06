import '../models/activity_models.dart';

/// Riga del registro giornate lavorative utili (Allegato D-P3-02 del MdQ):
/// un tecnico in un giorno, con tutte le attività validate di quel giorno.
class UsefulDayRow {
  UsefulDayRow(this.day, this.userId, this.name, this.licenseNumber);

  final DateTime day;
  final String userId;
  final String name;
  final String licenseNumber;
  final qualifications = <String>{};
  final tasks = <String>{};
  final orders = <String>{};
}

/// Righe importate dall'Annesso: riallineano la currency, non sono giornate
/// di lavoro e non vanno nel registro.
bool isAnnexAlignment(MaintenanceActivity a) =>
    (a.description ?? '').startsWith('Riallineamento currency');

/// Una riga per tecnico e giorno in [from, to] (date incluse), ordinate per
/// data e nome. Le attività su più giorni (`date_from`-`date_to`) danno una
/// giornata per ogni giorno, come il conteggio P-66.
List<UsefulDayRow> usefulDayRows(
  Iterable<MaintenanceActivity> activities,
  DateTime from,
  DateTime to,
) {
  DateTime d(DateTime x) => DateTime(x.year, x.month, x.day);
  final start = d(from), end = d(to);
  final rows = <String, UsefulDayRow>{};
  for (final a in activities) {
    if (!a.isValidated || isAnnexAlignment(a)) continue;
    // privilegeName = "Privilegio · Categoria" (categoria facoltativa).
    final parts = a.privilegeName.split(' · ');
    final qualification = [
      a.helicopterCode,
      if (parts.length > 1) parts[1],
    ].where((s) => s.isNotEmpty).join(' ');
    final desc = a.description?.trim() ?? '';
    final task = [
      desc.isNotEmpty ? desc : parts.first,
      if ((a.matricolaMilitare ?? '').trim().isNotEmpty)
        '(MM ${a.matricolaMilitare!.trim()})',
    ].where((s) => s.isNotEmpty).join(' ');
    for (
      var day = d(a.dateFrom ?? a.activityDate);
      !day.isAfter(d(a.dateTo ?? a.activityDate));
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      if (day.isBefore(start) || day.isAfter(end)) continue;
      final row = rows.putIfAbsent(
        '${day.toIso8601String()}|${a.userId}',
        () => UsefulDayRow(day, a.userId, a.userFullName, a.userLicenza),
      );
      if (qualification.isNotEmpty) row.qualifications.add(qualification);
      if (task.isNotEmpty) row.tasks.add(task);
      final order = a.ordineLavoro?.trim() ?? '';
      if (order.isNotEmpty) row.orders.add(order);
    }
  }
  return rows.values.toList()..sort(
    (a, b) =>
        a.day != b.day ? a.day.compareTo(b.day) : a.name.compareTo(b.name),
  );
}
