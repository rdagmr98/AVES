import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/gh_config.dart';
import 'crypto_service.dart';
import 'name_format.dart';

class GhDbService {
  static final GhDbService _instance = GhDbService._internal();

  factory GhDbService() => _instance;

  GhDbService._internal();

  static const String _base =
      'https://api.github.com/repos/${GhConfig.owner}/${GhConfig.dataRepo}/contents/db';

  final Map<String, Map<String, dynamic>> _cache = {};
  final _crypto = CryptoService();

  // ignore: unused_field
  String? _writePat;

  static String hashPassword(String password) {
    final bytes = utf8.encode(password + GhConfig.passwordSalt);
    return sha256.convert(bytes).toString();
  }

  static const _files = [
    'reference.json',
    'users.json',
    'licenses.json',
    'privileges.json',
    'crew.json',
    'tob_user_caps.json',
    'maintenance.json',
    'flight.json',
    'tob_acts.json',
    'criteria.json',
    'notifications.json',
    'push_subscriptions.json',
    'pta.json',
    'pta_acknowledgments.json',
    'account_deletion_requests.json',
    'seminars.json',
  ];

  Future<void> init() async {
    _cache.clear();
    await Future.wait(_files.map((f) async => _cache[f] = await _fetchFile(f)));
  }

  /// Riallinea la cache a GitHub senza svuotarla: un solo listing e poi si
  /// scaricano solo i file il cui sha è cambiato. I file con scritture in
  /// coda o in corso si saltano, così i dati ottimistici non vengono mai
  /// sovrascritti con la versione vecchia.
  Future<void> refresh() async {
    // Ritenta in background i salvataggi falliti, senza bloccare il chiamante.
    for (final f in _pending.keys.toList()) {
      _startDrain(f);
    }
    final remote = await _remoteShas();
    if (remote == null) return; // offline: si resta sulla cache
    bool busy(String f) => _pending.containsKey(f) || _drains.containsKey(f);
    await Future.wait(
      _files.where((f) => !busy(f) && (remote[f] ?? '') != _getSha(f)).map((
        f,
      ) async {
        final entry = await _fetchFile(f);
        // una scrittura può partire durante il fetch
        if (!busy(f)) _cache[f] = entry;
      }),
    );
  }

  Future<void> setWritePat(String pat) async {}

  Future<void> clearWritePat() async {}

  bool get hasWritePat => GhConfig.readPat.trim().isNotEmpty;

  Map<String, dynamic> _encryptUser(Map<String, dynamic> user) => {
    ...user,
    'nome': _crypto.encryptNullable(user['nome'] as String?),
    'cognome': _crypto.encryptNullable(user['cognome'] as String?),
    'email': _crypto.encryptNullable(user['email'] as String?),
    'numero_licenza': _crypto.encryptNullable(
      user['numero_licenza'] as String?,
    ),
    'username': _crypto.encryptNullable(user['username'] as String?),
  };

  Map<String, dynamic> _decryptUser(Map<String, dynamic> user) => {
    ...user,
    'nome': _crypto.decryptNullable(user['nome'] as String?),
    'cognome': _crypto.decryptNullable(user['cognome'] as String?),
    'email': _crypto.decryptNullable(user['email'] as String?),
    'numero_licenza': _crypto.decryptNullable(
      user['numero_licenza'] as String?,
    ),
    'username': _crypto.decryptNullable(user['username'] as String?),
  };

  dynamic _normalizeLoadedData(String fileName, dynamic data) {
    if (fileName == 'users.json') {
      final items = List<Map<String, dynamic>>.from(data as List? ?? const []);
      final decrypted = items.map(_decryptUser).toList(growable: false);
      final stillEncrypted = decrypted.any((user) {
        final username = user['username'] as String?;
        return username != null && username.startsWith('ENC:');
      });
      if (stillEncrypted) {
        debugPrint(
          'WARNING: Users appear to be encrypted - decryption may have failed',
        );
      }
      return decrypted;
    }
    return data;
  }

  // L'API GitHub risponde con Cache-Control max-age=60: senza un parametro
  // sempre diverso il browser serve la risposta vecchia di fino a un minuto.
  Uri _fresh(String url) => Uri.parse(url).replace(
    queryParameters: {'_': DateTime.now().microsecondsSinceEpoch.toString()},
  );

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${GhConfig.readPat}',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  Future<Map<String, dynamic>> _fetchFile(String fileName) async {
    final response = await http
        .get(_fresh('$_base/$fileName'), headers: _headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final sha = json['sha'] as String;
      final content = utf8.decode(
        base64.decode((json['content'] as String).replaceAll('\n', '')),
      );
      final data = _normalizeLoadedData(fileName, jsonDecode(content));
      return {'data': data, 'sha': sha, 'base': _baseOf(data)};
    }

    if (response.statusCode == 404) {
      final data = _emptyDataFor(fileName);
      return {'data': data, 'sha': '', 'base': _baseOf(data)};
    }

    throw Exception(
      'Errore GitHub API ${response.statusCode} durante il caricamento di $fileName: ${response.body}',
    );
  }

  dynamic _emptyDataFor(String fileName) {
    if (fileName == 'reference.json') {
      return <String, dynamic>{};
    }
    return <dynamic>[];
  }

  dynamic _getData(String fileName) => _cache[fileName]?['data'];

  String _getSha(String fileName) => _cache[fileName]?['sha'] as String? ?? '';

  // ── Coda di scrittura ottimistica ──────────────────────────────────────────
  // La cache viene aggiornata subito e la PUT su GitHub avviene in background;
  // salvataggi ravvicinati sullo stesso file vengono fusi nell'ultimo payload,
  // quindi N salvataggi consecutivi costano 1-2 PUT invece di N.

  /// Numero di file con scritture in corso o in attesa (avviso alla chiusura).
  static final ValueNotifier<int> pendingSaves = ValueNotifier<int>(0);

  /// Ultimo errore di salvataggio in background (null = tutto ok).
  static final ValueNotifier<String?> saveError = ValueNotifier<String?>(null);

  /// file → messaggio di commit della scrittura in attesa. Il payload è
  /// sempre la cache corrente del file, quindi salvataggi ravvicinati si
  /// fondono nell'ultimo.
  final Map<String, String> _pending = {};
  final Map<String, Future<void>> _drains = {};
  final _rng = Random();

  void _updatePendingCount() {
    pendingSaves.value = {..._drains.keys, ..._pending.keys}.length;
  }

  Future<void> _writeFile(String fileName, dynamic data, String msg) async {
    _cache[fileName] = {...?_cache[fileName], 'data': data};
    _pending[fileName] = msg;
    saveError.value = null;
    _startDrain(fileName);
  }

  /// Payload spedito a GitHub (users.json: cache in chiaro, scrittura cifrata).
  dynamic _wireFor(String fileName, dynamic data) => fileName == 'users.json'
      ? [
          for (final u in data as List)
            _encryptUser(Map<String, dynamic>.from(u)),
        ]
      : data;

  /// Ultima versione nota del server, record per record (id → json): serve
  /// alla fusione a tre vie sui conflitti. Null se il file non è una lista di
  /// record con id (reference.json): lì si sovrascrive come prima.
  static Map<Object?, String>? _baseOf(dynamic data) {
    if (data is! List) return null;
    final base = <Object?, String>{};
    for (final r in data) {
      if (r is! Map || r['id'] == null) return null;
      base[r['id']] = jsonEncode(r);
    }
    return base;
  }

  /// Conflitto 409: un altro client ha scritto nel frattempo. Invece di
  /// sovrascrivere con la cache locale, fonde per id:
  /// - record nuovi altrui → aggiunti;
  /// - record invariati qui → presi dal server (modificati o eliminati altrove);
  /// - record modificati/aggiunti/eliminati qui → vince il locale.
  Future<void> _mergeRemote(String fileName) async {
    final remote = await _fetchFile(fileName);
    final base = _cache[fileName]?['base'] as Map<Object?, String>?;
    final local = _getData(fileName);
    var data = local;
    if (base != null &&
        remote['base'] != null &&
        local is List &&
        _baseOf(local) != null) {
      final remoteList = remote['data'] as List;
      final remoteById = {for (final r in remoteList) (r as Map)['id']: r};
      final localIds = {for (final r in local) (r as Map)['id']};
      data = [
        for (final r in local)
          if (base[(r as Map)['id']] != jsonEncode(r))
            r
          else if (remoteById.containsKey(r['id']))
            remoteById[r['id']],
        for (final r in remoteList)
          if (!base.containsKey((r as Map)['id']) &&
              !localIds.contains(r['id']))
            r,
      ];
    }
    _cache[fileName] = {
      'data': data,
      'sha': remote['sha'],
      'base': remote['base'],
    };
  }

  void _startDrain(String fileName) {
    if (!_drains.containsKey(fileName) && _pending.containsKey(fileName)) {
      _drains[fileName] = _drain(fileName).whenComplete(() {
        _drains.remove(fileName);
        _updatePendingCount();
      });
    }
    _updatePendingCount();
  }

  Future<void> _drain(String fileName) async {
    while (_pending.containsKey(fileName)) {
      final msg = _pending.remove(fileName)!;
      try {
        await _putToGitHub(fileName, msg);
      } catch (e) {
        // Non perdere la scrittura: la cache resta quella locale e verrà
        // ritentata al prossimo salvataggio o da refresh().
        _pending.putIfAbsent(fileName, () => msg);
        saveError.value = 'Salvataggio $fileName non riuscito: $e';
        return;
      }
    }
  }

  static const int _maxWriteAttempts = 6;

  /// PUT della cache corrente con retry ed exponential backoff: sui conflitti
  /// (409) fonde le modifiche remote, sugli errori transitori (403/429/5xx,
  /// timeout, rete) ritenta.
  Future<void> _putToGitHub(String fileName, String msg) async {
    for (var attempt = 1; attempt <= _maxWriteAttempts; attempt++) {
      final sha = _getSha(fileName);
      final data = _getData(fileName);
      final sentBase = _baseOf(data); // istantanea prima dell'await
      final body = <String, dynamic>{
        'message': msg,
        'content': base64.encode(
          utf8.encode(jsonEncode(_wireFor(fileName, data))),
        ),
        if (sha.isNotEmpty) 'sha': sha,
      };

      final http.Response res;
      try {
        res = await http
            .put(
              Uri.parse('$_base/$fileName'),
              headers: {..._headers, 'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 30));
      } catch (e) {
        if (attempt == _maxWriteAttempts) {
          throw Exception('Rete non raggiungibile scrivendo $fileName: $e');
        }
        await _backoff(attempt);
        continue;
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Solo sha e base: la cache può già contenere dati più recenti in
        // attesa di scrittura.
        _cache[fileName] = {
          ...?_cache[fileName],
          'sha':
              ((jsonDecode(res.body) as Map)['content'] as Map)['sha']
                  as String,
          'base': sentBase,
        };
        return;
      }

      final retryable =
          res.statusCode == 409 ||
          res.statusCode == 403 ||
          res.statusCode == 429 ||
          res.statusCode >= 500;
      if (!retryable || attempt == _maxWriteAttempts) {
        if (res.statusCode == 409) {
          throw ConflictException(
            'Conflitto di scrittura dopo $attempt tentativi.',
          );
        }
        throw Exception('Errore GitHub API ${res.statusCode}: ${res.body}');
      }

      if (res.statusCode == 409) {
        await _mergeRemote(fileName);
      } else {
        await _backoff(attempt);
      }
    }
    throw Exception(
      'Salvataggio $fileName non riuscito dopo $_maxWriteAttempts tentativi.',
    );
  }

  Future<void> _backoff(int attempt) async {
    final ms = min(1000 * (1 << (attempt - 1)), 16000);
    await Future<void>.delayed(Duration(milliseconds: ms + _rng.nextInt(400)));
  }

  /// nome file → sha corrente, da un solo listing della cartella dati.
  /// Null se la rete o l'API non rispondono.
  Future<Map<String, String>?> _remoteShas() async {
    try {
      final res = await http
          .get(_fresh(_base), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return {
        for (final e
            in (jsonDecode(res.body) as List).cast<Map<String, dynamic>>())
          e['name'] as String: e['sha'] as String,
      };
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> get referenceData =>
      (_getData('reference.json') as Map<String, dynamic>?) ?? {};

  List<Map<String, dynamic>> get users =>
      List<Map<String, dynamic>>.from(_getData('users.json') as List? ?? []);

  Future<void> saveUsers(List<Map<String, dynamic>> input) async {
    // Punto unico di scrittura utenti: nomi sempre in forma canonica.
    final data = input.map(normalizeUserNames).toList(growable: false);
    await _writeFile('users.json', data, 'aggiornamento profili utenti');
  }

  Future<void> saveReference(Map<String, dynamic> data) =>
      _writeFile('reference.json', data, 'aggiornamento dati di riferimento');

  List<Map<String, dynamic>> get licenses =>
      List<Map<String, dynamic>>.from(_getData('licenses.json') as List? ?? []);

  Future<void> saveLicenses(List<Map<String, dynamic>> data) =>
      _writeFile('licenses.json', data, 'aggiornamento licenze');

  List<Map<String, dynamic>> get privileges => List<Map<String, dynamic>>.from(
    _getData('privileges.json') as List? ?? [],
  );

  Future<void> savePrivileges(List<Map<String, dynamic>> data) =>
      _writeFile('privileges.json', data, 'aggiornamento privilegi');

  List<Map<String, dynamic>> get crew =>
      List<Map<String, dynamic>>.from(_getData('crew.json') as List? ?? []);

  Future<void> saveCrew(List<Map<String, dynamic>> data) =>
      _writeFile('crew.json', data, 'aggiornamento equipaggi');

  List<Map<String, dynamic>> get tobUserCaps => List<Map<String, dynamic>>.from(
    _getData('tob_user_caps.json') as List? ?? [],
  );

  Future<void> saveTobUserCaps(List<Map<String, dynamic>> data) =>
      _writeFile('tob_user_caps.json', data, 'aggiornamento capacità TOB');

  List<Map<String, dynamic>> get maintenanceActs =>
      List<Map<String, dynamic>>.from(
        _getData('maintenance.json') as List? ?? [],
      );

  Future<void> saveMaintenanceActs(List<Map<String, dynamic>> data) =>
      _writeFile(
        'maintenance.json',
        data,
        'aggiornamento attività manutentive',
      );

  List<Map<String, dynamic>> get flightActs =>
      List<Map<String, dynamic>>.from(_getData('flight.json') as List? ?? []);

  Future<void> saveFlightActs(List<Map<String, dynamic>> data) =>
      _writeFile('flight.json', data, 'aggiornamento attività di volo');

  List<Map<String, dynamic>> get tobActs =>
      List<Map<String, dynamic>>.from(_getData('tob_acts.json') as List? ?? []);

  Future<void> saveTobActs(List<Map<String, dynamic>> data) =>
      _writeFile('tob_acts.json', data, 'aggiornamento attività TOB');

  List<Map<String, dynamic>> get seminars =>
      List<Map<String, dynamic>>.from(_getData('seminars.json') as List? ?? []);

  Future<void> saveSeminars(List<Map<String, dynamic>> data) =>
      _writeFile('seminars.json', data, 'aggiornamento seminari NAM/MHF');

  List<Map<String, dynamic>> get criteria =>
      List<Map<String, dynamic>>.from(_getData('criteria.json') as List? ?? []);

  Future<void> saveCriteria(List<Map<String, dynamic>> data) =>
      _writeFile('criteria.json', data, 'aggiornamento criteri currency');

  List<Map<String, dynamic>> get notifications =>
      List<Map<String, dynamic>>.from(
        _getData('notifications.json') as List? ?? [],
      );

  /// Messaggio di commit che fa partire l'invio Web Push (Action push.yml di
  /// aves-data). Resta finché la scrittura è in coda, così una lettura
  /// ravvicinata non fa saltare il push delle notifiche appena create.
  static const pushCommitMsg = 'nuove notifiche';

  Future<void> saveNotifications(
    List<Map<String, dynamic>> data, {
    bool fresh = false,
  }) => _writeFile(
    'notifications.json',
    data,
    fresh || _pending['notifications.json'] == pushCommitMsg
        ? pushCommitMsg
        : 'aggiornamento notifiche',
  );

  List<Map<String, dynamic>> get pushSubscriptions =>
      List<Map<String, dynamic>>.from(
        _getData('push_subscriptions.json') as List? ?? [],
      );

  Future<void> savePushSubscriptions(List<Map<String, dynamic>> data) =>
      _writeFile(
        'push_subscriptions.json',
        data,
        'aggiornamento sottoscrizioni push',
      );

  List<Map<String, dynamic>> get pta =>
      List<Map<String, dynamic>>.from(_getData('pta.json') as List? ?? []);

  Future<void> savePta(List<Map<String, dynamic>> data) =>
      _writeFile('pta.json', data, 'aggiornamento PTA');

  List<Map<String, dynamic>> get ptaAcknowledgments =>
      List<Map<String, dynamic>>.from(
        _getData('pta_acknowledgments.json') as List? ?? [],
      );

  Future<void> savePtaAcknowledgments(List<Map<String, dynamic>> data) =>
      _writeFile(
        'pta_acknowledgments.json',
        data,
        'aggiornamento presa visione PTA',
      );

  List<Map<String, dynamic>> get accountDeletionRequests =>
      List<Map<String, dynamic>>.from(
        _getData('account_deletion_requests.json') as List? ?? [],
      );

  Future<void> saveAccountDeletionRequests(List<Map<String, dynamic>> data) =>
      _writeFile(
        'account_deletion_requests.json',
        data,
        'aggiornamento richieste eliminazione account',
      );
}

class ConflictException implements Exception {
  final String message;

  ConflictException(this.message);

  @override
  String toString() => message;
}
