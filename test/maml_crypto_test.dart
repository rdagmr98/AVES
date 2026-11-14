import 'dart:io';
import 'dart:typed_data';

import 'package:aves_currency/services/crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final c = CryptoService();

  test('scansione: cifra e decifra uguale, IV diverso a ogni volta', () {
    final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
    final a = c.encryptBytes(data);
    expect(c.decryptBytes(a), data);
    expect(c.encryptBytes(data), isNot(a));
  });

  // File prodotto dall'import Python: MAML_BIN=<path .bin> flutter test ...
  final bin = Platform.environment['MAML_BIN'];
  test('decifra il formato dell\'import Python', () {
    final pdf = c.decryptBytes(File(bin!).readAsBytesSync());
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  }, skip: bin == null);
}
