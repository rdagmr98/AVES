class GhConfig {
  static const String owner = 'rdagmr98';
  static const String dataRepo = 'aves-data';
  // Injected at build time via --dart-define=READ_PAT=...
  // Never hardcode a real token here.
  static const String readPat = String.fromEnvironment(
    'READ_PAT',
    defaultValue: 'REPLACE_WITH_READ_ONLY_PAT',
  );
  static const String passwordSalt = 'aves_salt_2024';

  static bool get isConfigured => readPat != 'REPLACE_WITH_READ_ONLY_PAT';
}
