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

## Modelli
- `user_models.dart`: utente + abilitazioni
- `activity_models.dart`: attività, ore, tipologia
- `reference_models.dart`: elicotteri, capacità (TOB capabilities)

## STATO SESSIONE — aggiornato 2026-10-24
- Opzioni admin (`_openOptions` in `screens/dashboard/admin_privileges_dashboard.dart`): unità organizzative, tipi attività OL (`activityTypes` in reference.json, `UserService.getActivityTypes/saveActivityType`), elicotteri da mostrare (`view_helicopter_ids` nel profilo in users.json, filtra GO / NO GO, predefinito matrice e `PRIVILEGE_EXPIRED_ADMIN`). Report PDF rimosso, seminari contati tra le attività in attesa, T sul 169 = B + D (`UserService.tFamilyOf`). `93c31bf`. Nota vault `AVES Corsi/Tecnici richieste opzioni admin 2026-10-24.md`.
- 2026-10-23: push (banner su `WebNotificationService.pushActive`, `b469c61`), OL a due colonne con squadra per privilegio, seminari NAM/MHF importati (scadenza 2 anni di calendario), import Annesso 1, ore h:mm, `_ServiceRecordDialog` nel GO / NO GO. Note vault `AVES Corsi/Tecnici * 2026-10-23.md`.
- Screenshot solo con `lib/demo_main.dart` (escluso da git, MockClient, PUT scartate): mai avviare l'app in locale col PAT reale, `readPat` scrive anche.
- Deploy = solo web via GitHub Actions (`deploy.yml`): `flutter build apk` non applicabile (progetto senza cartella android). Storico sessioni precedenti nel vault (`AVES Corsi/AVES Tecnici.md`).
