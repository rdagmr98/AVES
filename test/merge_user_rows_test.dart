import 'package:aves_currency/services/merge_user_rows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var seq = 100;
  int nextId(_) => seq++;
  const keys = ['helicopter_type_id', 'privilege_type_id'];
  Map<String, dynamic> row(int id, String user, int h, int p) => {
    'id': id,
    'user_id': user,
    'helicopter_type_id': h,
    'privilege_type_id': p,
    'active': true,
    'created_at': '2020-01-01',
  };
  Map<String, dynamic> item(int h, int p) => {
    'helicopter_type_id': h,
    'privilege_type_id': p,
  };

  test('salva: tenute con created_at, tolte disattivate, nuove aggiunte', () {
    final all = [
      row(1, 'u', 1, 1),
      row(2, 'u', 1, 2),
      row(3, 'altro', 1, 2),
      {...row(4, 'u', 1, 3), 'active': false},
    ];
    final out = mergeUserRows(
      all,
      'u',
      [item(1, 1), item(1, 3)],
      keys,
      const ['expiry_date'],
      append: false,
      nextId: nextId,
    );
    expect(out[0], same(all[0])); // invariata: niente nuovo created_at
    expect(out[1]['active'], false); // revocata, non cancellata
    expect(out[2], same(all[2])); // altri utenti intatti
    expect(out[3], same(all[3])); // storico revoche intatto
    expect(out.length, 5); // (1,3) riassegnato = riga nuova
    expect(out[4]['active'], true);
    expect(out[4]['privilege_type_id'], 3);
  });

  test('append: nessuna revoca, solo righe mancanti', () {
    final all = [row(1, 'u', 1, 1), row(2, 'u', 1, 2)];
    final out = mergeUserRows(
      all,
      'u',
      [item(1, 1), item(2, 1)],
      keys,
      const [],
      append: true,
      nextId: nextId,
    );
    expect(out.where((r) => r['active'] == true).length, 3);
  });

  test('campi aggiornati solo se presenti nell\'item', () {
    final all = [
      {...row(1, 'u', 1, 1), 'expiry_date': '2027-01-01'},
    ];
    final keep = mergeUserRows(
      all,
      'u',
      [item(1, 1)],
      keys,
      const ['expiry_date'],
      append: false,
      nextId: nextId,
    );
    expect(keep.single['expiry_date'], '2027-01-01');
    final upd = mergeUserRows(
      all,
      'u',
      [
        {...item(1, 1), 'expiry_date': '2028-01-01'},
      ],
      keys,
      const ['expiry_date'],
      append: false,
      nextId: nextId,
    );
    expect(upd.single['expiry_date'], '2028-01-01');
    expect(upd.single['created_at'], '2020-01-01');
  });
}
