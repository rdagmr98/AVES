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
| `currency_history.dart` | perdite currency ricavate dalle attività (`currencyLosses`, puro); seminari: GO solo con NAM e MHF entrambi validi (`seminarTypeExpiries`, `seminarCovers`); categoria B1.3/B2 con `catCovers` (nullo = tutte); storico in `CurrencyService.getCurrencyHistory` / `getFlightCurrencyHistory` |
| `password_reset.dart` | funzioni pure del reset: password temporanea, ricerca della riga del richiedente (test in `test/password_reset_test.dart`) |
| `widgets/currency_event_tile.dart` | riga dello storico currency (manutenzione e volo) |
| `widgets/flight_course_dialog.dart` | `registerFlightCourse`: corso volo T/capacità, per la T i voli del corso contano per il semestre |
| `widgets/activity_edit_dialog.dart` | dialog unico di modifica attività in attesa (manutenzione, volo, TOB, seminari), da Valida e dashboard privilegi admin; `insertMaintenanceActivity`/`insertSeminar`/`insertFlight` = inserimento admin già validato dalla scheda; `confirmAction` = conferma condivisa |

## Modelli
- `user_models.dart`: utente + abilitazioni
- `activity_models.dart`: attività, ore, tipologia
- `reference_models.dart`: elicotteri, capacità (TOB capabilities)

## STATO SESSIONE — aggiornato 2026-11-06
- 2026-11-06 (23): audit, fix `75d43a3`: righe revocate fuori da `getMaintenanceCurrency`, notifiche di currency lette che non tornano più (`episode` = scadenza, `currencyNotificationSent`), tipo MTB, poligono MTB da `MDB_POLIGONO`. Aperto: MTB con o senza ore di volo (dashboard e PDF divergono). Nota vault `AVES Corsi/Tecnici audit 2026-11-06.md`.
- 2026-11-06 (22): scheda admin volo, sezione «Voli validati» (voli e TOB) con modifica/elimina e «+ Volo» (`insertFlight`), `18ffad6`. `/admin/insert`: un'unica tab «Volo» con l'equipaggio a ruoli (T/MTB/TOB volo base/TOB per capacità) e la ricerca, tab singole rimosse (`8e5125f`). Prossimo: prova in produzione (nota vault `AVES Corsi/Tecnici admin volo modifica cancella e inserimento voli 2026-11-06.md`).
- 2026-11-06 (21): volo TOB senza capacità salvato in `tob_acts` con capacità nulla («Volo base», `2338cec`), non più in `flight.json`; riga di Ardia spostata (`aves-data` `3467674`). Trappola: le versioni vecchie vanno in errore su capacità nulla, prima deploy poi dati. Prossimo: prova in produzione (vedi hub vault).
- 2026-11-06 (20): 3 h a semestre anche per i TOB senza T (`68ca884`): `flight_t` in `getFullCurrency` e `admin_crew_dashboard` con T o TOB, storico idem. Rischio presa profilo per nome accettato dall'utente, privilegi richiedibili per i nuovi. Prossimo: verificare in produzione su un TOB, attivazione Scimonello.
- 2026-11-06 (19): registrazione dei pre-registrati per nome e cognome (`802f69b`): `_checkName` in `register_screen.dart`, `signUp(claimUserId:)`, privilegi in sola lettura col profilo agganciato. Scimonello riportato a pre-registrato (`aves-data` `16c6e11`). Prossimo: provarlo con Scimonello. Nota vault `AVES Corsi/Tecnici registrazione per nome e cognome 2026-11-06.md`.
- 2026-11-05 (18): scheda persona admin volo come admincsl (`_CrewRecordDialog`, `35261b4`). Voli TOB con ore che valgono per la T, TOB senza capacità, scadenze SMI/visita mansione nel profilo, precarico dei pre-registrati in `register_screen.dart` (invia solo le differenze). MDB→MTB solo nelle etichette. Niente più «Tutti i privilegi»: attività null espanse per privilegio (`aves-data` `c208554`), scadenza NAM/MHF nella scheda admincsl (`5ed152e`). Dati allineati all'Annesso 29/10 (`aves-data` `63d921d`). Nota vault `AVES Corsi/Tecnici volo TOB ore SMI e precarico pre-registrati 2026-11-05.md`.
- 2026-11-02 (17): categoria B1.3/B2 su privilegi e attività (`3e8d72d`). `license_type_id` è facoltativo, nullo = tutte. Il confronto passa solo da `catCovers` (`currency_history.dart`). Fabbri è allineato in `aves-data` `8e01146`. Nota vault `AVES Corsi/Tecnici categoria su privilegi e attività 2026-11-02.md`.
- 2026-10-30 (16): richiesta reset anche dal cambio password a login effettuato (`57cd246`): link nel dialog del profilo (nascosto agli admin) e in `/change-password`, via `AuthProvider.requestPasswordReset`. Provato nella demo (SnackBar ok), persistenza no.
- 2026-10-30 (15): reset password da admin e richiesta dal login (`f62a6db`). Gate `mustChangePassword` nel `redirect` di `lib/app.dart`, verso `/change-password`. Tasto `_resetPassword` nel dettaglio utente (`user_management_screen.dart`). Admin e pre-registrati esclusi. Persistenza non provata nella demo: da provare in produzione. Nota vault `AVES Corsi/Reset password admin e richiesta utente 2026-10-30.md`.
- 2026-10-27 (14): tastiera Android. Flutter web sostituisce il meta viewport, quindi `interactive-widget=resizes-content` va riapplicato su `flutter-first-frame` in `web/index.html`. Lì anche: body fermo a `scrollTop` 0 e blur del campo quando la tastiera si chiude, solo sui resize `isTrusted`. Seminari NAM+MHF entrambi per il GO (`ca1f806`). Nota vault `AVES Corsi/Tecnici tastiera Android fascia vuota 2026-10-27.md`.
- Screenshot solo con `lib/demo_main.dart` (escluso da git, MockClient, PUT scartate): mai avviare l'app in locale col PAT reale, `readPat` scrive anche.
- Deploy = solo web via GitHub Actions (`deploy.yml`): `flutter build apk` non applicabile (progetto senza cartella android). Storico sessioni precedenti nel vault (`AVES Corsi/AVES Tecnici.md`).
