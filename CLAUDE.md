# AVES Tecnici (aves_currency) — Flutter App

Repo app: `rdagmr98/AVES` | Repo dati: `rdagmr98/aves-data`
Vault Obsidian: `C:\Users\Gianmarco\ObsidianVault\AVES Corsi\AVES Tecnici.md`

## Release workflow
Deploy solo web: il push su main avvia `deploy.yml` (GitHub Actions). Nessuna cartella android, quindi niente APK.
```
git add lib/...
git commit -m "..."
git push origin main   ← autorizzato, sempre senza chiedere
```

## Architettura
- Flutter app: "Gestione Currency Manutentori e Equipaggi"
- Stack: `go_router` + `flutter_riverpod` + `provider`
- `GhDbService`: singleton, GitHub API REST, AES-CBC PII; scritture in coda ottimistica non bloccante (cache subito, PUT in background, coalescing per file, retry con backoff, `pendingSaves`/`saveError`), `refresh()` incrementale (listing + solo file con sha diverso)
- DB: `rdagmr98/aves-data`

## Schermate
| Cartella | Contenuto |
|----------|-----------|
| `screens/auth/` | login |
| `screens/dashboard/` | home |
| `screens/helicopters/` | `my_fleet_screen.dart`, `helicopter_detail_screen.dart` |
| `screens/activities/` | `my_activities_screen.dart`, `add_activity_screen.dart`, `pta_screen.dart` |
| `screens/admin/` | gestione utenti |
| `screens/profile/` | profilo utente |

## Servizi
| Servizio | Ruolo |
|----------|-------|
| `currency_service.dart` | calcola currency manutentori/equipaggi |
| `activity_service.dart` | CRUD attività svolte |
| `pta_service.dart` | gestione PTA (Part Task Trainer / attività specifiche) |
| `p66_service.dart` | Part-66 qualifiche |
| `report_service.dart` | generazione report |
| `notification_service.dart` | notifiche scadenze |
| `gh_db_service.dart` | GitHub API, cache, SHA versioning |
| `crypto_service.dart` | AES-CBC encrypt/decrypt PII |
| `flight_semester.dart` | currency volo T a semestri di calendario (funzione pura, test in `test/flight_semester_test.dart`) |
| `hours_format.dart` | ore salvate decimali, inserite/mostrate h:mm (`parseHours`: `1:35`/`1.35`/`1h35`, solo cifre = minuti); widget `widgets/hours_field.dart` |
| `name_format.dart` | forma canonica nomi: Nome = iniziale maiuscola, COGNOME = maiuscolo (applicata in `GhDbService.saveUsers`) |
| `merge_user_rows.dart` | setter righe utente con soft delete (`active: false` + `updated_at`), conserva `created_at` = assegnazione |
| `currency_history.dart` | perdite currency ricavate dalle attività (`currencyLosses`, puro); storico in `CurrencyService.getCurrencyHistory` / `getFlightCurrencyHistory` |
| `widgets/currency_event_tile.dart` | riga dello storico currency (manutenzione e volo) |
| `widgets/flight_course_dialog.dart` | `registerFlightCourse`: corso volo T/capacità, per la T i voli del corso contano per il semestre |
| `widgets/activity_edit_dialog.dart` | dialog unico di modifica attività in attesa (manutenzione, volo, TOB, seminari), da Valida e dashboard privilegi admin |
| `view_prefs.dart` | preferenza vista dashboard (`compactDashboard`, default compatta, `shared_preferences`), caricata in `main()` prima di `runApp` |

## Modelli
- `user_models.dart`: utente + abilitazioni
- `activity_models.dart`: attività, ore, tipologia
- `reference_models.dart`: elicotteri, capacità (TOB capabilities)

## STATO SESSIONE — aggiornato 2026-10-24
- 2026-10-24 (4): partecipanti dei seminari per scadenza (`67b28d8`, `seminarExpiries`/`sortByExpiry` in `currency_history.dart`). Redesign mobile (`77d613d`): `widgets/form_parts.dart` (`FormHeader`, `LabeledField`, `SaveBar`) usato da `add_activity_screen` e `profile_screen`, con Salva/Invia fissi in basso e label sopra i campi. Nota vault `AVES Corsi/Tecnici redesign mobile e seminari per scadenza 2026-10-24.md`.
- 2026-10-24 (5): privilegi a selezione multipla + "Seleziona tutti" e label dentro il campo (`BoxInputBorder`, `a8e144a`); admin modifica attività in attesa (`e54f8bc`); dashboard utente compatta di default (`_CompactGrid`, `_Badge`, interruttore Profilo > Account, `bb0b79b`). Nota vault `AVES Corsi/Tecnici privilegi multipli label e modifica attività 2026-10-24.md`.
- Screenshot solo con `lib/demo_main.dart` (escluso da git, MockClient, PUT scartate): mai avviare l'app in locale col PAT reale, `readPat` scrive anche.
- Deploy = solo web via GitHub Actions (`deploy.yml`): `flutter build apk` non applicabile (progetto senza cartella android). Storico sessioni precedenti nel vault (`AVES Corsi/AVES Tecnici.md`).
