import 'package:aves_currency/services/name_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nome: iniziale maiuscola per parola', () {
    expect(formatNome('mario'), 'Mario');
    expect(formatNome('MARIA GRAZIA'), 'Maria Grazia');
    expect(formatNome("d'angelo"), "D'Angelo");
    expect(formatNome('  gian-marco  '), 'Gian-Marco');
    expect(formatNome('ÈMILIO'), 'Èmilio');
  });

  test('cognome: tutto maiuscolo, spazi collassati', () {
    expect(formatCognome('de  luca'), 'DE LUCA');
    expect(formatCognome(' Rossi '), 'ROSSI');
  });

  test('normalizeUserNames: solo role user, identità se già a posto', () {
    final ok = {'role': 'user', 'nome': 'Mario', 'cognome': 'ROSSI'};
    expect(identical(normalizeUserNames(ok), ok), isTrue);
    final bad = {'role': 'user', 'nome': 'mARIO', 'cognome': 'rossi'};
    expect(normalizeUserNames(bad)['nome'], 'Mario');
    expect(normalizeUserNames(bad)['cognome'], 'ROSSI');
    final admin = {'role': 'admin_crew', 'nome': 'mARIO', 'cognome': 'rossi'};
    expect(identical(normalizeUserNames(admin), admin), isTrue);
  });
}
