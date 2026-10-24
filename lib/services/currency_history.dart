enum CurrencyEventKind { assigned, revoked, restored, lost }

/// Evento dello storico currency di un utente (timeline della scheda).
typedef CurrencyEvent = ({
  DateTime date,
  CurrencyEventKind kind,
  String title,
  String? note,
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
