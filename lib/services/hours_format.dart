// Ore di volo: salvate in ore decimali, inserite e mostrate come ore:minuti.

/// "1:35", "1.35", "1,35", "1h35" → 1 h 35 min; "1h" → 1 h; solo cifre ("95")
/// → minuti. I minuti dopo il separatore vanno a 2 cifre (00-59): "1.5" è
/// ambiguo (1,5 h o 1 h 05?) e viene rifiutato invece di indovinare.
double? parseHours(String s) {
  final t = s.trim().toLowerCase().replaceAll(' ', '');
  if (RegExp(r'^\d+$').hasMatch(t)) return int.parse(t) / 60;
  final m = RegExp(r'^(\d+)[:.,h](\d{2})?(?:m|min)?$').firstMatch(t);
  if (m == null) return null;
  final min = int.parse(m[2] ?? '0');
  if (min > 59) return null;
  return int.parse(m[1]!) + min / 60;
}

int _minutes(double h) => (h * 60).round();

/// 1.5833 → "1:35"
String formatHours(double h) {
  final t = _minutes(h);
  return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
}

/// 1.5833 → "1 h 35 min", 0.5 → "30 min", 2 → "2 h"
String describeHours(double h) {
  final t = _minutes(h);
  final hh = t ~/ 60, mm = t % 60;
  if (hh == 0) return '$mm min';
  return mm == 0 ? '$hh h' : '$hh h $mm min';
}
