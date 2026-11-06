import 'package:aves_currency/models/activity_models.dart';
import 'package:aves_currency/services/useful_days.dart';
import 'package:flutter_test/flutter_test.dart';

MaintenanceActivity act(
  String user,
  DateTime date, {
  DateTime? from,
  DateTime? to,
  String? desc,
  String? ol,
  bool validated = true,
}) => MaintenanceActivity(
  userId: user,
  helicopterTypeId: 1,
  privilegeTypeId: 1,
  activityDate: date,
  dateFrom: from,
  dateTo: to,
  description: desc,
  ordineLavoro: ol,
  isValidated: validated,
  helicopterCode: 'AB206',
  privilegeName: 'Manutenzione T/M · B1.3',
  userFullName: user,
);

void main() {
  final d = DateTime.new;

  test('periodo espanso per giorno, tagliato sul registro', () {
    final rows = usefulDayRows(
      [act('ROSSI', d(2026, 3, 30), from: d(2026, 3, 30), to: d(2026, 4, 2))],
      d(2026, 4, 1),
      d(2026, 4, 30),
    );
    expect(rows.map((r) => r.day), [d(2026, 4, 1), d(2026, 4, 2)]);
    expect(rows.first.qualifications, {'AB206 B1.3'});
    expect(rows.first.tasks, {'Manutenzione T/M'});
  });

  test(
    'stesso tecnico e giorno = una riga; esclusi annesso e non validate',
    () {
      final rows = usefulDayRows(
        [
          act(
            'VERDI',
            d(2026, 4, 3),
            desc: 'ispezione giornaliera',
            ol: 'WO 12',
          ),
          act('VERDI', d(2026, 4, 3), desc: 'ritiro ricambi'),
          act('BIANCHI', d(2026, 4, 3)),
          act(
            'NERI',
            d(2026, 4, 3),
            desc: 'Riallineamento currency da Annesso',
          ),
          act('GIALLI', d(2026, 4, 3), validated: false),
        ],
        d(2026, 4, 1),
        d(2026, 4, 30),
      );
      expect(rows.map((r) => r.name), ['BIANCHI', 'VERDI']);
      expect(rows.last.tasks, {'ispezione giornaliera', 'ritiro ricambi'});
      expect(rows.last.orders, {'WO 12'});
    },
  );
}
