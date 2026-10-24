import 'package:aves_currency/services/currency_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final d = DateTime.utc; // niente salti ora legale nelle somme di giorni

  test('perdita alla data ultima + periodo, ripristino all\'attività dopo', () {
    final out = currencyLosses(
      [d(2026, 6, 1), d(2026, 1, 1), d(2026, 2, 1)],
      60,
      d(2026, 7, 1),
    );
    expect(out, [(lost: d(2026, 4, 2), regained: d(2026, 6, 1))]);
  });

  test('ancora persa a fine periodo', () {
    expect(currencyLosses([d(2026, 1, 1)], 30, d(2026, 3, 1)), [
      (lost: d(2026, 1, 31), regained: null),
    ]);
  });

  test('nessuna attività o sempre corrente = nessuna perdita', () {
    expect(currencyLosses([], 30, d(2026, 3, 1)), isEmpty);
    expect(
      currencyLosses([d(2026, 1, 1), d(2026, 1, 20)], 30, d(2026, 2, 10)),
      isEmpty,
    );
  });
}
