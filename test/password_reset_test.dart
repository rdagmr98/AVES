import 'package:aves_currency/services/password_reset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final users = <Map<String, dynamic>>[
    {'username': 'Rossi', 'role': 'user', 'password_hash': 'x'},
    {'numero_licenza': 'MAML-1', 'role': 'user', 'password_hash': 'x'},
    {'username': 'prereg', 'role': 'user', 'password_hash': ''},
    {'username': 'bianchi', 'role': 'user', 'password_hash': 'x', 'is_active': false},
    {
      'username': 'verdi',
      'role': 'user',
      'password_hash': 'x',
      'password_reset_requested_at': '2026-10-30',
    },
    {'username': 'capo', 'role': 'admin_priv', 'password_hash': 'x'},
  ];

  test('richiesta accettata solo per utente attivo con account e senza richiesta aperta', () {
    expect(resetRequestIndex(users, ' rossi '), 0);
    expect(resetRequestIndex(users, 'maml-1'), 1);
    expect(resetRequestIndex(users, 'prereg'), -1);
    expect(resetRequestIndex(users, 'bianchi'), -1);
    expect(resetRequestIndex(users, 'verdi'), -1);
    expect(resetRequestIndex(users, 'capo'), -1);
    expect(resetRequestIndex(users, 'nessuno'), -1);
  });

  test('password temporanea di 8 caratteri non ambigui', () {
    expect(generateTempPassword(), matches(RegExp(r'^[a-km-np-z2-9]{8}$')));
  });
}
