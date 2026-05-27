// test/crypto_test.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rawKey = 'd694b158908b35cc05cf4f4b39ab0e3c';
  final key = Key.fromUtf8(rawKey);
  // FIXED: allZerosOfLength produces deterministic zero IV, NOT random
  final iv = IV.allZerosOfLength(16);
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

  test('IV is all zeros (deterministic)', () {
    final ivBytes = iv.bytes;
    // ignore: avoid_print
    print(
      'IV bytes (hex): ${ivBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
    );
    expect(ivBytes, equals(List.filled(16, 0)));
  });

  test('decrypt admincsl (Python-encrypted value)', () {
    // This value was encrypted by Python with key+IV=zeros
    const base64Cipher = 'G0vdCPfTIvJHXWkprPBdsg==';
    final decrypted = encrypter.decrypt64(base64Cipher, iv: iv);
    // ignore: avoid_print
    print('Decrypted admincsl: "$decrypted"');
    expect(decrypted.trim(), equals('admincsl'));
  });

  test('decrypt adminvolo (Python-encrypted value)', () {
    const base64Cipher = 'nodDZhKR5r81T+Te0beJ1Q==';
    final decrypted = encrypter.decrypt64(base64Cipher, iv: iv);
    // ignore: avoid_print
    print('Decrypted adminvolo: "$decrypted"');
    expect(decrypted.trim(), equals('adminvolo'));
  });

  test('encrypt admincsl matches Python output', () {
    const plaintext = 'admincsl';
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    // ignore: avoid_print
    print('Dart encrypt("admincsl"): ${encrypted.base64}');
    expect(encrypted.base64, equals('G0vdCPfTIvJHXWkprPBdsg=='));
  });

  test('password hash aves2024 matches expected', () {
    const password = 'aves2024';
    const salt = 'aves_salt_2024';
    final bytes = utf8.encode(password + salt);
    final hash = sha256.convert(bytes).toString();
    // ignore: avoid_print
    print('Hash: $hash');
    expect(
      hash,
      equals(
        '910d7b6e7b6065c3e612e30f2345225c7ec02b4177b078ce036e5be40b6fc45c',
      ),
    );
  });
}
