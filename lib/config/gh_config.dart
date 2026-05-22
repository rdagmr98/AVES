class GhConfig {
  static const String owner = 'rdagmr98';
  static const String dataRepo = 'aves-data';
  // Fine-Grained PAT with read-only access to aves-data repo.
  // User must create this PAT and replace the placeholder.
  static const String readPat = 'REPLACE_WITH_READ_ONLY_PAT';
  static const String passwordSalt = 'aves_salt_2024';

  static bool get isConfigured => readPat != 'REPLACE_WITH_READ_ONLY_PAT';
}
