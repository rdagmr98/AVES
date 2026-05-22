# AVES Currency

Applicazione Flutter Web per la gestione della currency del personale AVES. Il backend usa il repository privato GitHub `rdagmr98/aves-data` come database JSON tramite GitHub Contents API.

## Architettura

- app Flutter Web: questo repository
- data repo privato: `rdagmr98/aves-data`
- lettura: Fine-Grained PAT read-only configurato in `lib/config/gh_config.dart`
- scrittura: Fine-Grained PAT inserito una volta dall'amministratore tramite dashboard/settings e salvato nel browser
- sessione: browser `localStorage` (`aves_session`)
- write PAT: browser `localStorage` (`aves_write_pat`)

## 1. Creare il repository dati `aves-data`

1. Crea il repository privato `rdagmr98/aves-data`.
2. Crea la cartella `db/` nella root del repository.
3. Copia nel repository dati tutti i file presenti in `data_setup/db/` di questo progetto.
4. Esegui commit e push del contenuto iniziale.

Struttura richiesta:

```text
db/
  reference.json
  users.json
  licenses.json
  privileges.json
  crew.json
  tob_user_caps.json
  maintenance.json
  flight.json
  tob_acts.json
  criteria.json
  notifications.json
```

## 2. Seed iniziale

In questo repository trovi già i seed pronti in `data_setup/db/`.

- `reference.json`: dati di riferimento AVES
- `users.json`: due account admin iniziali con password hash SHA-256 + salt
- `criteria.json`: criteri currency di default
- altri file: array vuoti pronti all'uso

## 3. GitHub Actions secret per il Read PAT

Il Read PAT **non va nel codice sorgente**: viene iniettato al momento del build da GitHub Actions tramite `--dart-define`.

1. Vai su **GitHub → AVES repo → Settings → Secrets and variables → Actions**
2. Aggiungi un secret chiamato `AVES_READ_PAT` con il tuo token GitHub (scope `repo` è sufficiente, oppure un Fine-Grained PAT con Contents: Read su `aves-data`)
3. GitHub Actions lo inietterà automaticamente ad ogni push su `main`

### Write PAT (solo per gli amministratori)

Crea un Classic PAT o Fine-Grained PAT con accesso **read/write** al solo repository `aves-data`.

Permessi minimi:
- Repository access: solo `aves-data`
- Contents: `Read and write`

> Il Write PAT non va nel codice sorgente. L'admin lo inserisce una volta sola dalla dashboard con il pulsante **Configura Write PAT**: viene salvato nel browser locale (`localStorage`).

## 4. Deploy automatico

Ogni push su `main` fa partire GitHub Actions che:
1. Builda l'app Flutter Web con il Read PAT iniettato via `--dart-define`
2. Pubblica su GitHub Pages automaticamente

Non è necessario modificare `gh_config.dart`.

## 5. Credenziali amministrative iniziali

Cambia le password al primo accesso.

- Admin Privilegi: `admin.privilegi@aves.it` / `AvesPriv2024!`
- Admin Equipaggi: `admin.equipaggi@aves.it` / `AvesCrew2024!`

## 6. Avvio in sviluppo

```bash
flutter pub get
flutter analyze
flutter run -d chrome
```

## 7. Deploy su GitHub Pages

Il workflow `.github/workflows/deploy.yml` esegue già:

```bash
flutter pub get
flutter build web --release --base-href /AVES/
```

Per pubblicare:

1. verifica localmente `flutter analyze`
2. esegui commit e push su `main`
3. lascia che GitHub Actions pubblichi `build/web` su GitHub Pages

## Note operative

- gli utenti appena registrati restano in attesa di approvazione admin
- tutte le scritture su JSON richiedono il Write PAT nel browser corrente
- i dati vengono caricati in memoria all'avvio dall'app tramite `GhDbService`
