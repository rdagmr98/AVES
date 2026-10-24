import 'package:aves_currency/models/user_models.dart';
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
  test('scadenza seminario: ultimo validato + 2 anni, mai svolto in cima', () {
    final exp = seminarExpiries([
      {'user_id': 'a', 'seminar_date': '2025-03-10', 'is_validated': true},
      {'user_id': 'a', 'seminar_date': '2024-01-01', 'is_validated': true},
      {'user_id': 'b', 'seminar_date': '2024-06-01', 'is_validated': true},
      {'user_id': 'c', 'seminar_date': '2026-01-01', 'is_validated': false},
    ]);
    expect(exp, {'a': DateTime(2027, 3, 10), 'b': DateTime(2026, 6, 1)});
    UserProfile u(String id, String cognome) => UserProfile(
      id: id,
      nome: 'X',
      cognome: cognome,
      role: 'user',
      createdAt: d(2026),
      updatedAt: d(2026),
    );
    final users = [u('a', 'A'), u('b', 'B'), u('c', 'D'), u('z', 'C')];
    sortByExpiry(users, exp);
    expect(users.map((x) => x.id), ['z', 'c', 'b', 'a']);
  });
}
