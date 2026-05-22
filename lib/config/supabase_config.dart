// CONFIGURAZIONE SUPABASE
//
// ISTRUZIONI SETUP:
// 1. Vai su https://supabase.com e crea un account gratuito
// 2. Crea un nuovo progetto (scegli una password sicura)
// 3. Vai su SQL Editor ed esegui nell'ordine:
//    - supabase/schema.sql
//    - supabase/seed.sql
//    - supabase/rls.sql
// 4. In Project Settings > API copia:
//    - Project URL  → incolla in supabaseUrl
//    - anon public  → incolla in supabaseAnonKey
// 5. Crea i due admin in Authentication > Users:
//    - admin.privilegi@aves.esercito.it / AvesPriv2024!
//    - admin.equipaggi@aves.esercito.it / AvesCrew2024!
// 6. Vai su SQL Editor ed esegui:
//    INSERT INTO user_profiles (id, nome, cognome, role, is_approved, is_active)
//    VALUES
//      ((SELECT id FROM auth.users WHERE email='admin.privilegi@aves.esercito.it'),
//       'Admin','Privilegi','admin_priv',TRUE,TRUE),
//      ((SELECT id FROM auth.users WHERE email='admin.equipaggi@aves.esercito.it'),
//       'Admin','Equipaggi','admin_crew',TRUE,TRUE);

class SupabaseConfig {
  static const String url = 'YOUR_SUPABASE_URL';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';

  static bool get isConfigured =>
      url != 'YOUR_SUPABASE_URL' && anonKey != 'YOUR_SUPABASE_ANON_KEY';
}
