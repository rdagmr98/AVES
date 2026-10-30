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
| `currency_history.dart` | perdite currency ricavate dalle attività (`currencyLosses`, puro); seminari: GO solo con NAM e MHF entrambi validi (`seminarTypeExpiries`, `seminarCovers`); storico in `CurrencyService.getCurrencyHistory` / `getFlightCurrencyHistory` |
| `password_reset.dart` | funzioni pure del reset: password temporanea, ricerca della riga del richiedente (test in `test/password_reset_test.dart`) |
| `widgets/currency_event_tile.dart` | riga dello storico currency (manutenzione e volo) |
| `widgets/flight_course_dialog.dart` | `registerFlightCourse`: corso volo T/capacità, per la T i voli del corso contano per il semestre |
| `widgets/activity_edit_dialog.dart` | dialog unico di modifica attività in attesa (manutenzione, volo, TOB, seminari), da Valida e dashboard privilegi admin; `insertMaintenanceActivity`/`insertSeminar` = inserimento admin già validato dalla scheda |

## Modelli
- `user_models.dart`: utente + abilitazioni
- `activity_models.dart`: attività, ore, tipologia
- `reference_models.dart`: elicotteri, capacità (TOB capabilities)

## STATO SESSIONE — aggiornato 2026-10-30
- 2026-10-30 (16): richiesta reset anche dal cambio password a login effettuato (`57cd246`): link nel dialog del profilo (nascosto agli admin) e in `/change-password`, via `AuthProvider.requestPasswordReset`. Provato nella demo (SnackBar ok), persistenza no.
- 2026-10-30 (15): reset password da admin e richiesta dal login (`f62a6db`). Gate `mustChangePassword` nel `redirect` di `lib/app.dart`, verso `/change-password`. Tasto `_resetPassword` nel dettaglio utente (`user_management_screen.dart`). Admin e pre-registrati esclusi. Persistenza non provata nella demo: da provare in produzione. Nota vault `AVES Corsi/Reset password admin e richiesta utente 2026-10-30.md`.
- 2026-10-27 (14): tastiera Android. Flutter web sostituisce il meta viewport, quindi `interactive-widget=resizes-content` va riapplicato su `flutter-first-frame` in `web/index.html`. Lì anche: body fermo a `scrollTop` 0 e blur del campo quando la tastiera si chiude, solo sui resize `isTrusted`. Seminari NAM+MHF entrambi per il GO (`ca1f806`). Nota vault `AVES Corsi/Tecnici tastiera Android fascia vuota 2026-10-27.md`.
- Screenshot solo con `lib/demo_main.dart` (escluso da git, MockClient, PUT scartate): mai avviare l'app in locale col PAT reale, `readPat` scrive anche.
- Deploy = solo web via GitHub Actions (`deploy.yml`): `flutter build apk` non applicabile (progetto senza cartella android). Storico sessioni precedenti nel vault (`AVES Corsi/AVES Tecnici.md`).
