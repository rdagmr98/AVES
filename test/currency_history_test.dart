import 'package:aves_currency/models/activity_models.dart';
import 'package:aves_currency/models/reference_models.dart';
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

  test('OJT: iniziale tutti, ripristino scaduti, nuovo non assegnati', () {
    final privs = [
      for (final id in [1, 2, 3])
        PrivilegeType(id: id, code: '$id', name: 'P$id'),
    ];
    PrivilegeCurrencyStatus s(int heli, int priv, CurrencyStatusEnum st) =>
        PrivilegeCurrencyStatus(
          helicopterTypeId: heli,
          helicopterCode: 'H$heli',
          privilegeTypeId: priv,
          privilegeName: 'P$priv',
          status: CurrencyStatus(status: st, label: ''),
        );
    final cur = [
      s(10, 1, CurrencyStatusEnum.expired),
      s(10, 2, CurrencyStatusEnum.valid),
      s(20, 3, CurrencyStatusEnum.expired),
    ];
    Iterable<int> o(int t, int heli) =>
        ojtOptions(ojtTypes[t], heli, privs, cur).keys;
    expect(o(0, 10), [1, 2, 3]);
    expect(o(1, 10), [1]);
    expect(o(2, 10), [3]);
    expect(o(1, 30), isEmpty);
    expect(o(2, 30), [1, 2, 3]);
  });

  test('tipo OJT proposto dallo storico privilegi', () {
    Map<String, dynamic> r(int h, int p, {bool active = true}) => {
      'helicopter_type_id': h,
      'privilege_type_id': p,
      'active': active,
    };
    expect(proposedOjt([], 10, [1, 2]), {1: ojtTypes[0], 2: ojtTypes[0]});
    final history = [r(10, 1), r(10, 2, active: false), r(20, 3)];
    expect(proposedOjt(history, 10, [1, 2, 3]), {
      2: ojtTypes[1],
      3: ojtTypes[2],
    });
  });
}
