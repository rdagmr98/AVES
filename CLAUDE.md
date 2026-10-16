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

## STATO SESSIONE — aggiornato 2026-10-16
- Latenze rimosse: `GhDbService._writeFile` ora accoda e ritorna subito (nessun `await` di PUT nei ~80 call site), `reloadAll` sostituito da `refresh()`, GET con `?_=` anti-cache e timeout 30 s, permesso notifiche non più atteso in `signIn`/`initialize`, avviso `beforeunload` se ci sono salvataggi in coda + snackbar su errore di salvataggio (`lib/app.dart`). Limite: F5 entro 1-3 s da un salvataggio protetta solo dall'avviso del browser.
- `web/index.html`: ricarica automatica una volta quando il service worker installa una nuova build (prima l'utente vedeva la versione vecchia dalla cache fino al secondo reload). Card Volo T: sottotitolo "semestre in corso".
- Currency volo T ora a semestri di calendario (gen-giu, lug-dic), >= ore minime per semestre; NO-GO se semestre precedente chiuso sotto minimo e corrente sotto minimo; primo semestre di attività = grazia. MDB_FLIGHT resta rolling 180 gg (da decidere se passare a semestri).
- Nomi utenti (`role == 'user'`) normalizzati in `GhDbService.saveUsers` + `signUp`; migrazione dei dati esistenti al primo login admin (`UserService.normalizeAllNames`).
- Deploy = solo web via GitHub Actions (`deploy.yml`): `flutter build apk` non applicabile (progetto senza cartella android).
