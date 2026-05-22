import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_models.dart';
import 'gh_db_service.dart';

class AuthService {
  final _db = GhDbService();

  Future<UserProfile?> signIn(String email, String password) async {
    final hash = GhDbService.hashPassword(password);
    final normalizedEmail = email.trim().toLowerCase();
    Map<String, dynamic>? match;

    for (final user in _db.users) {
      if ((user['email'] as String?)?.toLowerCase() == normalizedEmail &&
          user['password_hash'] == hash) {
        match = user;
        break;
      }
    }

    if (match == null) {
      return null;
    }
    if (match['is_active'] == false) {
      throw Exception('Account disabilitato');
    }

    return UserProfile.fromJson(_withOrgUnit(match));
  }

  Map<String, dynamic> _withOrgUnit(Map<String, dynamic> userMap) {
    final orgUnitId = userMap['org_unit_id'] as int?;
    if (orgUnitId == null) {
      return {...userMap, 'org_units': null};
    }

    final ref = _db.referenceData;
    final units = (ref['orgUnits'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final unit = units.firstWhere(
      (item) => item['id'] == orgUnitId,
      orElse: () => <String, dynamic>{},
    );

    return {...userMap, 'org_units': unit.isNotEmpty ? unit : null};
  }

  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String nome,
    required String cognome,
    String? numeroLicenza,
  }) async {
    final users = _db.users;
    final normalizedEmail = email.trim().toLowerCase();

    if (users.any(
      (user) => (user['email'] as String?)?.toLowerCase() == normalizedEmail,
    )) {
      throw Exception('Email già registrata');
    }

    if (numeroLicenza != null &&
        numeroLicenza.isNotEmpty &&
        users.any((user) => user['numero_licenza'] == numeroLicenza)) {
      throw Exception('Numero di licenza già registrato');
    }

    final id = _generateId();
    final now = DateTime.now().toIso8601String();
    final newUser = <String, dynamic>{
      'id': id,
      'email': normalizedEmail,
      'password_hash': GhDbService.hashPassword(password),
      'nome': nome,
      'cognome': cognome,
      'numero_licenza': numeroLicenza,
      'qualifica': '',
      'org_unit_id': null,
      'role': 'user',
      'is_approved': false,
      'is_active': true,
      'note': null,
      'created_at': now,
      'updated_at': now,
    };

    await _db.saveUsers([...users, newUser]);
    return UserProfile.fromJson({...newUser, 'org_units': null});
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('aves_session');
  }

  Future<void> saveSession(String userId, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'aves_session',
      jsonEncode({'userId': userId, 'role': role}),
    );
  }

  Future<Map<String, String>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('aves_session');
    if (raw == null) {
      return null;
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return {
        'userId': data['userId'] as String,
        'role': data['role'] as String,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> changePassword(String userId, String newPassword) async {
    final users = _db.users;
    final index = users.indexWhere((user) => user['id'] == userId);
    if (index == -1) {
      throw Exception('Utente non trovato');
    }

    users[index] = {
      ...users[index],
      'password_hash': GhDbService.hashPassword(newPassword),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.saveUsers(users);
  }

  String _generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toString();
    final bytes = utf8.encode(ts);
    return sha256.convert(bytes).toString().substring(0, 16);
  }
}
