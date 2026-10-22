import 'package:aves_currency/services/hours_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseHours: ore:minuti con vari separatori', () {
    for (final s in ['1:35', '1.35', '1,35', '1h35', ' 1 h 35 ', '1h35m']) {
      expect(parseHours(s), closeTo(1 + 35 / 60, 1e-9), reason: s);
    }
    expect(parseHours('0.35'), closeTo(35 / 60, 1e-9));
    expect(parseHours('2h'), 2);
    expect(parseHours('10:00'), 10);
  });

  test('parseHours: solo cifre = minuti', () {
    expect(parseHours('95'), closeTo(95 / 60, 1e-9));
    expect(parseHours('0'), 0);
  });

  test('parseHours: rifiuta ambigui e invalidi', () {
    for (final s in ['', '1.5', '1:60', 'abc', '1:355', '-1:00']) {
      expect(parseHours(s), isNull, reason: s);
    }
  });

  test('format/describe: round-trip senza deriva', () {
    expect(formatHours(parseHours('1:35')!), '1:35');
    expect(formatHours(1.5), '1:30');
    expect(formatHours(0.0833333), '0:05');
    expect(describeHours(1 + 35 / 60), '1 h 35 min');
    expect(describeHours(0.5), '30 min');
    expect(describeHours(2), '2 h');
  });
}
