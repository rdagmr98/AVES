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
| `currency_history.dart` | perdite currency ricavate dalle attività (`currencyLosses`, puro); storico in `CurrencyService.getCurrencyHistory` / `getFlightCurrencyHistory` |
| `widgets/currency_event_tile.dart` | riga dello storico currency (manutenzione e volo) |
| `widgets/flight_course_dialog.dart` | `registerFlightCourse`: corso volo T/capacità, per la T i voli del corso contano per il semestre |
| `widgets/activity_edit_dialog.dart` | dialog unico di modifica attività in attesa (manutenzione, volo, TOB, seminari), da Valida e dashboard privilegi admin |

## Modelli
- `user_models.dart`: utente + abilitazioni
- `activity_models.dart`: attività, ore, tipologia
- `reference_models.dart`: elicotteri, capacità (TOB capabilities)

## STATO SESSIONE — aggiornato 2026-10-25
- 2026-10-25 (12):
  - Gestione Utenti: i privilegi aggiunti aprono `_registerOjt`, un OJT precompilato con `proposedOjt` calcolato prima del salvataggio. "Senza OJT" assegna i privilegi senza attività.
  - `CurrencyEvent.delete`: dallo storico si eliminano, con conferma (`CurrencyEventTile(onDeleted:)`), OJT, corsi e righe revocate. Perdite calcolate e righe attive non si eliminano.
  - Tasto "Registra OJT" della dashboard privilegi solo con `isExpired`.
  - Nota vault `AVES Corsi/Tecnici Gestione Utenti OJT e storico eliminabile 2026-10-25.md`.
- 2026-10-24 (11): licenze e privilegi modificati dall'utente (profilo, registrazione) vanno in `privilege_requests.json` (`PrivilegeRequest`, `UserService.requestPrivilegeChange`). L'admin li approva in Valida attività > Privilegi con un click: gli OJT vengono registrati come attività validate e il tipo è dato da `proposedOjt` (storico vuoto = iniziale, privilegio già avuto = ripristino, altrimenti nuovo). In alternativa usa il dialog di modifica. Rimossi Aggiungi/modifica privilegi dalla dashboard admin. Nota vault `AVES Corsi/Tecnici approvazione privilegi con OJT 2026-10-24.md`.
- 2026-10-24 (10): tipi licenza AER(EP).P-66 / EMAR 66 in `reference.json` (`licenseTypes` id 1 A1, 2 B1.1, 3 B1.3, 4 B2, 5 C, 6 A2, 7 A3, 8 A4, 9 B1.2, 10 B1.4), ordinati con `compareLicenseCode` (`models/reference_models.dart`: C, B1.1-B1.4, B2, A1-A4) in menu, liste utente, P-66 e matrice privilegi. 95 licenze importate dall'Annesso 1 CS (TMA = B1.3, TEA = B2, UT = C), solo in append. Nota vault `AVES Corsi/Tecnici licenze P-66 da Annesso 2026-10-24.md`.
- 2026-10-24 (9): rimossi vista estesa della dashboard (`view_prefs.dart`, interruttore nel profilo), schermate flotta/dettaglio elicottero e `PrivilegeGridWidget`: resta solo la dashboard compatta. Card currency in rilievo: cornice piena da 2,5 px nel colore di stato (stesso dell'anello avatar) con luce/ombra diagonale, alone colorato, ombra scura, riflesso in alto e GO luminoso.
- Screenshot solo con `lib/demo_main.dart` (escluso da git, MockClient, PUT scartate): mai avviare l'app in locale col PAT reale, `readPat` scrive anche.
- Deploy = solo web via GitHub Actions (`deploy.yml`): `flutter build apk` non applicabile (progetto senza cartella android). Storico sessioni precedenti nel vault (`AVES Corsi/AVES Tecnici.md`).
