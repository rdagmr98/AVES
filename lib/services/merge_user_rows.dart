/// Righe di [userId] allineate a [items] (chiave = [keys]). Quelle già attive
/// restano con id e `created_at` (senza [append] si aggiornano i [fields]
/// presenti nell'item), le nuove si aggiungono e, senza [append], quelle tolte
/// passano ad `active: false` invece di sparire: licenze, privilegi, equipaggi
/// e capacità restano lo storico di assegnazioni e revoche.
List<Map<String, dynamic>> mergeUserRows(
  List<Map<String, dynamic>> all,
  String userId,
  List<Map<String, dynamic>> items,
  List<String> keys,
  List<String> fields, {
  required bool append,
  required int Function(Iterable<Map<String, dynamic>> rows) nextId,
}) {
  final now = DateTime.now().toIso8601String();
  bool same(Map<String, dynamic> a, Map<String, dynamic> b) =>
      keys.every((k) => a[k] == b[k]);
  final result = <Map<String, dynamic>>[];
  for (final r in all) {
    if (append || r['user_id'] != userId || r['active'] == false) {
      result.add(r);
      continue;
    }
    final item = items.where((i) => same(r, i)).firstOrNull;
    final changed = {
      for (final f in fields)
        if (item != null && item.containsKey(f) && item[f] != r[f]) f: item[f],
    };
    result.add(
      item == null
          ? {...r, 'active': false, 'updated_at': now}
          : changed.isEmpty
          ? r
          : {...r, ...changed, 'updated_at': now},
    );
  }
  for (final item in items) {
    if (result.any(
      (r) => r['user_id'] == userId && r['active'] != false && same(r, item),
    )) {
      continue;
    }
    result.add({
      'id': nextId(result),
      'user_id': userId,
      for (final k in keys) k: item[k],
      for (final f in fields) f: item[f],
      'active': true,
      'created_at': now,
      'updated_at': now,
    });
  }
  return result;
}
