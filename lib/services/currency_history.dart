import '../models/activity_models.dart';
import '../models/reference_models.dart';
import '../models/user_models.dart';

enum CurrencyEventKind { assigned, revoked, restored, lost }

/// Categoria di licenza (`license_type_id`) di un privilegio e di un'attività:
/// nulla = tutte le categorie, quindi si coprono se una delle due è nulla o
/// se coincidono (B1.3 e B2 sullo stesso privilegio hanno currency separate).
bool catCovers(Object? a, Object? b) => a == null || b == null || a == b;

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

/// Assegnazione del [created] già nello storico come OJT: un OJT ([ojt]) fino a
/// quel giorno e dopo l'ultima revoca precedente ([revoked]). L'OJT iniziale o
/// di ripristino è l'assegnazione, con la sua data vera; la riga privilegio
/// porta la data di inserimento.
bool assignedByOjt(
  DateTime created,
  Iterable<DateTime> ojt,
  Iterable<DateTime> revoked,
) {
  final day = DateTime(created.year, created.month, created.day);
  final prev = revoked.where((r) => r.isBefore(created)).fold<DateTime?>(
    null,
    (m, r) => m == null || r.isAfter(m) ? r : m,
  );
  return ojt.any((o) => !o.isAfter(day) && (prev == null || o.isAfter(prev)));
}

/// Tipi coperti da un seminario: NAM_MHF (anche "NAM/MHF" e i dati senza
/// tipo) vale per entrambi.
Set<String> seminarCovers(String? type) {
  final t = (type ?? 'NAM_MHF').trim().toUpperCase().replaceAll(
    RegExp(r'[^A-Z]+'),
    '_',
  );
  return {
    if (t == 'NAM' || t == 'NAM_MHF') 'NAM',
    if (t == 'MHF' || t == 'NAM_MHF') 'MHF',
  };
}

/// Scadenza per tecnico e tipo (NAM, MHF): ultimo seminario validato di quel
/// tipo + 2 anni di calendario, come il Riepilogo CAAE.
Map<String, Map<String, DateTime>> seminarTypeExpiries(
  Iterable<Map<String, dynamic>> seminars,
) {
  final expiry = <String, Map<String, DateTime>>{};
  for (final s in seminars) {
    final id = s['user_id'] as String?;
    final d = DateTime.tryParse(s['seminar_date'] as String? ?? '');
    if (s['is_validated'] != true || id == null || d == null) continue;
    final e = DateTime(d.year + 2, d.month, d.day);
    final byType = expiry.putIfAbsent(id, () => {});
    for (final t in seminarCovers(s['seminar_type'] as String?)) {
      if (byType[t]?.isAfter(e) != true) byType[t] = e;
    }
  }
  return expiry;
}

/// Scadenza seminari per tecnico: GO solo con NAM e MHF entrambi validi,
/// quindi vale il primo che scade. Assente = almeno uno dei due mai svolto.
Map<String, DateTime> seminarExpiries(
  Iterable<Map<String, dynamic>> seminars,
) => {
  for (final MapEntry(:key, :value) in seminarTypeExpiries(seminars).entries)
    if (value.length == 2)
      key: value.values.reduce((a, b) => a.isBefore(b) ? a : b),
};

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

/// Privilegi proponibili per tipo di OJT su un elicottero (e categoria
/// [cat], null = tutte): iniziale = tutti, ripristino = solo gli scaduti
/// dell'utente, nuovo = solo i non assegnati.
Map<int, String> ojtOptions(
  String type,
  int? heliId,
  List<PrivilegeType> privs,
  List<PrivilegeCurrencyStatus> current, [
  int? cat,
]) {
  bool has(int p, {bool expired = false}) => current.any(
    (s) =>
        s.helicopterTypeId == heliId &&
        s.privilegeTypeId == p &&
        catCovers(s.licenseTypeId, cat) &&
        (!expired || s.status.isExpired),
  );
  return {
    for (final p in privs)
      if (type == ojtTypes[0] ||
          (type == ojtTypes[1] ? has(p.id, expired: true) : !has(p.id)))
        p.id: p.name,
  };
}

/// OJT per assegnare [ids] su [heliId] nella categoria [cat] (null = tutte),
/// dallo storico privilegi dell'utente ([history], righe anche revocate): i
/// già attivi non lo richiedono; nessuna riga = utente nuovo (iniziale),
/// privilegio già avuto = ripristino.
Map<int, String> proposedOjt(
  List<Map<String, dynamic>> history,
  int heliId,
  Iterable<int> ids, [
  int? cat,
]) {
  bool had(int p, {bool active = false}) => history.any(
    (r) =>
        r['helicopter_type_id'] == heliId &&
        r['privilege_type_id'] == p &&
        catCovers(r['license_type_id'], cat) &&
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

/// Notifiche da tenere: notifications.json oltre 1 MB non si legge più con la
/// Contents API, quindi via le lette/cancellate dopo 180 giorni e tutte dopo
/// un anno.
// ponytail: una currency ancora scaduta dopo 180 giorni torna notificata una
// volta (la letta non c'è più): fa da promemoria, va bene così.
List<Map<String, dynamic>> pruneNotifications(
  List<Map<String, dynamic>> notifications,
  DateTime now,
) => notifications.where((n) {
  final created = DateTime.tryParse(n['created_at'] as String? ?? '');
  if (created == null) return true;
  final age = now.difference(created).inDays;
  return age <= 365 && (age <= 180 || n['is_read'] == false);
}).toList();

/// Notifica di currency già inviata: non letta, oppure letta ma dello stesso
/// episodio (stessa scadenza). Così una notifica letta non torna a ogni sync.
bool currencyNotificationSent(
  Iterable<Map<String, dynamic>> notifications, {
  required String userId,
  required String type,
  required String label,
  required String message,
  required String episode,
}) => notifications.any(
  (n) =>
      n['user_id'] == userId &&
      n['type'] == type &&
      (n['is_read'] == false || n['episode'] == episode) &&
      (n['label'] == label || n['message'] == message),
);
