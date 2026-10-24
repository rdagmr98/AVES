import 'package:aves_currency/services/flight_semester.dart';
import 'package:flutter_test/flutter_test.dart';

FlightAct _a(String d, double h) => (date: DateTime.parse(d), hours: h);

void main() {
  final now = DateTime(2026, 10, 16); // secondo semestre 2026

  test('semestre in corso a posto: scadenza a fine semestre successivo', () {
    final s = flightSemesterState([_a('2026-08-01', 3)], 3, now);
    expect(s.hours, 3);
    expect(s.deadline, DateTime(2027, 6, 30));
    expect(s.label, '2/2026');
  });

  test(
    'semestre precedente a posto, corrente non ancora: scade a fine semestre',
    () {
      final s = flightSemesterState(
        [_a('2026-03-01', 3.5), _a('2026-09-01', 1)],
        3,
        now,
      );
      expect(s.hours, 1);
      expect(s.prevHours, 3.5);
      expect(s.deadline, DateTime(2026, 12, 31));
    },
  );

  test(
    'non conta 180 gg rolling: 3h a fine giugno non coprono il 2° semestre',
    () {
      // 180 gg dal 2026-06-25 arriverebbero a dicembre, ma il semestre è nuovo.
      final s = flightSemesterState([_a('2026-06-25', 3)], 3, now);
      expect(s.hours, 0);
      expect(
        s.deadline,
        DateTime(2026, 12, 31),
      ); // prev a posto, si può recuperare
    },
  );

  test(
    'semestre precedente chiuso sotto il minimo: NO-GO (scadenza nel passato)',
    () {
      final s = flightSemesterState(
        [_a('2026-02-01', 2), _a('2025-11-01', 5)],
        3,
        now,
      );
      expect(s.prevHours, 2);
      expect(s.deadline, DateTime(2026, 6, 30));
      expect(s.deadline!.isBefore(now), isTrue);
    },
  );

  test(
    'recupero: 3h nel semestre in corso riportano GO anche con prev insufficiente',
    () {
      final s = flightSemesterState(
        [_a('2026-02-01', 1), _a('2026-07-10', 3)],
        3,
        now,
      );
      expect(s.deadline, DateTime(2027, 6, 30));
    },
  );

  test('primo semestre di attività: grazia fino a fine semestre', () {
    final s = flightSemesterState([_a('2026-09-01', 1)], 3, now);
    expect(s.deadline, DateTime(2026, 12, 31));
  });

  test('nessun volo: nessuna scadenza (NO-GO)', () {
    expect(flightSemesterState([], 3, now).deadline, isNull);
  });

  test('primo semestre dell\'anno: precedente è il 2° dell\'anno prima', () {
    final s = flightSemesterState(
      [_a('2025-12-31', 3), _a('2026-01-02', 1)],
      3,
      DateTime(2026, 2, 1),
    );
    expect(s.prevHours, 3);
    expect(s.hours, 1);
    expect(s.label, '1/2026');
    expect(s.deadline, DateTime(2026, 6, 30));
  });

  group('flightSemesterLosses', () {
    test('semestre chiuso sotto il minimo: persa a fine semestre, ripresa '
        'al volo che riporta il semestre a 3 h', () {
      final out = flightSemesterLosses(
        [
          _a('2025-08-01', 3),
          _a('2026-02-01', 1),
          _a('2026-09-01', 2),
          _a('2026-10-01', 1.5),
        ],
        3,
        now,
      );
      expect(out, [
        (lost: DateTime(2026, 6, 30), regained: DateTime(2026, 10, 1)),
      ]);
    });

    test('ancora persa: nessun recupero nel semestre in corso', () {
      expect(flightSemesterLosses([_a('2025-08-01', 3)], 3, now), [
        (lost: DateTime(2026, 6, 30), regained: null),
      ]);
    });

    test('semestre in corso non chiuso e nessun volo = nessuna perdita', () {
      expect(flightSemesterLosses([_a('2026-08-01', 1)], 3, now), isEmpty);
      expect(flightSemesterLosses([], 3, now), isEmpty);
    });
  });
}
