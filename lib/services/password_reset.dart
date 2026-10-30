import 'dart:math';

/// Riga da marcare per una richiesta di reset; -1 se l'utente non esiste, è
/// disattivato, non ha ancora un account (pre-registrato), ha già una richiesta
/// aperta o è un admin (la gestione utenti elenca solo il ruolo user).
int resetRequestIndex(List<Map<String, dynamic>> users, String login) {
  final target = login.trim().toLowerCase();
  final i = users.indexWhere((u) {
    final username = (u['username'] as String?)?.trim() ?? '';
    final key = username.isNotEmpty
        ? username
        : (u['numero_licenza'] as String?)?.trim() ?? '';
    return key.toLowerCase() == target;
  });
  if (i < 0 ||
      users[i]['role'] != 'user' ||
      users[i]['is_active'] == false ||
      (users[i]['password_hash'] as String? ?? '').isEmpty ||
      users[i]['password_reset_requested_at'] != null) {
    return -1;
  }
  return i;
}

/// Password temporanea da comunicare a voce: senza caratteri ambigui (0/O, 1/l/I).
String generateTempPassword() {
  const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
  final random = Random.secure();
  return List.generate(
    8,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}
