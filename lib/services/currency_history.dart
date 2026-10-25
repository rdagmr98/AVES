import '../models/activity_models.dart';
import '../models/reference_models.dart';
import '../models/user_models.dart';

enum CurrencyEventKind { assigned, revoked, restored, lost }

/// Evento dello storico currency di un utente (timeline della scheda).
/// [delete] elimina la riga da cui nasce (null = evento calcolato o
/// privilegio ancora attivo).
typedef CurrencyEvent = ({
  DateTime date,
  CurrencyEventKind kind,
  String title,
  String? note,
  Future<void> Function()? delete,
});

/// Perdite di currency ricavate dalle date delle attività: ogni intervallo
/// oltre [periodDays] fra due attività consecutive (o fra l'ultima ed [end])
/// è una perdita alla data dell'ultima + [periodDays]; `regained` è l'attività
/// che l'ha ripristinata (null = ancora persa a [end]). Senza attività la
/// currency non è mai stata acquisita: nessuna perdita.
List<({DateTime lost, DateTime? regained})> currencyLosses(
  Iterable<DateTime> dates,
  int periodDays,
  DateTime end,
) {
  final sorted = dates.toList()..sort();
  return [
    for (var i = 0; i < sorted.length; i++)
      if ((i + 1 < sorted.length ? sorted[i + 1] : end).isAfter(
        sorted[i].add(Duration(days: periodDays)),
      ))
        (
          lost: sorted[i].add(Duration(days: periodDays)),
          regained: i + 1 < sorted.length ? sorted[i + 1] : null,
        ),
  ];
}

/// Scadenza seminario per tecnico: ultimo seminario validato + 2 anni di
/// calendario (stessa regola del calcolo currency). Assente = mai svolto.
Map<String, DateTime> seminarExpiries(Iterable<Map<String, dynamic>> seminars) {
  final expiry = <String, DateTime>{};
  for (final s in seminars) {
    final id = s['user_id'] as String?;
    final d = DateTime.tryParse(s['seminar_date'] as String? ?? '');
    if (s['is_validated'] != true || id == null || d == null) continue;
    final e = DateTime(d.year + 2, d.month, d.day);
    if (expiry[id]?.isAfter(e) != true) expiry[id] = e;
  }
  return expiry;
}

/// Mai svolto (assente o null) in cima, poi chi scade prima; a pari data
/// alfabetico.
void sortByExpiry(List<UserProfile> users, Map<String, DateTime?> expiry) =>
    users.sort((a, b) {
      final ea = expiry[a.id], eb = expiry[b.id];
      final c = ea == null
          ? (eb == null ? 0 : -1)
          : (eb == null ? 1 : ea.compareTo(eb));
      return c != 0 ? c : a.fullName.compareTo(b.fullName);
    });

const ojtTypes = ['OJT iniziale', 'OJT di ripristino', 'OJT nuovo privilegio'];

/// Privilegi proponibili per tipo di OJT su un elicottero: iniziale = tutti,
/// ripristino = solo gli scaduti dell'utente, nuovo = solo i non assegnati.
Map<int, String> ojtOptions(
  String type,
  int? heliId,
  List<PrivilegeType> privs,
  List<PrivilegeCurrencyStatus> current,
) {
  bool has(int p, {bool expired = false}) => current.any(
    (s) =>
        s.helicopterTypeId == heliId &&
        s.privilegeTypeId == p &&
        (!expired || s.status.isExpired),
  );
  return {
    for (final p in privs)
      if (type == ojtTypes[0] ||
          (type == ojtTypes[1] ? has(p.id, expired: true) : !has(p.id)))
        p.id: p.name,
  };
}

/// OJT per assegnare [ids] su [heliId], dallo storico privilegi dell'utente
/// ([history], righe anche revocate): i già attivi non lo richiedono; nessuna
/// riga = utente nuovo (iniziale), privilegio già avuto = ripristino.
Map<int, String> proposedOjt(
  List<Map<String, dynamic>> history,
  int heliId,
  Iterable<int> ids,
) {
  bool had(int p, {bool active = false}) => history.any(
    (r) =>
        r['helicopter_type_id'] == heliId &&
        r['privilege_type_id'] == p &&
        (!active || r['active'] != false),
  );
  return {
    for (final p in ids)
      if (!had(p, active: true))
        p: history.isEmpty
            ? ojtTypes[0]
            : had(p)
            ? ojtTypes[1]
            : ojtTypes[2],
  };
}
