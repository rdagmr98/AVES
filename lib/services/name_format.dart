/// Forma canonica dei nomi utente: Nome = iniziale maiuscola per parola
/// ("Maria Grazia", "D'Angelo"), COGNOME = tutto maiuscolo.
String _collapse(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

String formatNome(String s) => _collapse(s).toLowerCase().replaceAllMapped(
  RegExp(r"(^|[ \-'’])(\p{L})", unicode: true),
  (m) => '${m[1]}${m[2]!.toUpperCase()}',
);

String formatCognome(String s) => _collapse(s).toUpperCase();

/// Normalizza nome/cognome dei soli utenti `role == 'user'` (gli admin
/// restano com'erano). Ritorna la stessa istanza se non cambia nulla.
Map<String, dynamic> normalizeUserNames(Map<String, dynamic> user) {
  if (user['role'] != 'user') return user;
  final nome = user['nome'] as String?;
  final cognome = user['cognome'] as String?;
  final n = nome == null ? null : formatNome(nome);
  final c = cognome == null ? null : formatCognome(cognome);
  if (n == nome && c == cognome) return user;
  return {...user, 'nome': n, 'cognome': c};
}
