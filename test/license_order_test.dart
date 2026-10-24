import 'package:aves_currency/models/reference_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('categorie da C ad A, numeri crescenti', () {
    final codes = [
      'A1',
      'B2',
      'C',
      'B1.3',
      'A4',
      'B1.1',
      'A3',
      'B1.4',
      'A2',
      'B1.2',
    ]..sort(compareLicenseCode);
    expect(codes, [
      'C',
      'B1.1',
      'B1.2',
      'B1.3',
      'B1.4',
      'B2',
      'A1',
      'A2',
      'A3',
      'A4',
    ]);
  });
}
