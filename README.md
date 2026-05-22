# AVES Currency

Applicazione Flutter Web per la gestione della currency del personale AVES, con autenticazione Supabase, workflow di approvazione utenti e dashboard dedicate per operatori e amministratori privilegi/equipaggi.

## Funzionalità principali

- accesso e registrazione utenti con approvazione amministrativa
- dashboard utente con stato currency, notifiche e accesso rapido alle attività
- dashboard amministrative separate per privilegi ed equipaggi
- inserimento, validazione e consultazione di attività manutentive, di volo e TOB
- gestione criteri currency, ruoli e assegnazioni operative

## Requisiti

- Flutter SDK installato e disponibile nel PATH
- account Supabase
- browser moderno per esecuzione web

## Setup Supabase

1. Crea un progetto su [Supabase](https://supabase.com/).
2. In **SQL Editor** esegui nell'ordine:
   - `supabase/schema.sql`
   - `supabase/seed.sql`
   - `supabase/rls.sql`
3. In **Project Settings > API** copia:
   - `Project URL`
   - `anon public key`
4. Apri `lib/config/supabase_config.dart` e sostituisci i placeholder con i valori reali.
5. In **Authentication > Users** crea i due account amministrativi:
   - `admin.privilegi@aves.esercito.it` / `AvesPriv2024!`
   - `admin.equipaggi@aves.esercito.it` / `AvesCrew2024!`
6. Dopo aver creato gli utenti admin, esegui questa query per inizializzare i profili:

```sql
INSERT INTO user_profiles (id, nome, cognome, role, is_approved, is_active)
VALUES
  ((SELECT id FROM auth.users WHERE email = 'admin.privilegi@aves.esercito.it'),
   'Admin', 'Privilegi', 'admin_priv', TRUE, TRUE),
  ((SELECT id FROM auth.users WHERE email = 'admin.equipaggi@aves.esercito.it'),
   'Admin', 'Equipaggi', 'admin_crew', TRUE, TRUE);
```

## Credenziali amministrative iniziali

- Admin Privilegi: `admin.privilegi@aves.esercito.it` / `AvesPriv2024!`
- Admin Equipaggi: `admin.equipaggi@aves.esercito.it` / `AvesCrew2024!`

## Avvio in sviluppo

```bash
flutter pub get
flutter run -d chrome
```

Se Supabase non è configurato, l'app mostra una schermata di setup con le istruzioni essenziali.

## Qualità del codice

Comandi consigliati durante lo sviluppo:

```bash
dart format lib\ testflutter analyze
flutter test
```

## Deploy

Il repository include il workflow GitHub Actions `.github/workflows/deploy.yml`.

Flusso suggerito:

1. Verifica localmente con `flutter analyze` e `flutter test`.
2. Esegui commit e push sul branch desiderato.
3. Lascia che GitHub Actions costruisca e pubblichi l'app secondo la configurazione del workflow.

## Struttura progetto

- `lib/app.dart`: bootstrap applicazione, provider Riverpod e routing GoRouter
- `lib/providers/`: stato applicativo per autenticazione e criteri currency
- `lib/screens/`: schermate per autenticazione, dashboard, attività, profilo e amministrazione
- `lib/services/`: integrazione Supabase per auth, utenti, activity e notification
- `supabase/`: schema, seed e policy RLS

## Note operative

- gli utenti appena registrati restano in stato **pending approval** finché un amministratore non li approva
- gli amministratori possono inserire attività già validate per conto degli utenti
- i criteri currency sono modificabili dalla dashboard admin privilegi
