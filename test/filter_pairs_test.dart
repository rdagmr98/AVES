import 'package:aves_currency/widgets/filter_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 169 = 1, 206 = 2; pre/post = 10, altro = 11
  const user = [(1, 11), (2, 10)]; // pre/post solo sul 206

  test('privilegio su un altro elicottero non passa', () {
    expect(matchPairs(user, [1], [10], all: false), isFalse);
    expect(matchPairs(user, [1], [10], all: true), isFalse);
    expect(matchPairs(user, [2], [10], all: true), isTrue);
  });

  test('almeno uno / tutti', () {
    expect(matchPairs(user, [1, 2], [10], all: false), isTrue);
    expect(matchPairs(user, [1, 2], [10], all: true), isFalse);
    expect(matchPairs(user, <int>[], [10, 11], all: true), isTrue);
    expect(matchPairs(user, [1], <int>[], all: true), isTrue);
  });

  test('nessun filtro', () {
    expect(
      matchPairs(const <(int, int)>[], <int>[], <int>[], all: true),
      isTrue,
    );
  });
}
