# AVES Tecnici (aves_currency) — Flutter App

Repo app: `rdagmr98/AVES` | Repo dati: `rdagmr98/aves-data`
Vault Obsidian: `C:\Users\Gianmarco\ObsidianVault\AVES Corsi\AVES Tecnici.md`

## Release workflow
```
flutter build apk --release
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
| `name_format.dart` | forma canonica nomi: Nome = iniziale maiuscola, COGNOME = maiuscolo (applicata in `GhDbService.saveUsers`) |

## Modelli
- `user_models.dart`: utente + abilitazioni
- `activity_models.dart`: attività, ore, tipologia
- `reference_models.dart`: elicotteri, capacità (TOB capabilities)

## STATO SESSIONE — aggiornato 2026-10-23
- Web Push ad app chiusa (`e00810f`): `push/notify.mjs` eseguito dall'Action `push.yml` di `aves-data` sui commit `nuove notifiche` (`GhDbService.pushCommitMsg`, `saveNotifications(fresh: true)`); sottoscrizioni in `db/push_subscriptions.json`, SW `web/push/sw.js`, `NotificationService.enablePush`. Secret VAPID solo su `aves-data`. Nota vault `AVES Corsi/Web Push via Action repo dati 2026-10-23.md`.
- Dashboard GO / NO GO: dettaglio utente = `_ServiceRecordDialog`.
  - Privilegi aggiungibili e modificabili per qualsiasi utente (`_editPrivileges`, `172b5a6`).
  - Attività validate con ricerca, filtri, modifica ed eliminazione; seminari eliminabili.
  - Usa `ActivityService.updateMaintenanceActivity`. Nota vault `AVES Corsi/Tecnici scheda stato di servizio 2026-10-23.md`.
- Deploy = solo web via GitHub Actions (`deploy.yml`): `flutter build apk` non applicabile (progetto senza cartella android). Storico sessioni precedenti nel vault (`AVES Corsi/AVES Tecnici.md`).
