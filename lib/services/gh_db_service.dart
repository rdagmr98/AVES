import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../config/gh_config.dart';

class GhDbService {
  static final GhDbService _instance = GhDbService._internal();

  factory GhDbService() => _instance;

  GhDbService._internal();

  static const String _base =
      'https://api.github.com/repos/${GhConfig.owner}/${GhConfig.dataRepo}/contents/db';

  final Map<String, Map<String, dynamic>> _cache = {};

  // ignore: unused_field
  String? _writePat;

  static String hashPassword(String password) {
    final bytes = utf8.encode(password + GhConfig.passwordSalt);
    return sha256.convert(bytes).toString();
  }

  Future<void> init() async {
    _cache.clear();

    await Future.wait([
      _loadFile('reference.json'),
      _loadFile('users.json'),
      _loadFile('licenses.json'),
      _loadFile('privileges.json'),
      _loadFile('crew.json'),
      _loadFile('tob_user_caps.json'),
      _loadFile('maintenance.json'),
      _loadFile('flight.json'),
      _loadFile('tob_acts.json'),
      _loadFile('criteria.json'),
      _loadFile('notifications.json'),
      _loadFile('pta.json'),
      _loadFile('pta_acknowledgments.json'),
      _loadFile('account_deletion_requests.json'),
      _loadFile('seminars.json'),
    ]);
  }

  Future<void> setWritePat(String pat) async {}

  Future<void> clearWritePat() async {}

  bool get hasWritePat => GhConfig.readPat.trim().isNotEmpty;

  Future<void> _loadFile(String fileName) async {
    final response = await http.get(
      Uri.parse('$_base/$fileName'),
      headers: {
        'Authorization': 'Bearer ${GhConfig.readPat}',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final sha = json['sha'] as String;
      final content = utf8.decode(
        base64.decode((json['content'] as String).replaceAll('\n', '')),
      );
      _cache[fileName] = {'data': jsonDecode(content), 'sha': sha};
      return;
    }

    if (response.statusCode == 404) {
      _cache[fileName] = {'data': _emptyDataFor(fileName), 'sha': ''};
      return;
    }

    throw Exception(
      'Errore GitHub API ${response.statusCode} durante il caricamento di $fileName: ${response.body}',
    );
  }

  dynamic _emptyDataFor(String fileName) {
    if (fileName == 'reference.json') {
      return <String, dynamic>{};
    }
    if (fileName == 'seminars.json') {
      return <dynamic>[];
    }
    return <dynamic>[];
  }

  dynamic _getData(String fileName) => _cache[fileName]?['data'];

  String _getSha(String fileName) => _cache[fileName]?['sha'] as String? ?? '';

  Future<void> _writeFile(String fileName, dynamic data, String commitMsg) async {
    final body = <String, dynamic>{
      'message': commitMsg,
      'content': base64.encode(utf8.encode(jsonEncode(data))),
    };
    final sha = _getSha(fileName);
    if (sha.isNotEmpty) {
      body['sha'] = sha;
    }

    final response = await http.put(
      Uri.parse('$_base/$fileName'),
      headers: {
        'Authorization': 'Bearer ${GhConfig.readPat}',
        'Accept': 'application/vnd.github+json',
        'Content-Type': 'application/json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final respJson = jsonDecode(response.body) as Map<String, dynamic>;
      final newSha =
          (respJson['content'] as Map<String, dynamic>)['sha'] as String;
      _cache[fileName] = {'data': data, 'sha': newSha};
      return;
    }

    if (response.statusCode == 409) {
      await _loadFile(fileName);
      throw ConflictException('Conflitto di scrittura. Riprova.');
    }

    throw Exception('Errore GitHub API ${response.statusCode}: ${response.body}');
  }

  Map<String, dynamic> get referenceData =>
      (_getData('reference.json') as Map<String, dynamic>?) ?? {};

  List<Map<String, dynamic>> get users =>
      List<Map<String, dynamic>>.from(_getData('users.json') as List? ?? []);

  Future<void> saveUsers(List<Map<String, dynamic>> data) =>
      _writeFile('users.json', data, 'aggiornamento profili utenti');

  List<Map<String, dynamic>> get licenses => List<Map<String, dynamic>>.from(
    _getData('licenses.json') as List? ?? [],
  );

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

  Future<void> saveMaintenanceActs(List<Map<String, dynamic>> data) => _writeFile(
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

  List<Map<String, dynamic>> get notifications => List<Map<String, dynamic>>.from(
    _getData('notifications.json') as List? ?? [],
  );

  Future<void> saveNotifications(List<Map<String, dynamic>> data) =>
      _writeFile('notifications.json', data, 'aggiornamento notifiche');

  List<Map<String, dynamic>> get pta =>
      List<Map<String, dynamic>>.from(_getData('pta.json') as List? ?? []);

  Future<void> savePta(List<Map<String, dynamic>> data) =>
      _writeFile('pta.json', data, 'aggiornamento PTA');

  List<Map<String, dynamic>> get ptaAcknowledgments =>
      List<Map<String, dynamic>>.from(
        _getData('pta_acknowledgments.json') as List? ?? [],
      );

  Future<void> savePtaAcknowledgments(List<Map<String, dynamic>> data) =>
      _writeFile('pta_acknowledgments.json', data, 'aggiornamento presa visione PTA');

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

  Future<void> reloadAll() async => init();
}

class ConflictException implements Exception {
  final String message;

  ConflictException(this.message);

  @override
  String toString() => message;
}
