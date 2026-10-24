/// Currency volo T a semestri di calendario (1 gen-30 giu, 1 lug-31 dic):
/// servono >= [minHours] ore validate in ciascun semestre.
typedef FlightAct = ({DateTime date, double hours});

typedef FlightSemesterState = ({
  /// Ore nel semestre in corso.
  double hours,

  /// Ore nel semestre precedente (concluso).
  double prevHours,

  /// Scadenza: ultimo giorno entro cui il requisito va soddisfatto.
  /// Nel passato = requisito non soddisfatto (NO-GO).
  DateTime? deadline,

  /// Etichetta semestre in corso, es. "2/2026".
  String label,
});

DateTime _semStart(DateTime d) => DateTime(d.year, d.month <= 6 ? 1 : 7, 1);
DateTime _semEnd(DateTime start) => start.month == 1
    ? DateTime(start.year, 6, 30)
    : DateTime(start.year, 12, 31);
DateTime _prevStart(DateTime start) => start.month == 1
    ? DateTime(start.year - 1, 7, 1)
    : DateTime(start.year, 1, 1);
DateTime _nextStart(DateTime start) => start.month == 1
    ? DateTime(start.year, 7, 1)
    : DateTime(start.year + 1, 1, 1);

/// Perdite currency T per lo storico: un semestre chiuso entro [end] sotto
/// [minHours] la fa perdere a fine semestre (la scadenza di
/// [flightSemesterState]); `regained` è il volo che in un semestre successivo
/// porta le ore del semestre al minimo (null = ancora persa a [end]).
List<({DateTime lost, DateTime? regained})> flightSemesterLosses(
  Iterable<FlightAct> acts,
  double minHours,
  DateTime end,
) {
  final sorted = acts.where((a) => !a.date.isAfter(end)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final out = <({DateTime lost, DateTime? regained})>[];
  if (sorted.isEmpty) return out;
  DateTime? lost;
  for (
    var s = _semStart(sorted.first.date);
    !s.isAfter(end);
    s = _nextStart(s)
  ) {
    var hours = 0.0;
    DateTime? reached;
    for (final a in sorted) {
      if (a.date.isBefore(s) || a.date.isAfter(_semEnd(s))) continue;
      hours += a.hours;
      if (hours >= minHours) {
        reached = a.date;
        break;
      }
    }
    if (lost != null && reached != null) {
      out.add((lost: lost, regained: reached));
      lost = null;
    }
    if (lost == null && reached == null && !_nextStart(s).isAfter(end)) {
      lost = _semEnd(s);
    }
  }
  if (lost != null) out.add((lost: lost, regained: null));
  return out;
}

FlightSemesterState flightSemesterState(
  Iterable<FlightAct> acts,
  double minHours,
  DateTime now,
) {
  final cur = _semStart(now);
  final prev = _prevStart(cur);
  double sum(DateTime from, DateTime to) => acts
      .where((a) => !a.date.isBefore(from) && !a.date.isAfter(to))
      .fold(0.0, (s, a) => s + a.hours);

  final hours = sum(cur, _semEnd(cur));
  final prevHours = sum(prev, _semEnd(prev));
  final hasPrior = acts.any((a) => a.date.isBefore(cur));
  final label = '${cur.month == 1 ? 1 : 2}/${cur.year}';

  DateTime? deadline;
  if (hours >= minHours) {
    // Semestre in corso a posto: prossima scadenza a fine semestre successivo.
    deadline = _semEnd(_nextStart(cur));
  } else if (prevHours >= minHours || (acts.isNotEmpty && !hasPrior)) {
    // Semestre precedente a posto (o primo semestre di attività): si può
    // ancora recuperare fino a fine semestre in corso.
    deadline = _semEnd(cur);
  } else if (hasPrior) {
    // Semestre precedente chiuso con meno del minimo: NO-GO.
    deadline = _semEnd(prev);
  }
  return (hours: hours, prevHours: prevHours, deadline: deadline, label: label);
}
