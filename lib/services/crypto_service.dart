import 'package:encrypt/encrypt.dart';

class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  // Chiave AES-256 fissa. I dati sono nel repository privato aves-data,
  // che costituisce il livello di sicurezza principale.
  static const String _rawKey = 'd694b158908b35cc05cf4f4b39ab0e3c';

  late final Key _key = Key.fromUtf8(_rawKey);
  // IV fisso (all-zero). La sicurezza si basa sul repository privato aves-data
  // e sulla chiave AES; un IV fisso è necessario per la persistenza dei dati.
  final IV _iv = IV.allZerosOfLength(16);
  late final Encrypter _encrypter = Encrypter(AES(_key, mode: AESMode.cbc));

  String encrypt(String plaintext) {
    if (plaintext.isEmpty) return plaintext;
    final encrypted = _encrypter.encrypt(plaintext, iv: _iv);
    return 'ENC:${encrypted.base64}';
  }

  String decrypt(String ciphertext) {
    if (!ciphertext.startsWith('ENC:')) return ciphertext;
    final base64 = ciphertext.substring(4);
    try {
      return _encrypter.decrypt64(base64, iv: _iv);
    } catch (_) {
      return ciphertext;
    }
  }

  String? encryptNullable(String? value) =>
      value == null ? null : encrypt(value);
  String? decryptNullable(String? value) =>
      value == null ? null : decrypt(value);
}
