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

## STATO SESSIONE — aggiornato 2026-10-24
- 2026-10-24 (9): rimossi vista estesa della dashboard (`view_prefs.dart`, interruttore nel profilo), schermate flotta/dettaglio elicottero e `PrivilegeGridWidget`: resta solo la dashboard compatta. Card currency in rilievo: cornice piena da 2,5 px nel colore di stato (stesso dell'anello avatar) con luce/ombra diagonale, alone colorato, ombra scura, riflesso in alto e GO luminoso.
- 2026-10-24 (8): dashboard compatta, miniature elicotteri. `_HelicopterTiles` sotto le currency usa i ritagli senza sfondo in `assets/images/helicopters/<code>.webp` (crediti in `assets/CREDITS.md`). Il tocco apre `_HelicopterSheet`, che mostra i privilegi con GO/NO GO (`getPerPrivilegeCurrency`; PTA o seminario bloccano tutti), le qualifiche di volo e le licenze. Card currency con bordo, alone e gradiente diagonale nel colore di stato. Catalogo ridotto a `helicopterImage`/`catalogAccent`; le descrizioni sono nel vault (`AVES Corsi/Catalogo elicotteri descrizioni.md`). Nota vault `AVES Corsi/Tecnici dashboard miniature elicotteri 2026-10-24.md`.
- 2026-10-24 (7): dashboard compatta stile iOS, con anello di stato sull'avatar e anello di progresso sulle currency (`4c5ad0b`). Nota vault `AVES Corsi/Tecnici dashboard compatta stile iOS 2026-10-24.md`.
- Screenshot solo con `lib/demo_main.dart` (escluso da git, MockClient, PUT scartate): mai avviare l'app in locale col PAT reale, `readPat` scrive anche.
- Deploy = solo web via GitHub Actions (`deploy.yml`): `flutter build apk` non applicabile (progetto senza cartella android). Storico sessioni precedenti nel vault (`AVES Corsi/AVES Tecnici.md`).
